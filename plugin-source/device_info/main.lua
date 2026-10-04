-- device_info — 设备信息查看
-- 系统基础信息走宿主 system API (只读无权限), 公网网络信息走 network.get 可选查询

-- ---------------- 测试钩子 (harness 专用) ----------------
-- 从扁平 JSON 文本中提取指定字段的字符串/数字值 (无模式匹配可用, 手写扫描)
local function extractField(json, key)
  local pat = '"' .. key .. '"'
  local pos = string.find(json, pat, 1, true)
  if pos == nil then return nil end
  pos = pos + string.len(pat)
  -- 跳过空白与冒号
  while pos <= string.len(json) do
    local c = string.sub(json, pos, pos)
    if c == ":" then
      pos = pos + 1
      break
    end
    if c ~= " " and c ~= "\n" and c ~= "\t" then
      -- 奇怪的键值间隔, 仍尝试继续
    end
    pos = pos + 1
  end
  local c = string.sub(json, pos, pos)
  if c == '"' then
    -- 字符串值: 处理转义
    local out = {}
    pos = pos + 1
    while pos <= string.len(json) do
      local ch = string.sub(json, pos, pos)
      if ch == "\\" then
        local nxt = string.sub(json, pos + 1, pos + 1)
        out[#out + 1] = nxt
        pos = pos + 2
      elseif ch == '"' then
        break
      else
        out[#out + 1] = ch
        pos = pos + 1
      end
    end
    return table.concat(out)
  end
  -- 数字/null: 截到逗号或右括号
  local endPos = pos
  while endPos <= string.len(json) do
    local ch = string.sub(json, endPos, endPos)
    if ch == "," or ch == "}" or ch == "]" then break end
    endPos = endPos + 1
  end
  local raw = string.sub(json, pos, endPos - 1)
  if raw == "null" then return nil end
  return raw
end

function _extractField(json, key)
  return extractField(json, key)
end

-- ---------------- 插件状态与交互 ----------------
local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

function onInit()
  state.set("platform", "")
  state.set("osVersion", "")
  state.set("hostname", "")
  state.set("cores", "")
  state.set("locale", "")
  state.set("screenText", "")
  state.set("brightnessText", "")
  state.set("ipQueryTime", "")
  state.set("ipInfo", "")
  state.set("hasIpInfo", false)
  state.set("ipLoading", false)
  clearError()
  refreshSystem()
end

function refreshSystem()
  clearError()
  state.set("platform", system.platform())
  state.set("osVersion", system.osVersion())
  state.set("hostname", system.hostname())
  state.set("cores", tostring(system.cores()) .. " 核")
  state.set("locale", system.locale())
  local w = system.screenWidth()
  local h = system.screenHeight()
  local ratio = system.pixelRatio()
  state.set("screenText", w .. " x " .. h .. " 物理像素 @ " .. ratio .. "x"
      .. " (逻辑约 " .. math.floor(w / ratio) .. " x " .. math.floor(h / ratio) .. ")")
  local bright = system.brightness()
  if bright == "dark" then
    state.set("brightnessText", "深色")
  else
    state.set("brightnessText", "浅色")
  end
  dialog.toast("已刷新")
end

function onNetworkResponse(status, body)
  state.set("ipLoading", false)
  if status ~= 200 then
    setError("查询失败: HTTP " .. status)
    return nil
  end
  local query = extractField(body, "query") or "未知"
  local country = extractField(body, "country") or ""
  local region = extractField(body, "regionName") or ""
  local city = extractField(body, "city") or ""
  local isp = extractField(body, "isp") or "未知"
  local tz = extractField(body, "timezone") or ""
  state.set("ipInfo", "公网 IP: " .. query
      .. "\n位置: " .. country .. " " .. region .. " " .. city
      .. "\n运营商: " .. isp
      .. "\n时区: " .. tz)
  state.set("hasIpInfo", true)
  clearError()
end

function onNetworkError(message)
  state.set("ipLoading", false)
  setError("查询失败: " .. message .. " (设备可能离线)")
end

function queryIp()
  clearError()
  state.set("hasIpInfo", false)
  state.set("ipLoading", true)
  state.set("ipQueryTime", util.timestamp())
  network.get("http://ip-api.com/json/?lang=zh-CN&fields=query,country,regionName,city,isp,timezone")
end
