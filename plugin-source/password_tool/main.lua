-- password_tool — 随机密码生成
-- 熵源: util.uuid() 去连字符后每两个十六进制字符合成一个字节 (0-255);
-- 取模以 rejection sampling 消除偏差; 强度按 len * log2(字符集大小) 估算

local HEXD = "0123456789ABCDEF"
local UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local LOWER = "abcdefghijklmnopqrstuvwxyz"
local DIGIT = "0123456789"
local SYMBOL = "!@#$%^&*()-_=+[]{};:,.?"

local MIN_LEN = 4
local MAX_LEN = 64

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

-- 从熵流取一个 < limit 的字节 (limit 为 setSize 的最大 256 倍数以下界)
-- 索引自 1 起: 空表 # 为 0, 若自 0 起则 0 > 0 为假会取出 nil 参与比较
local entropyBytes, entropyIdx = {}, 1

local function refillEntropy()
  local u = string.upper(util.uuid())
  local hexChars = {}
  for j = 1, string.len(u) do
    local ch = string.sub(u, j, j)
    if ch ~= "-" then hexChars[#hexChars + 1] = ch end
  end
  entropyBytes = {}
  local j = 1
  while j + 1 <= #hexChars do
    local hi = string.find(HEXD, hexChars[j], 1, true) - 1
    local lo = string.find(HEXD, hexChars[j + 1], 1, true) - 1
    entropyBytes[#entropyBytes + 1] = hi * 16 + lo
    j = j + 2
  end
  entropyIdx = 1
end

local function nextRandom(limit)
  while true do
    if entropyIdx > #entropyBytes then refillEntropy() end
    local b = entropyBytes[entropyIdx]
    entropyIdx = entropyIdx + 1
    if b < limit then return b end
  end
end

-- 字符集串 pool -> 取 n 个字符的密码
function _genPassword(n, pool)
  local setSize = string.len(pool)
  if setSize == 0 then return nil, "请至少选择一种字符类型" end
  local limit = 256 - (256 % setSize)
  local out = {}
  for i = 1, n do
    local b = nextRandom(limit)
    local idx = b % setSize + 1
    out[i] = string.sub(pool, idx, idx)
  end
  return table.concat(out), nil, setSize
end

-- 强度标签: bits = n * log2(setSize)
function _strengthLabel(bits)
  if bits < 28 then return "弱 (" .. string.format("%.0f", bits) .. " bits)" end
  if bits < 36 then return "中 (" .. string.format("%.0f", bits) .. " bits)" end
  if bits < 60 then return "强 (" .. string.format("%.0f", bits) .. " bits)" end
  return "极强 (" .. string.format("%.0f", bits) .. " bits)"
end

function _log2(setSize)
  return math.log(setSize) / math.log(2)
end

-- ---------------- 测试钩子 (harness 专用) ----------------

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("pwLen", "16")
  state.set("pwResult", "")
  state.set("pwStrength", "")
  state.set("hasResult", false)
  state.set("useUpper", true)
  state.set("useLower", true)
  state.set("useDigit", true)
  state.set("useSymbol", false)
  state.set("upLbl", "大写 A-Z: 已选")
  state.set("lowLbl", "小写 a-z: 已选")
  state.set("digitLbl", "数字 0-9: 已选")
  state.set("symbolLbl", "符号: 未选")
  clearError()
end

local function refreshToggleLabels()
  local lbl = "未选"
  if state.get("useUpper") then lbl = "已选" end
  state.set("upLbl", "大写 A-Z: " .. lbl)
  lbl = "未选"
  if state.get("useLower") then lbl = "已选" end
  state.set("lowLbl", "小写 a-z: " .. lbl)
  lbl = "未选"
  if state.get("useDigit") then lbl = "已选" end
  state.set("digitLbl", "数字 0-9: " .. lbl)
  lbl = "未选"
  if state.get("useSymbol") then lbl = "已选" end
  state.set("symbolLbl", "符号: " .. lbl)
end

local function flip(key)
  local cur = state.get(key)
  if cur then
    state.set(key, false)
  else
    state.set(key, true)
  end
end

function toggleUpper()
  flip("useUpper")
  refreshToggleLabels()
end

function toggleLower()
  flip("useLower")
  refreshToggleLabels()
end

function toggleDigit()
  flip("useDigit")
  refreshToggleLabels()
end

function toggleSymbol()
  flip("useSymbol")
  refreshToggleLabels()
end

function generate()
  clearError()
  state.set("hasResult", false)
  local len = math.floor(tonumber(state.get("pwLen")) or 0)
  if len < MIN_LEN then
    setError("长度需在 " .. MIN_LEN .. "-" .. MAX_LEN .. " 之间")
    return nil
  end
  if len > MAX_LEN then
    setError("长度需在 " .. MIN_LEN .. "-" .. MAX_LEN .. " 之间")
    return nil
  end
  local pool = ""
  if state.get("useUpper") then pool = pool .. UPPER end
  if state.get("useLower") then pool = pool .. LOWER end
  if state.get("useDigit") then pool = pool .. DIGIT end
  if state.get("useSymbol") then pool = pool .. SYMBOL end
  local pw, err, setSize = _genPassword(len, pool)
  if pw == nil then
    setError(err)
    return nil
  end
  state.set("pwResult", pw)
  state.set("pwStrength", _strengthLabel(len * _log2(setSize)))
  state.set("hasResult", true)
end
