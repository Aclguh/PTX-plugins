-- dice_tool — 掷骰子与随机决策
-- 随机性来自宿主 math.random, onInit 以毫秒时间戳播种;
-- 区间取数统一平移到正数域调用 math.random(1, n) 再平移回来

local SIDES = { 2, 4, 6, 8, 10, 12, 20, 100 }
local sidesIdx = 3 -- 默认 6 面

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

local function splitLines(s)
  local outList = {}
  local start = 1
  while true do
    local pos = string.find(s, "\n", start, true)
    if pos == nil then
      outList[#outList + 1] = string.sub(s, start)
      return outList
    end
    outList[#outList + 1] = string.sub(s, start, pos - 1)
    start = pos + 1
  end
end

-- 整数解析: 非法或带小数返回 nil
function _toInt(s)
  local n = tonumber(s)
  if n == nil then return nil end
  if n ~= math.floor(n) then return nil end
  return n
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _currentSides()
  return SIDES[sidesIdx]
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  math.randomseed(util.timestampMs() % 2147483647)
  state.set("diceCount", "3")
  state.set("sidesLbl", "面数: 6")
  state.set("diceResult", "")
  state.set("hasDice", false)
  state.set("optInput", "")
  state.set("chosen", "")
  state.set("hasChosen", false)
  state.set("rndMin", "1")
  state.set("rndMax", "100")
  state.set("rndOut", "")
  state.set("hasRnd", false)
  clearError()
end

function cycleSides()
  sidesIdx = sidesIdx % #SIDES + 1
  state.set("sidesLbl", "面数: " .. SIDES[sidesIdx])
end

function rollDice()
  clearError()
  state.set("hasDice", false)
  local count = _toInt(state.get("diceCount") or "")
  if count == nil then
    setError("骰子数量必须为整数")
    return nil
  end
  if count < 1 then
    setError("骰子数量至少为 1")
    return nil
  end
  if count > 10 then
    setError("骰子数量最多 10 颗")
    return nil
  end
  local sides = SIDES[sidesIdx]
  local parts = {}
  local sum = 0
  for i = 1, count do
    local v = math.random(1, sides)
    parts[i] = tostring(v)
    sum = sum + v
  end
  local line = "总点数: " .. sum .. " (" .. table.concat(parts, " + ") .. ")"
  if count == 1 then
    line = "点数: " .. sum
  end
  state.set("diceResult", line)
  state.set("hasDice", true)
end

function pickOption()
  clearError()
  state.set("hasChosen", false)
  local raw = state.get("optInput") or ""
  local items = {}
  local lines = splitLines(raw)
  for _, line in ipairs(lines) do
    local t = trim(line)
    if t ~= "" then
      items[#items + 1] = t
    end
  end
  if #items < 2 then
    setError("请输入至少两个候选选项（每行一个）")
    return nil
  end
  if #items > 100 then
    setError("候选选项最多 100 个")
    return nil
  end
  local k = math.random(1, #items)
  state.set("chosen", "第 " .. k .. " / " .. #items .. " 项: " .. items[k])
  state.set("hasChosen", true)
end

function drawRange()
  clearError()
  state.set("hasRnd", false)
  local lo = tonumber(state.get("rndMin") or "")
  local hi = tonumber(state.get("rndMax") or "")
  if lo == nil then
    setError("最小值必须为数字")
    return nil
  end
  if hi == nil then
    setError("最大值必须为数字")
    return nil
  end
  lo = math.floor(lo)
  hi = math.floor(hi)
  if lo > hi then
    local tmp = lo
    lo = hi
    hi = tmp
  end
  if lo < -100000000 then
    setError("数值范围请控制在 ±1 亿以内")
    return nil
  end
  if hi > 100000000 then
    setError("数值范围请控制在 ±1 亿以内")
    return nil
  end
  -- 平移到正数域再取随机, 规避实现层对负数参数的兼容差异
  local v = math.random(1, hi - lo + 1) + lo - 1
  state.set("rndOut", tostring(v))
  state.set("hasRnd", true)
end
