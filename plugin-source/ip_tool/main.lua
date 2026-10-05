-- ip_tool — IP 归属地查询
-- 数据源: https://ipwho.is/ (免费 HTTPS, 无需密钥), 响应为嵌套 JSON,
-- 借宿主 json.decode 还原; 空输入查询本机出口 IP

local API = "https://ipwho.is/"
local NUMS = "0123456789"

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

-- IPv4 校验: 4 段 0-255, 无前导零
local function validIpv4(s)
  local parts = {}
  local start = 1
  while true do
    local pos = string.find(s, ".", start, true)
    if pos == nil then
      parts[#parts + 1] = string.sub(s, start)
      break
    end
    parts[#parts + 1] = string.sub(s, start, pos - 1)
    start = pos + 1
  end
  if #parts ~= 4 then return false end
  for _, p in ipairs(parts) do
    if p == "" then return false end
    if string.len(p) > 3 then return false end
    for i = 1, string.len(p) do
      if string.find(NUMS, string.sub(p, i, i), 1, true) == nil then return false end
    end
    local n = tonumber(p)
    if n == nil then return false end
    if n > 255 then return false end
    if string.len(p) > 1 and string.sub(p, 1, 1) == "0" then return false end
  end
  return true
end

local function field(v)
  if v == nil then return "未知" end
  if v == "" then return "未知" end
  return tostring(v)
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _validIpv4(s)
  return validIpv4(s)
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("ipInput", "")
  state.set("ipOut", "")
  state.set("locOut", "")
  state.set("ispOut", "")
  state.set("tzOut", "")
  state.set("geoOut", "")
  state.set("hasResult", false)
  clearError()
end

function queryIp()
  clearError()
  state.set("hasResult", false)
  local ip = trim(state.get("ipInput") or "")
  local url = API
  if ip ~= "" then
    if not validIpv4(ip) then
      -- IPv6 不做本地校验, 交给服务端判定
      if string.find(ip, ":", 1, true) == nil then
        setError("IP 格式不合法")
        return nil
      end
    end
    url = API .. ip
  end
  network.get(url)
end

function onNetworkResponse(status, body)
  if status ~= 200 then
    setError("查询失败: HTTP " .. status)
    return nil
  end
  local ok, data = pcall(json.decode, body or "")
  if not ok then
    setError("响应解析失败")
    return nil
  end
  if type(data) ~= "table" then
    setError("响应解析失败")
    return nil
  end
  if data.success == false then
    setError("查询失败: " .. field(data.message))
    return nil
  end
  state.set("ipOut", field(data.ip))
  local isp = "未知"
  local conn = data.connection
  if type(conn) == "table" then
    isp = field(conn.isp)
    local org = field(conn.org)
    if org ~= "未知" and org ~= isp then
      isp = isp .. " / " .. org
    end
  end
  state.set("ispOut", isp)
  local tzs = "未知"
  local tz = data.timezone
  if type(tz) == "table" then tzs = field(tz.id) end
  state.set("tzOut", tzs)
  state.set("locOut", field(data.country) .. " · " .. field(data.region)
      .. " · " .. field(data.city))
  state.set("geoOut", field(data.latitude) .. ", " .. field(data.longitude))
  state.set("hasResult", true)
  clearError()
end

function onNetworkError(msg)
  setError("网络请求失败: " .. (msg or "未知错误"))
end
