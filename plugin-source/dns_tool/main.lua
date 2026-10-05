-- dns_tool — DNS 查询
-- 数据源: https://dns.google/resolve?name=<domain>&type=<TYPE>
-- (Google Public DNS 的 DoH JSON 接口, 免费免密钥, GET 即可);
-- 记录类型循环切换, 一次只发起一个请求 (network 回调为单一全局函数)

local TYPES = { "A", "AAAA", "CNAME", "MX", "TXT", "NS" }
local typeIdx = 1
local MAX_DOMAIN = 253

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

local function currentType()
  return TYPES[typeIdx]
end

-- 域名合法性: 字母/数字/连字符/点, 无空格, 长度 <= 253
function _validDomain(s)
  if s == "" then return false end
  if string.len(s) > MAX_DOMAIN then return false end
  for i = 1, string.len(s) do
    local c = string.sub(s, i, i)
    local isAlnum = false
    if c >= "a" and c <= "z" then isAlnum = true end
    if c >= "A" and c <= "Z" then isAlnum = true end
    if c >= "0" and c <= "9" then isAlnum = true end
    if c == "." then isAlnum = true end
    if c == "-" then isAlnum = true end
    if not isAlnum then return false end
  end
  return true
end

-- 构造请求 URL
function _buildUrl(domain, dnstype)
  return "https://dns.google/resolve?name=" .. domain .. "&type=" .. dnstype
end

-- Answer 数组 -> 展示行
function _answerLines(answer)
  local lines = {}
  local n = 0
  if type(answer) == "table" then n = #answer end
  for i = 1, n do
    local rec = answer[i]
    if type(rec) == "table" then
      local data = tostring(rec.data or "?")
      local ttl = tonumber(rec.ttl)
      local line = data
      if ttl ~= nil then
        line = data .. " (TTL " .. ttl .. ")"
      end
      lines[#lines + 1] = line
      if #lines >= 20 then
        lines[#lines + 1] = "...（其余记录省略）"
        return lines
      end
    end
  end
  return lines
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("domainInput", "")
  state.set("typeLbl", "类型: A")
  state.set("resultText", "")
  state.set("hasResult", false)
  state.set("infoText", "")
  clearError()
end

function cycleType()
  typeIdx = typeIdx % #TYPES + 1
  state.set("typeLbl", "类型: " .. TYPES[typeIdx])
end

function queryDns()
  clearError()
  state.set("hasResult", false)
  local domain = state.get("domainInput") or ""
  if domain == "" then
    setError("请输入要查询的域名")
    return nil
  end
  if not _validDomain(domain) then
    setError("域名格式不合法（仅支持字母/数字/连字符/点）")
    return nil
  end
  state.set("infoText", "查询中: " .. domain .. " " .. currentType() .. " ...")
  network.get(_buildUrl(domain, currentType()))
end

function onNetworkResponse(status, body)
  if status ~= 200 then
    state.set("infoText", "")
    setError("查询失败: HTTP " .. status)
    return nil
  end
  local ok, data = pcall(json.decode, body or "")
  if not ok then
    state.set("infoText", "")
    setError("响应解析失败")
    return nil
  end
  if type(data) ~= "table" then
    state.set("infoText", "")
    setError("响应格式异常")
    return nil
  end
  if data.Status ~= nil and data.Status ~= 0 then
    state.set("infoText", "")
    setError("DNS 状态码 " .. tostring(data.Status) .. " (0 表示成功, 3 表示域名不存在)")
    return nil
  end
  local lines = _answerLines(data.Answer)
  local domain = state.get("domainInput") or ""
  if #lines == 0 then
    state.set("resultText", domain .. " 的 " .. currentType() .. " 记录为空")
  else
    state.set("resultText", domain .. " " .. currentType() .. " 记录:\n" .. table.concat(lines, "\n"))
  end
  state.set("infoText", "查询完成")
  state.set("hasResult", true)
end

function onNetworkError(msg)
  state.set("infoText", "")
  setError("网络错误: " .. (msg or "未知"))
end
