-- lux_meter_tool: 环境光照度计与摄影测光 EV 助手

local function roundNum(v, d)
  local factor = 1
  local i = 0
  while i < d do
    factor = factor * 10
    i = i + 1
  end
  return math.floor(v * factor + 0.5) / factor
end

local function evalLightingStandard(lx)
  if lx < 50 then
    return "昏暗夜景 / 仓库楼道 (适宜睡眠，长期用眼极易疲劳)"
  elseif lx < 200 then
    return "门厅走廊 / 卧室休闲 (柔和环境光，不宜精细阅读)"
  elseif lx < 400 then
    return "起居会客 / 餐厅进餐 (满足基础日常起居活动)"
  elseif lx < 750 then
    return "标准办公室 / 教室阅览 (国标推荐 300~500 lx，视觉舒适)"
  elseif lx < 2000 then
    return "精密电子装配 / 高度专注制图 (高照度工作台)"
  elseif lx < 20000 then
    return "户外阴天自然光 (散射漫射光照)"
  else
    return "户外艳阳直射强光 (高动态范围，需注意防眩光)"
  end
end

local function getCameraSettings(ev)
  -- 假定 ISO 100
  if ev <= 3 then
    return "ISO 100 | f/1.4 | 1/4s (或大光圈慢门三脚架夜拍)"
  elseif ev <= 6 then
    return "ISO 100 | f/2.0 | 1/15s (室内弱光人像)"
  elseif ev <= 9 then
    return "ISO 100 | f/2.8 | 1/60s (标准室内日常光线)"
  elseif ev <= 12 then
    return "ISO 100 | f/5.6 | 1/125s (户外阴天扫街抓拍)"
  elseif ev <= 14 then
    return "ISO 100 | f/8.0 | 1/250s (晴天树荫/背光人像)"
  else
    return "ISO 100 | f/11.0 | 1/500s (艳阳高照阳光法则 Sunny 16)"
  end
end

function calculateEv()
  local raw = state.get("luxInput") or "500"
  local lx = tonumber(raw)
  if lx == nil or lx < 0 then
    lx = 0
  end

  local fc = lx / 10.764
  local ev = 0
  if lx > 0.05 then
    ev = (math.log(lx / 2.5)) / (math.log(2))
  else
    ev = -2.0
  end

  local stdAssessment = evalLightingStandard(lx)
  local camGuide = getCameraSettings(ev)

  state.set("luxDisplay", tostring(roundNum(lx, 1)) .. " lx")
  state.set("fcDisplay", tostring(roundNum(fc, 2)) .. " fc (Foot-candle)")
  state.set("evDisplay", "EV " .. tostring(roundNum(ev, 1)) .. " (ISO 100)")
  state.set("assessment", stdAssessment)
  state.set("cameraGuide", camGuide)
  state.set("hasResult", true)
  state.set("statusMsg", "测光与曝光参数推算完成")
  return nil
end

function loadPreset(val)
  state.set("luxInput", tostring(val))
  calculateEv()
  dialog.toast("已载入 " .. tostring(val) .. " lx 照度预设")
  return nil
end

function copyReport()
  local lx = state.get("luxDisplay") or ""
  local fc = state.get("fcDisplay") or ""
  local ev = state.get("evDisplay") or ""
  local std = state.get("assessment") or ""
  local cam = state.get("cameraGuide") or ""

  local report = "【环境照度与摄影测光报告】\n" ..
    "- 照度数值: " .. lx .. " (" .. fc .. ")\n" ..
    "- 曝光指数: " .. ev .. "\n" ..
    "- 照明场景评估: " .. std .. "\n" ..
    "- 推荐曝光参数: " .. cam
  clipboard.set(report)
  dialog.toast("已复制测光报告")
  return nil
end

function onInit()
  state.set("luxInput", "500")
  calculateEv()
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
