-- morse_tool — 摩尔斯电码互转
-- 字母 A-Z、数字 0-9 与常用标点; 词间以 "/" 分隔, 不支持的字符跳过/以 ? 呈现

local MORSE = {
  A = ".-", B = "-...", C = "-.-.", D = "-..", E = ".", F = "..-.",
  G = "--.", H = "....", I = "..", J = ".---", K = "-.-", L = ".-..",
  M = "--", N = "-.", O = "---", P = ".--.", Q = "--.-", R = ".-.",
  S = "...", T = "-", U = "..-", V = "...-", W = ".--", X = "-..-",
  Y = "-.--", Z = "--..",
  ["0"] = "-----", ["1"] = ".----", ["2"] = "..---", ["3"] = "...--",
  ["4"] = "....-", ["5"] = ".....", ["6"] = "-....", ["7"] = "--...",
  ["8"] = "---..", ["9"] = "----.",
  ["."] = ".-.-.-", [","] = "--..--", ["?"] = "..--..", ["!"] = "-.-.--",
  ["/"] = "-..-.", ["("] = "-.--.", [")"] = "-.--.-", ["&"] = ".-...",
  [":"] = "---...", [";"] = "-.-.-.", ["="] = "-...-", ["+"] = ".-.-.",
  ["-"] = "-....-", ["_"] = "..--.-", ['"'] = ".-..-.", ["$"] = "...-..-",
  ["@"] = ".--.-.", ["'"] = ".----.",
}

local REV = {}
for k, v in pairs(MORSE) do REV[v] = k end

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

local function trim(s)
  local a = 1
  local b = string.len(s)
  while a <= b and string.sub(s, a, a) == " " do a = a + 1 end
  while b >= a and string.sub(s, b, b) == " " do b = b - 1 end
  if a > b then return "" end
  return string.sub(s, a, b)
end

-- 文本 -> 摩尔斯电码 (词间 "/", 不支持字符跳过, emoji 按代理对整体跳过)
function _encode(text)
  local out = {}
  local n = string.len(text)
  local i = 1
  while i <= n do
    local c = string.byte(text, i)
    local advance = 1
    if c >= 55296 and c <= 56319 and i + 1 <= n then
      local d = string.byte(text, i + 1)
      if d >= 56320 and d <= 57343 then advance = 2 end
    end
    local ch = nil
    if c < 55296 then
      if advance == 1 then ch = string.sub(text, i, i) end
    else
      if c > 57343 then
        if advance == 1 then ch = string.sub(text, i, i) end
      end
    end
    if ch == " " then
      local last = out[#out]
      if last ~= nil and last ~= "/" then out[#out + 1] = "/" end
    elseif ch ~= nil then
      local code = MORSE[string.upper(ch)]
      if code ~= nil then out[#out + 1] = code end
    end
    i = i + advance
  end
  return table.concat(out, " ")
end

-- 摩尔斯电码 -> 文本 (未知码组以 ? 呈现)
function _decode(s)
  local out = {}
  local start = 1
  local n = string.len(s)
  while true do
    local pos = string.find(s, " ", start, true)
    local tok
    if pos == nil then
      tok = string.sub(s, start)
    else
      tok = string.sub(s, start, pos - 1)
    end
    if tok ~= "" then
      if tok == "/" then
        out[#out + 1] = " "
      else
        local ch = REV[tok]
        if ch ~= nil then
          out[#out + 1] = ch
        else
          out[#out + 1] = "?"
        end
      end
    end
    if pos == nil then return table.concat(out) end
    start = pos + 1
  end
end

-- ---------------- 测试钩子 (harness 专用) ----------------

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("morseInput", "")
  state.set("morseResult", "")
  state.set("hasResult", false)
  clearError()
end

function encodeText()
  clearError()
  state.set("hasResult", false)
  local text = state.get("morseInput") or ""
  if trim(text) == "" then
    setError("请输入要编码的文本")
    return nil
  end
  if string.len(text) > 2000 then
    setError("文本过长: 一次最多编码 2000 个字符")
    return nil
  end
  state.set("morseResult", _encode(text))
  state.set("hasResult", true)
end

function decodeText()
  clearError()
  state.set("hasResult", false)
  local text = trim(state.get("morseInput") or "")
  if text == "" then
    setError("请输入要解码的摩尔斯电码")
    return nil
  end
  if string.len(text) > 8000 then
    setError("输入过长")
    return nil
  end
  state.set("morseResult", _decode(text))
  state.set("hasResult", true)
end

function pasteInput()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("morseInput", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
