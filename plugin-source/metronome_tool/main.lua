-- metronome_tool — 节拍器与节奏训练器
-- 支持 40~240 BPM 调速、高低音纯正弦波节拍、触觉震动与多拍号模式

local currentBpm = 120
local currentSigIdx = 3 -- 1: 2/4, 2: 3/4, 3: 4/4, 4: 6/8
local SIGNATURES = {
  { name = "2/4 拍", beats = 2 },
  { name = "3/4 拍", beats = 3 },
  { name = "4/4 拍", beats = 4 },
  { name = "6/8 拍", beats = 6 }
}

local timerId = nil
local currentBeat = 0

function _calcIntervalMs(bpm)
  if bpm <= 0 then return 500 end
  return math.floor(60000 / bpm)
end

function _getTempoTerm(bpm)
  if bpm < 60 then
    return "Largo 广板 (<60)"
  elseif bpm < 76 then
    return "Adagio 柔板 (60-75)"
  elseif bpm < 108 then
    return "Andante 行板 (76-107)"
  elseif bpm < 120 then
    return "Moderato 中速 (108-119)"
  elseif bpm < 168 then
    return "Allegro 快板 (120-167)"
  elseif bpm < 200 then
    return "Presto 急板 (168-199)"
  else
    return "Prestissimo 最急板 (>=200)"
  end
end

function _buildBeatDots(beats, activeBeat)
  local t = {}
  for i = 1, beats do
    if i == activeBeat then
      t[i] = "●"
    else
      t[i] = "○"
    end
  end
  return table.concat(t, "  ")
end

local function updateUi()
  state.set("bpm", tostring(currentBpm))
  state.set("tempoName", _getTempoTerm(currentBpm))
  state.set("signatureLabel", SIGNATURES[currentSigIdx].name)
end

-- ---------------- UI 事件 ----------------
function onInit()
  currentBpm = 120
  currentSigIdx = 3
  currentBeat = 0
  timerId = nil
  state.set("bpm", "120")
  state.set("tempoName", _getTempoTerm(120))
  state.set("signatureLabel", "4/4 拍")
  state.set("beatDots", "○  ○  ○  ○")
  state.set("isRunning", false)
  state.set("statusText", "就绪 (未播放)")
  state.set("playBtnText", "开始节拍")
end

function onDispose()
  stopMetronome()
end

function adjustBpmMinus5()
  local target = currentBpm - 5
  if target < 40 then target = 40 end
  currentBpm = target
  updateUi()
  if timerId ~= nil then restartTimer() end
end

function adjustBpmMinus1()
  local target = currentBpm - 1
  if target < 40 then target = 40 end
  currentBpm = target
  updateUi()
  if timerId ~= nil then restartTimer() end
end

function adjustBpmPlus1()
  local target = currentBpm + 1
  if target > 240 then target = 240 end
  currentBpm = target
  updateUi()
  if timerId ~= nil then restartTimer() end
end

function adjustBpmPlus5()
  local target = currentBpm + 5
  if target > 240 then target = 240 end
  currentBpm = target
  updateUi()
  if timerId ~= nil then restartTimer() end
end

function cycleSignature()
  currentSigIdx = currentSigIdx % #SIGNATURES + 1
  currentBeat = 0
  local sig = SIGNATURES[currentSigIdx]
  state.set("signatureLabel", sig.name)
  state.set("beatDots", _buildBeatDots(sig.beats, 0))
end

local function onTick()
  local sig = SIGNATURES[currentSigIdx]
  currentBeat = (currentBeat % sig.beats) + 1
  state.set("beatDots", _buildBeatDots(sig.beats, currentBeat))

  if currentBeat == 1 then
    -- 强拍 880Hz
    audio.playTone(880, 0.08)
    haptic.heavy()
  else
    -- 弱拍 440Hz
    audio.playTone(440, 0.05)
    haptic.light()
  end
end

function restartTimer()
  if timerId ~= nil then
    timer.clear(timerId)
    timerId = nil
  end
  local ms = _calcIntervalMs(currentBpm)
  timerId = timer.setInterval(onTick, ms)
end

function togglePlay()
  if timerId ~= nil then
    stopMetronome()
  else
    startMetronome()
  end
end

function startMetronome()
  currentBeat = 0
  restartTimer()
  screen.setKeepScreenOn(true)
  state.set("isRunning", true)
  state.set("playBtnText", "停止节拍")
  state.set("statusText", "节拍运行中 (" .. currentBpm .. " BPM)")
end

function stopMetronome()
  if timerId ~= nil then
    timer.clear(timerId)
    timerId = nil
  end
  screen.setKeepScreenOn(false)
  currentBeat = 0
  local sig = SIGNATURES[currentSigIdx]
  state.set("isRunning", false)
  state.set("playBtnText", "开始节拍")
  state.set("statusText", "已停止")
  state.set("beatDots", _buildBeatDots(sig.beats, 0))
end
