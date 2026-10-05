-- jwt_tool — JWT 解析 (仅解码展示, 不验证签名)
-- JWT 段为 base64url 无填充: 先还原标准字母表并补齐 '=' 再走 codec.base64Decode,
-- 随后用宿主 json.decode 还原为表, 插件内做缩进美化输出

local WEEKDAYS = { "星期四", "星期五", "星期六", "星期日", "星期一", "星期二", "星期三" }

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

local function trim(s)
  local a = 1
  local b = string.len(s)
  while a <= b and string.sub(s, a, a) == " " do a = a + 1 end
  while b >= a and string.sub(s, b, b) == " " do b = b - 1 end
  if a > b then return "" end
  return string.sub(s, a, b)
end

-- Unix 秒 -> "YYYY-MM-DD HH:MM:SS 星期X" (UTC)
local function formatEpoch(sec)
  local days = math.floor(sec / 86400)
  local secsOfDay = sec - days * 86400
  if secsOfDay < 0 then
    secsOfDay = secsOfDay + 86400
    days = days - 1
  end
  local z = days + 719468
  local era = math.floor(z / 146097)
  local doe = z - era * 146097
  local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
  local mp = math.floor((5 * doy + 2) / 153)
  local d = doy - math.floor((153 * mp + 2) / 5) + 1
  local m = mp + (mp < 10 and 3 or -9)
  if m <= 2 then y = y + 1 end
  local hh = math.floor(secsOfDay / 3600)
  local mi = math.floor((secsOfDay - hh * 3600) / 60)
  local ss = secsOfDay - hh * 3600 - mi * 60
  return string.format("%04d-%02d-%02d %02d:%02d:%02d ", y, m, d, hh, mi, ss)
      .. WEEKDAYS[(days % 7) + 1]
end

local function b64urlToStd(s)
  local out = {}
  for i = 1, string.len(s) do
    local ch = string.sub(s, i, i)
    if ch == "-" then
      out[#out + 1] = "+"
    elseif ch == "_" then
      out[#out + 1] = "/"
    else
      out[#out + 1] = ch
    end
  end
  local t = table.concat(out)
  local pad = (4 - string.len(t) % 4) % 4
  if pad > 0 then t = t .. string.rep("=", pad) end
  return t
end

-- JWT 段 -> Lua 表; 失败返回 nil, err
function _decodeSegment(seg)
  local ok, jsonText = pcall(codec.base64Decode, b64urlToStd(seg))
  if not ok then return nil, "Base64URL 解码失败" end
  local ok2, val = pcall(json.decode, jsonText)
  if not ok2 then return nil, "JSON 解析失败" end
  if type(val) ~= "table" then return nil, "段内容不是 JSON 对象" end
  return val
end

-- Lua 表 -> 缩进 JSON 文本 (对象键排序以稳定输出; 空表为 {})
function _jsonPretty(val, indent)
  local pad = string.rep("  ", indent)
  local inner = string.rep("  ", indent + 1)
  if type(val) == "table" then
    local n = 0
    for _ in pairs(val) do n = n + 1 end
    if n == 0 then return "{}" end
    local isArr = true
    for i = 1, n do
      if val[i] == nil then isArr = false end
    end
    if isArr then
      local parts = {}
      for i = 1, n do parts[i] = _jsonPretty(val[i], indent + 1) end
      return "[\n" .. inner .. table.concat(parts, ",\n" .. inner) .. "\n" .. pad .. "]"
    end
    local parts = {}
    for k, v in pairs(val) do
      parts[#parts + 1] = '"' .. tostring(k) .. '": ' .. _jsonPretty(v, indent + 1)
    end
    table.sort(parts)
    return "{\n" .. inner .. table.concat(parts, ",\n" .. inner) .. "\n" .. pad .. "}"
  end
  -- 标量交给宿主 json.encode 以获得与 JSON 一致的转义/字面量
  return json.encode(val)
end

-- token -> {header, payload, claims, sig}; 非法返回 nil, err
function _parseJwt(token)
  local parts = {}
  local start = 1
  while true do
    local pos = string.find(token, ".", start, true)
    if pos == nil then
      parts[#parts + 1] = string.sub(token, start)
      break
    end
    parts[#parts + 1] = string.sub(token, start, pos - 1)
    start = pos + 1
  end
  if #parts ~= 3 then
    return nil, "JWT 应为 header.payload.signature 三段结构"
  end
  if parts[1] == "" then
    return nil, "header 或 payload 段为空"
  end
  if parts[2] == "" then
    return nil, "header 或 payload 段为空"
  end
  local hdr, err1 = _decodeSegment(parts[1])
  if hdr == nil then return nil, "header: " .. err1 end
  local pld, err2 = _decodeSegment(parts[2])
  if pld == nil then return nil, "payload: " .. err2 end

  local claims = {}
  local now = util.timestamp()
  local names = { "exp", "iat", "nbf" }
  for _, name in ipairs(names) do
    local v = pld[name]
    if type(v) == "number" then
      claims[#claims + 1] = name .. ": " .. formatEpoch(math.floor(v)) .. " (UTC)"
      if name == "exp" then
        if now > v then
          claims[#claims + 1] = "exp 状态: 已过期"
        else
          claims[#claims + 1] = "exp 状态: 有效"
        end
      end
    end
  end

  return {
    header = _jsonPretty(hdr, 0),
    payload = _jsonPretty(pld, 0),
    claims = table.concat(claims, "\n"),
    sig = "signature: " .. string.len(parts[3]) .. " 字符 (未验证)",
  }
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _b64urlToStd(s)
  return b64urlToStd(s)
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("jwtInput", "")
  state.set("headerOut", "")
  state.set("payloadOut", "")
  state.set("claimsOut", "")
  state.set("sigOut", "")
  state.set("hasResult", false)
  clearError()
end

function parseJwt()
  clearError()
  state.set("hasResult", false)
  local token = trim(state.get("jwtInput") or "")
  if token == "" then
    setError("请输入 JWT 令牌")
    return nil
  end
  if string.len(token) > 8192 then
    setError("Token 过长 (上限 8192 字符)")
    return nil
  end
  local res, err = _parseJwt(token)
  if res == nil then
    setError(err)
    return nil
  end
  state.set("headerOut", res.header)
  state.set("payloadOut", res.payload)
  state.set("claimsOut", res.claims)
  state.set("sigOut", res.sig)
  state.set("hasResult", true)
end

function pasteInput()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("jwtInput", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
