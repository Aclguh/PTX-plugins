-- text_stats_tool — 文本统计
-- 字符数按码点计 (emoji 为 1 个字符), 字节数为 UTF-8 编码长度;
-- 单词数 = ASCII 字母数字连续段 + CJK 逐字计数

local MAX_INPUT = 50000

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

local function isAsciiAlnum(cp)
  local isDigit = cp >= 48
  if isDigit then isDigit = cp <= 57 end
  local isUpper = cp >= 65
  if isUpper then isUpper = cp <= 90 end
  local isLower = cp >= 97
  if isLower then isLower = cp <= 122 end
  return isDigit or isUpper or isLower
end

-- CJK 统一表意文字及其扩展区 (逐字计为一个词)
local function isCjk(cp)
  local inCjk = cp >= 19968
  if inCjk then inCjk = cp <= 40959 end
  local inExtA = cp >= 13312
  if inExtA then inExtA = cp <= 19903 end
  local inExtB = cp >= 131072
  if inExtB then inExtB = cp <= 173791 end
  local inCompat = cp >= 63744
  if inCompat then inCompat = cp <= 64255 end
  return inCjk or inExtA or inExtB or inCompat
end

local function isWhitespace(cp)
  local isSpace = cp == 32
  local isCtrl = cp >= 9
  if isCtrl then isCtrl = cp <= 13 end
  return isSpace or isCtrl
end

local function splitLines(s)
  local out = {}
  local start = 1
  while true do
    local pos = string.find(s, "\n", start, true)
    if pos == nil then
      out[#out + 1] = string.sub(s, start)
      return out
    end
    out[#out + 1] = string.sub(s, start, pos - 1)
    start = pos + 1
  end
end

-- 文本 -> 码点数组 (重组 UTF-16 代理对, 孤立代理记为 U+FFFD)
local function codepoints(s)
  local out = {}
  local n = string.len(s)
  local i = 1
  while i <= n do
    local c = string.byte(s, i)
    if c >= 55296 and c <= 56319 and i + 1 <= n then
      local d = string.byte(s, i + 1)
      if d >= 56320 and d <= 57343 then
        out[#out + 1] = 65536 + (c - 55296) * 1024 + (d - 56320)
        i = i + 2
      else
        out[#out + 1] = 65533
        i = i + 1
      end
    elseif c >= 55296 then
      if c <= 57343 then
        out[#out + 1] = 65533
        i = i + 1
      else
        out[#out + 1] = c
        i = i + 1
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  return out
end

local function utf8Len(cp)
  if cp >= 55296 then
    if cp <= 57343 then return 3 end -- U+FFFD
  end
  if cp < 128 then return 1 end
  local two = cp < 2048
  if two then return 2 end
  local three = cp < 65536
  if three then return 3 end
  return 4
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _stats(text)
  local cps = codepoints(text)
  local chars = #cps
  local bytes = 0
  local words = 0
  local digits = 0
  local spaces = 0
  local inWord = false
  for i = 1, chars do
    local cp = cps[i]
    bytes = bytes + utf8Len(cp)
    if isCjk(cp) then
      words = words + 1
      inWord = false
    else
      if isAsciiAlnum(cp) then
        if not inWord then
          words = words + 1
          inWord = true
        end
      else
        inWord = false
      end
      if cp >= 48 then
        if cp <= 57 then digits = digits + 1 end
      end
      if isWhitespace(cp) then spaces = spaces + 1 end
    end
  end

  local lines = splitLines(text)
  local lineCount = #lines
  local nonEmpty = 0
  local paras = 0
  local prevBlank = true
  for _, line in ipairs(lines) do
    local blank = trim(line) == ""
    if not blank then
      nonEmpty = nonEmpty + 1
      if prevBlank then paras = paras + 1 end
    end
    prevBlank = blank
  end

  return {
    chars = chars,
    bytes = bytes,
    lines = lineCount,
    nonEmpty = nonEmpty,
    words = words,
    paras = paras,
    spaces = spaces,
    digits = digits,
  }
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("statsInput", "")
  state.set("statsText", "")
  state.set("hasStats", false)
  clearError()
end

function computeStats()
  clearError()
  state.set("hasStats", false)
  local text = state.get("statsInput") or ""
  if text == "" then
    setError("请输入要统计的文本")
    return nil
  end
  if string.len(text) > MAX_INPUT then
    setError("文本过长: 一次最多统计 " .. MAX_INPUT .. " 个字符")
    return nil
  end
  local s = _stats(text)
  local lines = {
    "字符数 (码点): " .. s.chars,
    "UTF-8 字节数: " .. s.bytes,
    "总行数: " .. s.lines .. " · 非空行: " .. s.nonEmpty,
    "段落数: " .. s.paras,
    "单词数: " .. s.words .. " (CJK 逐字计)",
    "数字字符: " .. s.digits .. " · 空白字符: " .. s.spaces,
  }
  state.set("statsText", table.concat(lines, "\n"))
  state.set("hasStats", true)
end

function pasteInput()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("statsInput", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
