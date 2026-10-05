-- radix_tool — 进制转换器 (2/8/10/16 互转)
-- 除基取余拼串 / 逐位加权求和, 双精度整数精确域 |n| <= 2^53 内精确

local DIGITS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local MAX_SAFE = 9007199254740992 -- 2^53

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

-- 非负整数 -> base 进制串 (2 <= base <= 36), 大写字母
-- 注意: 沙箱中 / 产生浮点而 string.sub 拒绝浮点索引, 除法结果必须 floor 回整数
function _toBase(n, base)
  if n == 0 then return "0" end
  local out = {}
  while n > 0 do
    local r = n % base
    local idx = math.floor(r) + 1
    out[#out + 1] = string.sub(DIGITS, idx, idx)
    n = math.floor((n - r) / base)
  end
  local rev = {}
  for i = #out, 1, -1 do rev[#rev + 1] = out[i] end
  return table.concat(rev)
end

-- base 进制串 -> 非负整数; 非法字符或超 2^53 返回 nil
function _fromBase(s, base)
  if base < 2 then return nil end
  if base > 36 then return nil end
  if s == "" then return nil end
  local n = 0
  for i = 1, string.len(s) do
    local v = string.find(DIGITS, string.sub(s, i, i), 1, true)
    if v == nil then return nil end
    if v - 1 >= base then return nil end
    n = n * base + (v - 1)
    if n > MAX_SAFE then return nil end
  end
  return n
end

-- 带符号解析 (支持前导 '-'), 返回整数或 nil
function _parseSigned(s, base)
  local neg = false
  if string.sub(s, 1, 1) == "-" then
    neg = true
    s = string.sub(s, 2)
  end
  local n = _fromBase(s, base)
  if n == nil then return nil end
  if neg then return -n end
  return n
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _trim(s)
  return trim(s)
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("decInput", "")
  state.set("srcInput", "")
  state.set("decBin", "")
  state.set("decOct", "")
  state.set("decHex", "")
  state.set("srcDec", "")
  state.set("hasDecResult", false)
  state.set("hasSrcResult", false)
  clearError()
end

function decToAll()
  clearError()
  state.set("hasDecResult", false)
  local raw = trim(state.get("decInput") or "")
  if raw == "" then
    setError("请输入十进制整数")
    return nil
  end
  local n = _parseSigned(raw, 10)
  if n == nil then
    setError("输入不合法或超出 2^53 精确范围")
    return nil
  end
  local neg = n < 0
  local abs = n
  if neg then abs = -n end
  local sign = ""
  if neg then sign = "-" end
  state.set("decBin", sign .. _toBase(abs, 2))
  state.set("decOct", sign .. _toBase(abs, 8))
  state.set("decHex", sign .. _toBase(abs, 16))
  state.set("hasDecResult", true)
end

function fromBase(b)
  clearError()
  state.set("hasSrcResult", false)
  local base = math.floor(tonumber(b) or 0)
  local raw = string.upper(trim(state.get("srcInput") or ""))
  if raw == "" then
    setError("请输入待转换的数字")
    return nil
  end
  if base < 2 then
    setError("不支持的进制")
    return nil
  end
  if base > 36 then
    setError("不支持的进制")
    return nil
  end
  local n = _parseSigned(raw, base)
  if n == nil then
    setError("输入含 " .. base .. " 进制之外的字符或超出 2^53 精确范围")
    return nil
  end
  state.set("srcDec", string.format("%d", n))
  state.set("hasSrcResult", true)
end

function fromBin()
  fromBase(2)
end

function fromOct()
  fromBase(8)
end

function fromHex()
  fromBase(16)
end
