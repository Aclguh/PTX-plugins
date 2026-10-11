-- decibel_meter_tool main.lua
-- 环境噪音分贝计

local function evalLevel(db)
  if db == nil then return "未知" end
  if db <= 35.0 then
    return "极安静 (深山/耳语)"
  elseif db <= 50.0 then
    return "安静舒适 (起居室/图书馆)"
  elseif db <= 70.0 then
    return "普通正常 (办公交流/交谈)"
  elseif db <= 85.0 then
    return "较为嘈杂 (闹市/干道)"
  else
    return "严重噪音 (损耳风险)"
  end
end

function _evalNoiseLevel(db)
  return evalLevel(db)
end

local minVal = nil
local maxVal = nil
local count = 0
local sumVal = 0.0

function onInit()
  minVal = nil
  maxVal = nil
  count = 0
  sumVal = 0.0

  state.set("currentDb", "--")
  state.set("minDb", "--")
  state.set("maxDb", "--")
  state.set("avgDb", "--")
  state.set("levelTag", "待检测")
  return nil
end

function sampleDecibel()
  audio.getDecibel(function(db)
    if db == nil then db = 0.0 end
    local rounded = math.floor(db * 10 + 0.5) / 10.0

    count = count + 1
    sumVal = sumVal + rounded

    if minVal == nil then
      minVal = rounded
    else
      if rounded < minVal then minVal = rounded end
    end

    if maxVal == nil then
      maxVal = rounded
    else
      if rounded > maxVal then maxVal = rounded end
    end

    local avg = math.floor((sumVal / count) * 10 + 0.5) / 10.0

    state.set("currentDb", string.format("%.1f", rounded))
    state.set("minDb", string.format("%.1f", minVal))
    state.set("maxDb", string.format("%.1f", maxVal))
    state.set("avgDb", string.format("%.1f", avg))
    state.set("levelTag", evalLevel(rounded))
    return nil
  end)
  return nil
end

function resetStats()
  minVal = nil
  maxVal = nil
  count = 0
  sumVal = 0.0

  state.set("currentDb", "--")
  state.set("minDb", "--")
  state.set("maxDb", "--")
  state.set("avgDb", "--")
  state.set("levelTag", "待检测")
  dialog.toast("数据已重置")
  return nil
end

function copyStats()
  local cur = state.get("currentDb")
  local min = state.get("minDb")
  local max = state.get("maxDb")
  local avg = state.get("avgDb")
  local lvl = state.get("levelTag")

  local report = string.format("【噪音检测报告】\n当前声压: %s dB (%s)\n最低声压: %s dB\n最高声压: %s dB\n平均声压: %s dB",
    tostring(cur), tostring(lvl), tostring(min), tostring(max), tostring(avg))
  clipboard.set(report)
  dialog.toast("报告已复制到剪贴板")
  return nil
end

function onDispose()
  if audio ~= nil and audio.stopRecord ~= nil then
    pcall(function()
      audio.stopRecord()
    end)
  end
  return nil
end
