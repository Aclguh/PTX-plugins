-- morse_light_tool — 摩斯电码光信号发射器
-- 将字母数字转为摩尔斯电码并通过手机手电筒发送光脉冲

local MORSE_MAP = {
  A = ".-", B = "-...", C = "-.-.", D = "-..", E = ".",
  F = "..-.", G = "--.", H = "....", I = "..", J = ".---",
  K = "-.-", L = ".-..", M = "--", N = "-.", O = "---",
  P = ".--.", Q = "--.-", R = ".-.", S = "...", T = "-",
  U = "..-", V = "...-", W = ".--", X = "-..-", Y = "-.--",
  Z = "--..",
  ["0"] = "-----", ["1"] = ".----", ["2"] = "..---", ["3"] = "...--",
  ["4"] = "....-", ["5"] = ".....", ["6"] = "-....", ["7"] = "--...",
  ["8"] = "---..", ["9"] = "----."
}

local isFlashing = false
local currentTimerId = nil
local signalQueue = {} -- list of { on = bool, duration = ms }
local queueIndex = 1

function _textToMorse(text)
  if text == nil then return "" end
  local len = string.len(text)
  local result = {}
  for i = 1, len do
    local ch = string.upper(string.sub(text, i, i))
    if ch == " " then
      result[#result + 1] = "/"
    else
      local code = MORSE_MAP[ch]
      if code ~= nil then
        result[#result + 1] = code
      end
    end
  end
  return table.concat(result, " ")
end

local function buildSignalQueue(morseStr, unitMs)
  local u = unitMs or 200
  local q = {}
  local len = string.len(morseStr)
  for i = 1, len do
    local ch = string.sub(morseStr, i, i)
    if ch == "." then
      q[#q + 1] = { on = true, duration = u }
      q[#q + 1] = { on = false, duration = u } -- intra-char gap
    elseif ch == "-" then
      q[#q + 1] = { on = true, duration = u * 3 }
      q[#q + 1] = { on = false, duration = u } -- intra-char gap
    elseif ch == " " then
      q[#q + 1] = { on = false, duration = u * 2 } -- letter gap (with previous = 3 units)
    elseif ch == "/" then
      q[#q + 1] = { on = false, duration = u * 6 } -- word gap
    end
  end
  return q
end

local function stepSignal()
  if not isFlashing then return nil end
  if queueIndex > #signalQueue then
    stopFlashing()
    state.set("statusMsg", "光信号发送完成")
    dialog.toast("光信号发送完毕")
    return nil
  end

  local item = signalQueue[queueIndex]
  queueIndex = queueIndex + 1

  if item.on then
    torch.on()
    state.set("torchStateText", "手电筒: 发光中 [●]")
  else
    torch.off()
    state.set("torchStateText", "手电筒: 熄灭中 [○]")
  end

  currentTimerId = timer.setTimeout(function()
    stepSignal()
    return nil
  end, item.duration)
end

-- ---------------- UI 事件 ----------------
function onInit()
  isFlashing = false
  currentTimerId = nil
  signalQueue = {}
  queueIndex = 1

  state.set("inputText", "SOS")
  state.set("morsePreview", "... --- ...")
  state.set("isFlashing", false)
  state.set("torchStateText", "手电筒: 待命中")
  state.set("statusMsg", "点击「发射 SOS」或输入内容后开始")
end

function onDispose()
  stopFlashing()
end

function setSosText()
  state.set("inputText", "SOS")
  state.set("morsePreview", "... --- ...")
  state.set("statusMsg", "已载入 SOS 国际紧急求救信号")
end

function updateMorse()
  local txt = state.get("inputText") or ""
  local morse = _textToMorse(txt)
  state.set("morsePreview", morse)
  state.set("statusMsg", "已转换摩尔斯码")
end

function startFlashing()
  local txt = state.get("inputText") or ""
  if string.len(txt) == 0 then
    dialog.toast("请输入要发送的文本")
    return nil
  end

  local morse = _textToMorse(txt)
  state.set("morsePreview", morse)
  if string.len(morse) == 0 then
    dialog.toast("未能转换为有效摩斯码")
    return nil
  end

  signalQueue = buildSignalQueue(morse, 200)
  queueIndex = 1
  isFlashing = true
  state.set("isFlashing", true)
  state.set("statusMsg", "正在发射光脉冲信号...")
  stepSignal()
end

function stopFlashing()
  isFlashing = false
  if currentTimerId ~= nil then
    timer.clear(currentTimerId)
    currentTimerId = nil
  end
  torch.off()
  state.set("isFlashing", false)
  state.set("torchStateText", "手电筒: 已熄灭")
  state.set("statusMsg", "已停止发射")
end

function copyMorse()
  local m = state.get("morsePreview") or ""
  if string.len(m) == 0 then
    dialog.toast("暂无电码可复制")
    return nil
  end
  clipboard.set(m)
  dialog.toast("已复制摩斯电码")
end
