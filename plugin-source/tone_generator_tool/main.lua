-- tone_generator_tool main.lua
-- 音频频率发生器与调音器

local activeFreq = 440.0
local activeDuration = 1000

function _freqToPitchName(freq)
  local f = math.floor(freq + 0.5)
  if f == 440 then
    return "A4 (440 Hz 国际标准音)"
  elseif f == 261 then
    return "C4 (261 Hz 中央 C)"
  elseif f == 329 then
    return "E4 (329 Hz 基础大三度)"
  elseif f == 392 then
    return "G4 (392 Hz 纯五度)"
  else
    return string.format("自定义频率 (%d Hz)", f)
  end
end

function onInit()
  activeFreq = 440.0
  activeDuration = 1000

  state.set("freqHz", "440")
  state.set("currentNote", "A4 (440 Hz 国际标准音)")
  state.set("inputFreq", "440")
  state.set("inputDuration", "1000")
  state.set("statusText", "空闲中，准备就绪")
  return nil
end

function setNoteC4()
  activeFreq = 261.63
  state.set("freqHz", "261")
  state.set("inputFreq", "261")
  state.set("currentNote", _freqToPitchName(261))
  playCurrentTone()
  return nil
end

function setNoteE4()
  activeFreq = 329.63
  state.set("freqHz", "329")
  state.set("inputFreq", "329")
  state.set("currentNote", _freqToPitchName(329))
  playCurrentTone()
  return nil
end

function setNoteG4()
  activeFreq = 392.00
  state.set("freqHz", "392")
  state.set("inputFreq", "392")
  state.set("currentNote", _freqToPitchName(392))
  playCurrentTone()
  return nil
end

function setNoteA4()
  activeFreq = 440.00
  state.set("freqHz", "440")
  state.set("inputFreq", "440")
  state.set("currentNote", _freqToPitchName(440))
  playCurrentTone()
  return nil
end

function playCurrentTone()
  local rawF = state.get("inputFreq")
  local f = tonumber(rawF)
  if f == nil or f < 20 or f > 20000 then
    dialog.toast("频率请输入 20 ~ 20000 Hz 之间的数值")
    return nil
  end

  local rawD = state.get("inputDuration")
  local d = tonumber(rawD)
  if d == nil or d <= 0 then d = 1000 end
  if d > 10000 then d = 10000 end

  activeFreq = f
  activeDuration = d

  state.set("freqHz", tostring(math.floor(f + 0.5)))
  state.set("currentNote", _freqToPitchName(f))
  state.set("statusText", string.format("正在播放 %d Hz (时长 %d ms)...", math.floor(f + 0.5), d))

  audio.playTone(f, d, function(ok)
    state.set("statusText", "播放完成")
    return nil
  end)

  return nil
end

function stopTone()
  audio.stop(function(ok)
    state.set("statusText", "已手动停止发音")
    dialog.toast("发音已停止")
    return nil
  end)
  return nil
end

function onDispose()
  if audio ~= nil and audio.stop ~= nil then
    pcall(function()
      audio.stop()
    end)
  end
  return nil
end
