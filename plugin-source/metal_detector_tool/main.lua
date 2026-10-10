-- metal_detector_tool: 磁力计金属探测与磁场强度计

local baselineUt = 45.0
local currentUt = 48.2
local thresholdUt = 25.0
local isAlerting = false

local function formatOneDecimal(n)
  local r = math.floor(n * 10 + 0.5) / 10
  return tostring(r)
end

function refreshField()
  local compass = sensor.getCompass()
  local heading = 0
  if compass ~= nil and compass.heading ~= nil then
    heading = compass.heading
  end

  local delta = currentUt - baselineUt
  if delta < 0 then delta = 0 end

  local detected = delta >= thresholdUt
  if detected then
    haptic.vibrate()
    state.set("metalStatus", "⚠️ 探测到强磁性金属 / 铁磁物体靠近！")
    state.set("alertColor", "#E53935")
  else
    state.set("metalStatus", "环境磁场平稳，未探测到金属异物")
    state.set("alertColor", "#43A047")
  end

  state.set("isMetalDetected", detected)
  state.set("currentReading", formatOneDecimal(currentUt) .. " μT")
  state.set("baselineReading", formatOneDecimal(baselineUt) .. " μT")
  state.set("deltaReading", "+" .. formatOneDecimal(delta) .. " μT")
  state.set("headingDegree", formatOneDecimal(heading) .. "°")
  return nil
end

function calibrateBaseline()
  baselineUt = currentUt
  state.set("baselineReading", formatOneDecimal(baselineUt) .. " μT")
  state.set("statusMsg", "已将当前数值校准为环境背景地磁基准")
  dialog.toast("底噪基准已校准")
  refreshField()
  return nil
end

function simulateProximity(level)
  if level == "near" then
    -- 钥匙/硬币靠近
    currentUt = baselineUt + 35.0
  elseif level == "magnet" then
    -- 强磁铁/电机近距离
    currentUt = baselineUt + 120.0
  else
    -- 正常远离
    currentUt = baselineUt + 3.2
  end
  refreshField()
  return nil
end

function setThreshold(th)
  thresholdUt = tonumber(th) or 25.0
  state.set("thresholdLabel", formatOneDecimal(thresholdUt) .. " μT")
  refreshField()
  return nil
end

function copyReading()
  local cur = state.get("currentReading") or ""
  local base = state.get("baselineReading") or ""
  local d = state.get("deltaReading") or ""
  local stat = state.get("metalStatus") or ""

  local text = "【磁力计金属探测数据】\n" ..
    "- 实时磁场模长: " .. cur .. "\n" ..
    "- 标定地磁底噪: " .. base .. "\n" ..
    "- 相对异常差值: " .. d .. "\n" ..
    "- 报警判决阈值: " .. formatOneDecimal(thresholdUt) .. " μT\n" ..
    "- 探测状态: " .. stat
  clipboard.set(text)
  dialog.toast("已复制磁场读数")
  return nil
end

function onInit()
  baselineUt = 45.0
  currentUt = 48.2
  thresholdUt = 25.0
  isAlerting = false

  state.set("thresholdLabel", "25.0 μT")
  state.set("statusMsg", "就绪，靠近金属或墙壁线管进行扫描")
  refreshField()
  return nil
end
