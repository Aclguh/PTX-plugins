-- compass_level_tool main.lua
-- 电子罗盘与水平仪

local function headingToName(deg)
  if deg == nil then return "未知" end
  local d = deg % 360
  if d < 0 then d = d + 360 end

  if d >= 337.5 or d < 22.5 then
    return "正北"
  elseif d < 67.5 then
    return "东北"
  elseif d < 112.5 then
    return "正东"
  elseif d < 157.5 then
    return "东南"
  elseif d < 202.5 then
    return "正南"
  elseif d < 247.5 then
    return "西南"
  elseif d < 292.5 then
    return "正西"
  else
    return "西北"
  end
end

function _calcHeadingLabel(deg)
  return headingToName(deg)
end

function _evalLevel(pitch, roll)
  local ap = math.abs(pitch)
  local ar = math.abs(roll)
  if ap <= 3.0 and ar <= 3.0 then
    return true
  end
  return false
end

function onInit()
  state.set("heading", 0)
  state.set("headingLabel", "正北 (0°)")
  state.set("pitch", "0.0")
  state.set("roll", "0.0")
  state.set("levelStatus", "完全水平 (校准基准)")
  refreshSensors()
  return nil
end

function refreshSensors()
  local comp = sensor.getCompass()
  if comp ~= nil then
    local h = comp.heading
    if h == nil then h = 0.0 end
    local roundH = math.floor(h + 0.5)
    local name = headingToName(roundH)
    state.set("heading", roundH)
    state.set("headingLabel", string.format("%s (%d°)", name, roundH))
  end

  local acc = sensor.getAccelerometer()
  if acc ~= nil then
    local x = acc.x or 0.0
    local y = acc.y or 0.0
    local z = acc.z or 9.8

    local denom = math.sqrt(y * y + z * z)
    if denom == 0 then denom = 0.001 end
    local pRad = math.atan(-x, denom)
    local rRad = math.atan(y, z)

    local pDeg = math.floor((pRad * 180.0 / 3.14159265) * 10 + 0.5) / 10.0
    local rDeg = math.floor((rRad * 180.0 / 3.14159265) * 10 + 0.5) / 10.0

    state.set("pitch", string.format("%.1f", pDeg))
    state.set("roll", string.format("%.1f", rDeg))

    local isLvl = _evalLevel(pDeg, rDeg)
    if isLvl == true then
      state.set("levelStatus", "平整良好 (在 ±3° 内)")
    else
      state.set("levelStatus", "存在倾斜 (需微调被测物)")
    end
  end

  return nil
end

function onDispose()
  if sensor ~= nil and sensor.stop ~= nil then
    pcall(function()
      sensor.stop("all")
    end)
  end
  return nil
end
