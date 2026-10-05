-- unicode_tool — 字符与码点查询
-- 沙箱内 string.byte 返回码点/UTF-16 代理码元, 代理对需重组;
-- 运行时码点->字符无法用 string.char (仅 0..255), 借 json \u 转义构造

local MAX_DETAIL = 24
local MAX_ANALYZE = 10000
local MAX_BUILD = 64
local HEX = "0123456789ABCDEF"

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

-- 单码点 -> UTF-8 字节数组 (孤立代理以 U+FFFD 呈现)
function _cpUtf8(cp)
  if cp >= 55296 and cp <= 57343 then cp = 65533 end
  local out = {}
  if cp < 128 then
    out[1] = cp
  elseif cp < 2048 then
    out[1] = 192 + math.floor(cp / 64)
    out[2] = 128 + cp % 64
  elseif cp < 65536 then
    out[1] = 224 + math.floor(cp / 4096)
    out[2] = 128 + math.floor(cp / 64) % 64
    out[3] = 128 + cp % 64
  else
    out[1] = 240 + math.floor(cp / 262144)
    out[2] = 128 + math.floor(cp / 65536) % 64
    out[3] = 128 + math.floor(cp / 4096) % 64
    out[4] = 128 + cp % 64
  end
  return out
end

-- 码点 -> 字符 (JSON \u 转义; 增补平面拆代理对; 代理区码点以 U+FFFD 呈现)
function _cpChar(cp)
  if cp < 0 then return nil end
  if cp > 1114111 then return nil end
  if cp >= 55296 then
    if cp <= 57343 then cp = 65533 end
  end
  if cp < 65536 then
    return json.decode('"\\u' .. string.format("%04x", cp) .. '"')
  end
  local v = cp - 65536
  local hi = 55296 + math.floor(v / 1024)
  local lo = 56320 + (v % 1024)
  return json.decode('"\\u' .. string.format("%04x", hi)
      .. '\\u' .. string.format("%04x", lo) .. '"')
end

-- 文本 -> 码点数组 (重组 UTF-16 代理对, 孤立代理记为 U+FFFD)
function _codepoints(s)
  local out = {}
  local n = string.len(s)
  local i = 1
  while i <= n do
    local c = string.byte(s, i)
    if c >= 55296 and c <= 56319 and i + 1 <= n then
      local d = string.byte(s, i + 1)
      if d >= 56320 and d <= 57343 then
        out[#out + 1] = 65536 + (c - 55296) * 1024 + (d - 56320)
        i = i + 2
      else
        out[#out + 1] = 65533
        i = i + 1
      end
    elseif c >= 55296 then
      if c <= 57343 then
        out[#out + 1] = 65533
        i = i + 1
      else
        out[#out + 1] = c
        i = i + 1
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return out
end

-- 按空格/逗号/分号切分 token
local function splitTokens(s)
  local out = {}
  local cur = {}
  local n = string.len(s)
  for i = 1, n do
    local ch = string.sub(s, i, i)
    local isSep = ch == " " or ch == "," or ch == ";" or ch == "\t"
    if isSep then
      if #cur > 0 then
        out[#out + 1] = table.concat(cur)
        cur = {}
      end
    else
      cur[#cur + 1] = ch
    end
  end
  if #cur > 0 then out[#out + 1] = table.concat(cur) end
  return out
end

-- "4F60 597D" / "U+4F60,u+597D" -> 码点数组; 非法返回 nil
function _parseCps(s)
  local out = {}
  local tokens = splitTokens(string.upper(s))
  for _, tok in ipairs(tokens) do
    if string.len(tok) >= 2 and string.sub(tok, 1, 2) == "U+" then
      tok = string.sub(tok, 3)
    end
    if tok == "" then return nil end
    local n = 0
    for i = 1, string.len(tok) do
      local v = string.find(HEX, string.sub(tok, i, i), 1, true)
      if v == nil then return nil end
      n = n * 16 + (v - 1)
      if n > 1114111 then return nil end
    end
    out[#out + 1] = n
  end
  if #out == 0 then return nil end
  return out
end

-- 字节数组 -> "E4 BD A0" 形式
local function bytesHex(bytes)
  local parts = {}
  for i, b in ipairs(bytes) do
    parts[i] = string.format("%02X", b)
  end
  return table.concat(parts, " ")
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _bytesHex(bytes)
  return bytesHex(bytes)
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("uInput", "")
  state.set("uSummary", "")
  state.set("uDetail", "")
  state.set("cpInput", "")
  state.set("charOut", "")
  state.set("charBytes", "")
  state.set("hasAnalysis", false)
  state.set("hasCharResult", false)
  clearError()
end

function analyze()
  clearError()
  state.set("hasAnalysis", false)
  local text = state.get("uInput") or ""
  if text == "" then
    setError("请输入要分析的文本")
    return nil
  end
  if string.len(text) > MAX_ANALYZE then
    setError("文本过长: 一次最多分析 " .. MAX_ANALYZE .. " 个字符")
    return nil
  end
  local cps = _codepoints(text)
  local total = #cps
  local bytes = 0
  for _, cp in ipairs(cps) do
    bytes = bytes + #_cpUtf8(cp)
  end
  local summary = "共 " .. total .. " 个字符 (码点), UTF-8 编码 " .. bytes .. " 字节"
  local shown = total
  if shown > MAX_DETAIL then
    shown = MAX_DETAIL
    summary = summary .. "\n明细仅展示前 " .. MAX_DETAIL .. " 个字符"
  end
  local lines = {}
  for i = 1, shown do
    local cp = cps[i]
    local b = _cpUtf8(cp)
    lines[i] = _cpChar(cp) .. "  U+" .. string.format("%04X", cp)
        .. "  " .. bytesHex(b)
  end
  state.set("uSummary", summary)
  state.set("uDetail", table.concat(lines, "\n"))
  state.set("hasAnalysis", true)
end

function buildFromCps()
  clearError()
  state.set("hasCharResult", false)
  local raw = trim(state.get("cpInput") or "")
  if raw == "" then
    setError("请输入码点, 如 4F60 或 U+4F60 597D")
    return nil
  end
  local cps = _parseCps(string.upper(raw))
  if cps == nil then
    setError("码点格式不合法: 仅支持十六进制, 以空格/逗号分隔")
    return nil
  end
  if #cps > MAX_BUILD then
    setError("一次最多转换 " .. MAX_BUILD .. " 个码点")
    return nil
  end
  local chars = {}
  local allBytes = {}
  for i, cp in ipairs(cps) do
    local ch = _cpChar(cp)
    if ch == nil then
      setError("码点超出 Unicode 范围 (最大 U+10FFFF)")
      return nil
    end
    chars[i] = ch
    local b = _cpUtf8(cp)
    for _, v in ipairs(b) do allBytes[#allBytes + 1] = v end
  end
  state.set("charOut", table.concat(chars))
  state.set("charBytes", "UTF-8: " .. bytesHex(allBytes))
  state.set("hasCharResult", true)
end
