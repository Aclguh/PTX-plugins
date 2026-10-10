-- barcode_tool: 一维条形码生成器 (Code 128 / EAN-13 / Code 39)

local eanL = {
  ["0"] = "0001101", ["1"] = "0011001", ["2"] = "0010011", ["3"] = "0111101", ["4"] = "0100011",
  ["5"] = "0110001", ["6"] = "0101111", ["7"] = "0111011", ["8"] = "0110111", ["9"] = "0001011"
}
local eanG = {
  ["0"] = "0100111", ["1"] = "0110011", ["2"] = "0011011", ["3"] = "0100001", ["4"] = "0011101",
  ["5"] = "0111001", ["6"] = "0000101", ["7"] = "0010001", ["8"] = "0001001", ["9"] = "0010111"
}
local eanR = {
  ["0"] = "1110010", ["1"] = "1100110", ["2"] = "1101100", ["3"] = "1000010", ["4"] = "1011100",
  ["5"] = "1001110", ["6"] = "1010000", ["7"] = "1000100", ["8"] = "1001000", ["9"] = "1110100"
}

local eanParity = {
  ["0"] = "LLLLLL", ["1"] = "LLGLGG", ["2"] = "LLGGLG", ["3"] = "LLGGGL", ["4"] = "LGLLGG",
  ["5"] = "LGGLLG", ["6"] = "LGGGLL", ["7"] = "LGLGLG", ["8"] = "LGLGGL", ["9"] = "LGGLGL"
}

-- Code 39 patterns (9 elements: b s b s b s b s b, where 1=wide, 0=narrow)
local c39Patterns = {
  ["0"] = "000110100", ["1"] = "100100001", ["2"] = "001100001", ["3"] = "101100000",
  ["4"] = "000110001", ["5"] = "100110000", ["6"] = "001110000", ["7"] = "000100101",
  ["8"] = "100100100", ["9"] = "001100100", ["A"] = "100001001", ["B"] = "001001001",
  ["C"] = "101001000", ["D"] = "000011001", ["E"] = "100011000", ["F"] = "001011000",
  ["G"] = "000001101", ["H"] = "100001100", ["I"] = "001001100", ["J"] = "000011100",
  ["K"] = "100000011", ["L"] = "001000011", ["M"] = "101000010", ["N"] = "000010011",
  ["O"] = "100010010", ["P"] = "001010010", ["Q"] = "000000111", ["R"] = "100000110",
  ["S"] = "001000110", ["T"] = "000010110", ["U"] = "110000001", ["V"] = "011000001",
  ["W"] = "111000000", ["X"] = "010010001", ["Y"] = "110010000", ["Z"] = "011010000",
  ["-"] = "010000101", ["."] = "110000100", [" "] = "011000100", ["$"] = "010101000",
  ["/"] = "010100010", ["+"] = "010001010", ["%"] = "000101010", ["*"] = "010010100"
}

-- Code 128 (Set B) patterns for values 0..106
-- 每个字符用 6 位交替宽度的条空 run-lengths 表示 (106 项平铺为 636 字符字串, 避免 VM 表构造超限)
local c128Flat = "212222222122222221121223121322131222122213122312132212221213221312231212112232122132122231113222123122123221223211221132221231213212223112312131311222321122321221312212322112322211212123212321232121111323131123131321112313132113132311211313231113231311112133112331132131113123113321133121313121211331231131213113213311213131311123311321331121312113312311332111314111221411431111111224111422121124121421141122141221112214112412122114122411142112142211241211221114413111241112134111111242121142121241114212124112124211411212421112421211212141214121412121111143111341131141114113114311411113411311113141114131311141411131211412211214211232"

local function getC128Runs(idx)
  if idx == 106 then
    return "2331112"
  end
  local startPos = (idx * 6) + 1
  return string.sub(c128Flat, startPos, startPos + 5)
end

local function runsToModules(runs)
  local res = ""
  local isBar = true
  local len = string.len(runs)
  local i = 1
  while i <= len do
    local cnt = string.byte(runs, i) - 48
    local ch = "0"
    if isBar then
      ch = "1"
    end
    local k = 1
    while k <= cnt do
      res = res .. ch
      k = k + 1
    end
    if isBar then
      isBar = false
    else
      isBar = true
    end
    i = i + 1
  end
  return res
end

local function encodeCode128(text)
  local len = string.len(text)
  if len == 0 then
    return nil, "输入内容不可为空"
  end
  local checkSum = 104
  local modules = runsToModules(getC128Runs(104))
  local i = 1
  while i <= len do
    local code = string.byte(text, i)
    if code < 32 then
      return nil, "Code 128B 不支持 ASCII 32 以下字符"
    end
    if code > 127 then
      return nil, "仅支持 ASCII 字符"
    end
    local val = code - 32
    checkSum = checkSum + (i * val)
    modules = modules .. runsToModules(getC128Runs(val))
    i = i + 1
  end
  local checkVal = checkSum % 103
  modules = modules .. runsToModules(getC128Runs(checkVal))
  modules = modules .. runsToModules(getC128Runs(106))
  return modules, nil
end

local function encodeEan13(raw)
  local text = ""
  local len = string.len(raw)
  local i = 1
  while i <= len do
    local b = string.byte(raw, i)
    if b >= 48 then
      if b <= 57 then
        text = text .. string.sub(raw, i, i)
      end
    end
    i = i + 1
  end

  local tLen = string.len(text)
  if tLen == 12 then
    -- 计算校验位
    local sumOdd = 0
    local sumEven = 0
    local j = 1
    while j <= 12 do
      local d = string.byte(text, j) - 48
      if (j % 2) == 1 then
        sumOdd = sumOdd + d
      else
        sumEven = sumEven + d
      end
      j = j + 1
    end
    local checkD = (10 - ((sumOdd + (sumEven * 3)) % 10)) % 10
    text = text .. tostring(checkD)
  end

  if string.len(text) ~= 13 then
    return nil, "EAN-13 需要 12 位或 13 位纯数字"
  end

  local firstDigit = string.sub(text, 1, 1)
  local parity = eanParity[firstDigit]
  if parity == nil then
    parity = "LLLLLL"
  end

  local modules = "101" -- 左护线
  -- 左侧 6 个数字 (位置 2 到 7)
  local k = 2
  while k <= 7 do
    local dStr = string.sub(text, k, k)
    local p = string.sub(parity, k - 1, k - 1)
    if p == "L" then
      modules = modules .. eanL[dStr]
    else
      modules = modules .. eanG[dStr]
    end
    k = k + 1
  end

  modules = modules .. "01010" -- 中置线

  -- 右侧 6 个数字 (位置 8 到 13)
  k = 8
  while k <= 13 do
    local dStr = string.sub(text, k, k)
    modules = modules .. eanR[dStr]
    k = k + 1
  end

  modules = modules .. "101" -- 右护线
  return modules, text
end

local function charToModules(pat)
  local s = ""
  local pLen = string.len(pat)
  local idx = 1
  while idx <= pLen do
    local isBar = (idx % 2) == 1
    local isWide = string.sub(pat, idx, idx) == "1"
    local fill = "0"
    if isBar then
      fill = "1"
    end
    local count = 1
    if isWide then
      count = 3
    end
    local c = 1
    while c <= count do
      s = s .. fill
      c = c + 1
    end
    idx = idx + 1
  end
  return s
end

local function encodeCode39(raw)
  local text = string.upper(raw)
  local len = string.len(text)
  if len == 0 then
    return nil, "输入内容不可为空"
  end
  local i = 1
  while i <= len do
    local ch = string.sub(text, i, i)
    if c39Patterns[ch] == nil then
      return nil, "Code 39 不支持字符: " .. ch
    end
    i = i + 1
  end

  local modules = charToModules(c39Patterns["*"]) .. "0"
  i = 1
  while i <= len do
    local ch = string.sub(text, i, i)
    modules = modules .. charToModules(c39Patterns[ch]) .. "0"
    i = i + 1
  end
  modules = modules .. charToModules(c39Patterns["*"])
  return modules, nil
end

function generate()
  local bType = state.get("barcodeType")
  if bType == nil then
    bType = "code128"
  end
  local content = state.get("inputContent")
  if content == nil then
    content = ""
  end

  local modules = nil
  local err = nil
  local finalDisplay = content

  if bType == "code128" then
    modules, err = encodeCode128(content)
  elseif bType == "ean13" then
    local m, fullText = encodeEan13(content)
    modules = m
    if m ~= nil then
      finalDisplay = fullText
    else
      err = fullText
    end
  elseif bType == "code39" then
    modules, err = encodeCode39(content)
  else
    err = "不支持的条码类型"
  end

  if modules ~= nil then
    state.set("hasResult", true)
    state.set("hasError", false)
    state.set("errorMsg", "")
    state.set("barsPattern", modules)
    state.set("displayText", finalDisplay)
    state.set("totalModules", string.len(modules))
  else
    state.set("hasResult", false)
    state.set("hasError", true)
    if err ~= nil then
      state.set("errorMsg", err)
    else
      state.set("errorMsg", "条形码生成失败")
    end
  end
  return nil
end

function onInit()
  state.set("barcodeType", "code128")
  state.set("inputContent", "PTX-2026-TOOL")
  state.set("barsPattern", "")
  state.set("displayText", "")
  state.set("totalModules", 0)
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  generate()
  return nil
end

function setType(t)
  state.set("barcodeType", t)
  if t == "ean13" then
    state.set("inputContent", "690123456789")
  elseif t == "code39" then
    state.set("inputContent", "CODE-39-EX")
  else
    state.set("inputContent", "PTX-2026-TOOL")
  end
  generate()
  return nil
end

function copyPattern()
  local pat = state.get("barsPattern")
  if pat ~= nil then
    clipboard.set(pat)
    dialog.toast("已复制条码二进制流")
  end
  return nil
end

function copyText()
  local txt = state.get("displayText")
  if txt ~= nil then
    clipboard.set(txt)
    dialog.toast("已复制条码文本")
  end
  return nil
end

function clearAll()
  state.set("inputContent", "")
  state.set("hasResult", false)
  state.set("barsPattern", "")
  state.set("displayText", "")
  state.set("totalModules", 0)
  return nil
end
