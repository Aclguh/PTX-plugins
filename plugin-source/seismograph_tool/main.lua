-- seismograph_tool: 微震动监测仪与微型地震记录仪

local baselineG = 9.81
local peakPga = 0.0
local currentVibration = 0.0

local function roundNum(v, d)
  local factor = 1
  local i = 0
  while i < d do
    factor = factor * 10
    i = i + 1
  end
  return math.floor(v * factor + 0.5) / factor
end

local function evalIntensity(pgaMs2)
  local gal = pgaMs2 * 100
  if gal < 3.0 then
    return "0 度 (无感 / 平稳背景微震)"
  elseif gal < 10.0 then
    return "Ⅰ~Ⅱ 度 (微有感，室内个别静止者有感)"
  elseif gal < 35.0 then
    return "Ⅲ~Ⅳ 度 (轻度，悬挂物轻微摆动，门窗轻颤)"
  elseif gal < 100.0 then
    return "Ⅴ 度 (中度震感，室内多数人有感，小物件摇晃)"
  elseif gal < 250.0 then
    return "Ⅵ~Ⅶ 度 (强烈震感，站立不稳，墙体可能龟裂)"
  else
    return "Ⅷ 度以上 (破坏性剧烈震动)"
  end
end

function refreshVibration()
  local acc = sensor.getAccelerometer()
  local x = 0.05
  local y = 0.02
  local z = 9.81

  if acc ~= nil then
    if acc.x ~= nil then x = acc.x end
    if acc.y ~= nil then y = acc.y end
    if acc.z ~= nil then z = acc.z end
  end

  local totalMod = math.sqrt((x * x) + (y * y) + (z * z))
  local delta = math.abs(totalMod - baselineG)

  if delta > peakPga then
    peakPga = delta
  end

  local gal = delta * 100
  local peakGal = peakPga * 100
  local intensity = evalIntensity(delta)

  state.set("netAcc", tostring(roundNum(delta, 3)) .. " m/s²")
  state.set("galDisplay", tostring(roundNum(gal, 1)) .. " Gal")
  state.set("peakDisplay", tostring(roundNum(peakPga, 3)) .. " m/s² (" .. tostring(roundNum(peakGal, 1)) .. " Gal)")
  state.set("rawAxes", "X: " .. tostring(roundNum(x, 2)) .. " | Y: " .. tostring(roundNum(y, 2)) .. " | Z: " .. tostring(roundNum(z, 2)))
  state.set("intensityLevel", intensity)
  state.set("statusMsg", "监测中: " .. intensity)
  return nil
end

function calibrateRest()
  local acc = sensor.getAccelerometer()
  if acc ~= nil and acc.z ~= nil then
    local x = acc.x or 0
    local y = acc.y or 0
    local z = acc.z or 9.81
    baselineG = math.sqrt((x * x) + (y * y) + (z * z))
  else
    baselineG = 9.81
  end
  refreshVibration()
  state.set("statusMsg", "已校准当前静止重力底噪: " .. tostring(roundNum(baselineG, 3)) .. " m/s²")
  dialog.toast("静止基准已校准")
  return nil
end

function simulateShock(level)
  if level == "step" then
    -- 脚步走动 / 敲击桌面 (约 0.15 m/s2)
    peakPga = 0.15
  elseif level == "quake" then
    -- 明显地震晃动 (约 1.25 m/s2)
    peakPga = 1.25
  else
    -- 微风轻拂
    peakPga = 0.02
  end
  refreshVibration()
  dialog.toast("已模拟 " .. level .. " 振动峰值")
  return nil
end

function resetPeak()
  peakPga = 0.0
  refreshVibration()
  dialog.toast("历史峰值已重置")
  return nil
end

function copyRecord()
  local acc = state.get("netAcc") or ""
  local gal = state.get("galDisplay") or ""
  local peak = state.get("peakDisplay") or ""
  local axes = state.get("rawAxes") or ""
  local lvl = state.get("intensityLevel") or ""

  local report = "【微震动与地震记录仪数据】\n" ..
    "- 实时净加速度: " .. acc .. " (" .. gal .. ")\n" ..
    "- 峰值加速度 (PGA): " .. peak .. "\n" ..
    "- 三轴原始读数: " .. axes .. "\n" ..
    "- 地震烈度估算: " .. lvl
  clipboard.set(report)
  dialog.toast("已复制震动报告")
  return nil
end

function onInit()
  baselineG = 9.81
  peakPga = 0.0
  currentVibration = 0.0
  refreshVibration()
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
