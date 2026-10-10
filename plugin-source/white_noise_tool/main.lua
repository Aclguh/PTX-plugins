-- white_noise_tool: 助眠白噪音与多频段混音发生器

local currentType = "pink"
local durationMins = 30
local volumeLevel = 70
local isRunning = false

local function getNoiseProfile(typ)
  if typ == "white" then
    return {
      title = "全频白噪音 (White Noise)",
      desc = "各频段能量均匀分布，有效掩蔽交谈声与突发杂音，适合高压专注与屏蔽办公区干扰。",
      freq = "20 Hz ~ 20,000 Hz 均衡能量"
    }
  elseif typ == "brown" then
    return {
      title = "深沉布朗噪音 (Brownian Noise)",
      desc = "低频能量衰减更深，类似深海远浪与瀑布低沉轰鸣，适合极度焦虑放松与婴儿哄睡。",
      freq = "以 -6 dB/Octave 低频下潜"
    }
  elseif typ == "rain" then
    return {
      title = "自然夜雨淅淅 (Rain Soundscape)",
      desc = "模拟屋檐窗外的柔和雨声与远雷微鸣，营造宁静安全感，舒缓大脑紧绷神经。",
      freq = "有机声场频谱动态扰动"
    }
  elseif typ == "alpha" then
    return {
      title = "10Hz Alpha 专注双耳节拍",
      desc = "通过左右耳微弱频差诱导大脑进入 10Hz Alpha 波清醒放松状态，激发创造力与深度心流。",
      freq = "载波 220Hz + 频差 10Hz"
    }
  else
    return {
      title = "舒缓粉红噪音 (Pink Noise)",
      desc = "能量随频率递减 (1/f)，符合自然界声学规律，被多项睡眠研究所推崇的助眠黄金声学。",
      freq = "1/f 均衡粉红频谱分布"
    }
  end
end

function setNoise(typ)
  currentType = typ
  local p = getNoiseProfile(typ)
  state.set("noiseTitle", p.title)
  state.set("noiseDesc", p.desc)
  state.set("noiseFreq", "频段特性: " .. p.freq)
  state.set("statusMsg", "已就绪: " .. p.title)
  storage.set("last_noise_type", typ)
  return nil
end

function setDuration(m)
  durationMins = tonumber(m) or 30
  state.set("durationLabel", tostring(durationMins) .. " 分钟")
  state.set("statusMsg", "定时倒计时已设为 " .. tostring(durationMins) .. " 分钟")
  return nil
end

function adjustVolume(delta)
  volumeLevel = volumeLevel + tonumber(delta)
  if volumeLevel < 0 then volumeLevel = 0 end
  if volumeLevel > 100 then volumeLevel = 100 end
  state.set("volumeLabel", tostring(volumeLevel) .. " %")
  return nil
end

function togglePlay()
  isRunning = not isRunning
  state.set("isPlaying", isRunning)
  if isRunning then
    haptic.light()
    state.set("playButtonText", "停止播放")
    state.set("statusMsg", "正在持续播放中... (定时 " .. tostring(durationMins) .. " 分钟后自动淡出停止)")
    dialog.toast("开始沉浸音频体验")
  else
    state.set("playButtonText", "开始播放")
    state.set("statusMsg", "音频已暂停")
    dialog.toast("播放已停止")
  end
  return nil
end

function copyConfig()
  local p = getNoiseProfile(currentType)
  local info = "【白噪音与助眠方案】\n" ..
    "- 声学类型: " .. p.title .. "\n" ..
    "- 声谱特性: " .. p.freq .. "\n" ..
    "- 播放音量: " .. tostring(volumeLevel) .. "%\n" ..
    "- 定时倒计: " .. tostring(durationMins) .. " 分钟\n" ..
    "- 方案简介: " .. p.desc
  clipboard.set(info)
  dialog.toast("已复制当前声场配置")
  return nil
end

function onInit()
  currentType = "pink"
  durationMins = 30
  volumeLevel = 70
  isRunning = false

  state.set("isPlaying", false)
  state.set("playButtonText", "开始播放")
  state.set("durationLabel", "30 分钟")
  state.set("volumeLabel", "70 %")
  setNoise("pink")
  return nil
end
