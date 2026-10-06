local STORAGE_KEY = "pomodoro_stats_v1"

local currentMode = "focus"
local targetDurationSec = 1500
local remainingSec = 1500
local status = "idle" -- idle, running, paused, finished
local lastStartTimestamp = 0
local baseRemainingAtStart = 1500

local function format_mmss(sec)
  if sec < 0 then
    sec = 0
  end
  local m = math.floor(sec / 60)
  local s = sec % 60
  return string.format("%02d:%02d", m, s)
end

local currentStats = {
  totalSessions = 0,
  totalMinutes = 0
}

local function save_stats()
  local raw = json.encode(currentStats)
  storage.set(STORAGE_KEY, raw)
end

local function update_ui_state()
  local mmss = format_mmss(remainingSec)
  local progress = 0
  if targetDurationSec > 0 then
    progress = math.floor(((targetDurationSec - remainingSec) / targetDurationSec) * 100)
  end
  if progress > 100 then
    progress = 100
  end

  local statusDesc = "准备开始"
  if status == "running" then
    statusDesc = "专注进行中..."
  elseif status == "paused" then
    statusDesc = "已暂停"
  elseif status == "finished" then
    statusDesc = "恭喜！本轮已达成！"
  end

  local modeName = "深度专注"
  if currentMode == "short_break" then
    modeName = "短休息"
  elseif currentMode == "long_break" then
    modeName = "长休息"
  end

  local statsDesc = string.format("累计达成番茄钟: %d 个 | 专注总时长: %d 分钟", currentStats.totalSessions or 0, currentStats.totalMinutes or 0)

  state.set("displayTime", mmss)
  state.set("statusDesc", statusDesc)
  state.set("modeTitle", "【" .. modeName .. "】 " .. tostring(math.floor(targetDurationSec / 60)) .. " 分钟")
  state.set("progressDesc", "完成进度: " .. tostring(progress) .. "%")
  state.set("statsDesc", statsDesc)
  state.set("isRunning", status == "running")
  state.set("isPaused", status == "paused")
  state.set("isIdle", status == "idle")
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function refreshTimer()
  if status == "running" then
    local now = util.timestamp()
    local elapsed = now - lastStartTimestamp
    if elapsed < 0 then
      elapsed = 0
    end
    remainingSec = baseRemainingAtStart - elapsed
    if remainingSec <= 0 then
      remainingSec = 0
      status = "finished"
      finishSession()
    end
  end
  update_ui_state()
  return nil
end

function startTimer()
  if status == "running" then
    return nil
  end
  status = "running"
  lastStartTimestamp = util.timestamp()
  baseRemainingAtStart = remainingSec
  update_ui_state()
  dialog.toast("番茄钟已启动，保持专注！")
  return nil
end

function pauseTimer()
  if status == "running" then
    refreshTimer()
    status = "paused"
    baseRemainingAtStart = remainingSec
    update_ui_state()
    dialog.toast("计时已暂停")
  end
  return nil
end

function resetTimer()
  status = "idle"
  remainingSec = targetDurationSec
  baseRemainingAtStart = targetDurationSec
  update_ui_state()
  dialog.toast("已重置时钟")
  return nil
end

function finishSession()
  status = "finished"
  remainingSec = 0
  if currentMode == "focus" then
    currentStats.totalSessions = (currentStats.totalSessions or 0) + 1
    local mins = math.floor(targetDurationSec / 60)
    currentStats.totalMinutes = (currentStats.totalMinutes or 0) + mins
    save_stats()
    dialog.toast("达成一个番茄钟！休息一下吧～")
  else
    dialog.toast("休息时间结束，准备开始下一轮专注！")
  end
  update_ui_state()
  return nil
end

function setFocus25()
  currentMode = "focus"
  targetDurationSec = 1500
  resetTimer()
  return nil
end

function setBreak5()
  currentMode = "short_break"
  targetDurationSec = 300
  resetTimer()
  return nil
end

function setBreak15()
  currentMode = "long_break"
  targetDurationSec = 900
  resetTimer()
  return nil
end

function addFiveMin()
  targetDurationSec = targetDurationSec + 300
  if targetDurationSec > 7200 then
    targetDurationSec = 7200
  end
  resetTimer()
  return nil
end

function subFiveMin()
  targetDurationSec = targetDurationSec - 300
  if targetDurationSec < 300 then
    targetDurationSec = 300
  end
  resetTimer()
  return nil
end

function clearHistory()
  currentStats = { totalSessions = 0, totalMinutes = 0 }
  save_stats()
  update_ui_state()
  dialog.toast("专注历史统计已清空")
  return nil
end

function onInit()
  currentMode = "focus"
  targetDurationSec = 1500
  remainingSec = 1500
  status = "idle"
  baseRemainingAtStart = 1500
  storage.get(STORAGE_KEY, function(raw)
    if raw and raw ~= "" then
      local ok, data = pcall(json.decode, raw)
      if ok and type(data) == "table" then
        currentStats = data
      end
    end
    update_ui_state()
    return nil
  end)
  update_ui_state()
  return nil
end
