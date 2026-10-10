-- hud_speedometer_tool: 车载 HUD 抬头数字测速仪与超速预警

local speedUnit = "km/h"
local speedLimit = 80
local peakSpeed = 0
local isMirrorMode = false

local function formatNumber(val, decimals)
  local factor = 1
  local i = 0
  while i < decimals do
    factor = factor * 10
    i = i + 1
  end
  local rounded = math.floor(val * factor + 0.5) / factor
  return tostring(rounded)
end

function refreshSpeed()
  location.getCurrentPosition(function(pos)
    if pos ~= nil and pos.ok == true then
      local rawSpeedMs = pos.speed or 0
      local currentSpeedKmh = rawSpeedMs * 3.6
      local displaySpeed = currentSpeedKmh
      if speedUnit == "mph" then
        displaySpeed = currentSpeedKmh * 0.621371
      end

      if displaySpeed > peakSpeed then
        peakSpeed = displaySpeed
      end

      local isOver = displaySpeed > speedLimit
      if isOver then
        haptic.heavy()
        state.set("speedStatus", "⚠️ 超速预警！当前已超过限速 " .. tostring(speedLimit) .. " " .. speedUnit)
      else
        state.set("speedStatus", "行驶正常 | 限速 " .. tostring(speedLimit) .. " " .. speedUnit)
      end

      state.set("isOverSpeed", isOver)
      state.set("currentSpeed", formatNumber(displaySpeed, 1))
      state.set("peakSpeed", formatNumber(peakSpeed, 1))
      state.set("altitude", formatNumber(pos.altitude or 0, 1) .. " m")
      state.set("latLon", formatNumber(pos.latitude or 0, 4) .. ", " .. formatNumber(pos.longitude or 0, 4))
      state.set("hasGpsLock", true)
    else
      state.set("speedStatus", "GPS 信号搜星中，请移动至开阔道路")
      state.set("hasGpsLock", false)
    end
    return nil
  end)
  return nil
end

function toggleMirror()
  isMirrorMode = not isMirrorMode
  state.set("isMirror", isMirrorMode)
  if isMirrorMode then
    state.set("mirrorLabel", "HUD 镜像投影模式已激活")
    state.set("mirrorTip", "请将手机水平放置在车辆仪表台中央，挡风玻璃将清晰反射平视读数")
    dialog.toast("已进入 HUD 挡风玻璃投影模式")
  else
    state.set("mirrorLabel", "常规正向显示模式")
    state.set("mirrorTip", "常规手持或车载支架直视显示")
    dialog.toast("已切回常规直视模式")
  end
  return nil
end

function setLimit(limit)
  speedLimit = tonumber(limit) or 80
  state.set("limitValue", speedLimit)
  refreshSpeed()
  return nil
end

function setUnit(u)
  speedUnit = u
  state.set("unitLabel", speedUnit)
  refreshSpeed()
  return nil
end

function resetPeak()
  peakSpeed = 0
  state.set("peakSpeed", "0.0")
  dialog.toast("最高车速记录已重置")
  return nil
end

function copyStats()
  local cur = state.get("currentSpeed") or "0"
  local peak = state.get("peakSpeed") or "0"
  local alt = state.get("altitude") or "0 m"
  local gps = state.get("latLon") or ""
  local text = "【车载 HUD 测速仪数据】\n" ..
    "- 当前车速: " .. cur .. " " .. speedUnit .. "\n" ..
    "- 最高车速: " .. peak .. " " .. speedUnit .. "\n" ..
    "- 海拔高度: " .. alt .. "\n" ..
    "- GPS 坐标: " .. gps .. "\n" ..
    "- 监控限速: " .. tostring(speedLimit) .. " " .. speedUnit
  clipboard.set(text)
  dialog.toast("已复制行车测速数据")
  return nil
end

function onInit()
  speedUnit = "km/h"
  speedLimit = 80
  peakSpeed = 0
  isMirrorMode = false

  screen.setKeepScreenOn(true)
  state.set("currentSpeed", "0.0")
  state.set("peakSpeed", "0.0")
  state.set("altitude", "-- m")
  state.set("latLon", "--")
  state.set("unitLabel", "km/h")
  state.set("limitValue", 80)
  state.set("isMirror", false)
  state.set("isOverSpeed", false)
  state.set("mirrorLabel", "常规正向显示模式")
  state.set("mirrorTip", "夜间驾驶可开启 HUD 镜像投影，放于挡风玻璃下方反光读取")
  state.set("speedStatus", "就绪")
  state.set("hasGpsLock", false)

  refreshSpeed()
  return nil
end
