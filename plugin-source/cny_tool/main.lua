-- cny_tool — 数字金额转人民币大写
-- 全程字符串运算 (不用浮点), 支持负数、两位小数与第三位四舍五入;
-- 整数部分最多 12 位 (到万亿), 角分按央行规范处理 (分位为零时补"整")

local DIGITS = { "零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖" }
local UNITS = { "", "拾", "佰", "仟" }
local GROUPS = { "", "万", "亿" }
local NUMS = "0123456789"

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

-- 十进制整数字符串 +1 (处理进位)
local function incInt(s)
  local digits = {}
  for i = 1, string.len(s) do
    digits[i] = tonumber(string.sub(s, i, i))
  end
  local i = #digits
  local carry = true
  while i >= 1 and carry do
    digits[i] = digits[i] + 1
    if digits[i] > 9 then
      digits[i] = 0
      i = i - 1
    else
      carry = false
    end
  end
  if carry then
    return "1" .. table.concat(digits)
  end
  local out = {}
  for k = 1, #digits do out[k] = tostring(digits[k]) end
  return table.concat(out)
end

-- 4 位数字组 -> 汉字 (组内零合并, 不带组后缀); "0000" 返回 ""
local function groupToCny(gstr)
  local out = {}
  local needZero = false
  for pos = 1, 4 do
    local d = tonumber(string.sub(gstr, pos, pos))
    if d == 0 then
      needZero = true
    else
      if needZero then out[#out + 1] = "零" end
      out[#out + 1] = DIGITS[d + 1]
      out[#out + 1] = UNITS[5 - pos]
      needZero = false
    end
  end
  return table.concat(out)
end

-- 整数字符串 -> 大写 (去前导零, 按 4 位分组, 处理跨组零); "0" 返回 ""
local function intToCny(intStr)
  while string.len(intStr) > 1 and string.sub(intStr, 1, 1) == "0" do
    intStr = string.sub(intStr, 2)
  end
  if intStr == "0" then return "" end
  local n = string.len(intStr)
  local pad = (4 - n % 4) % 4
  local padded = string.rep("0", pad) .. intStr
  local groupCount = string.len(padded) / 4
  local out = {}
  local needGroupZero = false
  for g = 1, groupCount do
    local gstr = string.sub(padded, (g - 1) * 4 + 1, g * 4)
    local gtxt = groupToCny(gstr)
    if gtxt == "" then
      needGroupZero = true
    else
      if g > 1 then
        if needGroupZero then
          -- 组内已带前导零时不重复补跨组零, 避免出现两个"零"
          if string.sub(gtxt, 1, string.len("零")) ~= "零" then
            out[#out + 1] = "零"
          end
          needGroupZero = false
        end
      end
      out[#out + 1] = gtxt .. GROUPS[groupCount - g + 1]
    end
  end
  local res = table.concat(out)
  -- 最高组内前导零不发音 (如 0100 -> 壹佰 而非 零壹佰)
  while string.sub(res, 1, string.len("零")) == "零" do
    res = string.sub(res, string.len("零") + 1)
  end
  return res
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _groupToCny(gstr)
  return groupToCny(gstr)
end

function _intToCny(intStr)
  return intToCny(intStr)
end

-- 金额字符串 -> 人民币大写; 非法返回 nil, err
function _toCny(raw)
  local s = trim(raw)
  if s == "" then return nil, "请输入金额" end
  local neg = false
  if string.sub(s, 1, 1) == "-" then
    neg = true
    s = string.sub(s, 2)
  end
  local intPart = s
  local fracPart = ""
  local dot = string.find(s, ".", 1, true)
  if dot ~= nil then
    intPart = string.sub(s, 1, dot - 1)
    fracPart = string.sub(s, dot + 1)
  end
  if intPart == "" then intPart = "0" end
  if string.len(intPart) > 12 then
    return nil, "整数部分最多 12 位 (万亿级)"
  end
  for i = 1, string.len(intPart) do
    if string.find(NUMS, string.sub(intPart, i, i), 1, true) == nil then
      return nil, "金额格式不合法"
    end
  end
  for i = 1, string.len(fracPart) do
    if string.find(NUMS, string.sub(fracPart, i, i), 1, true) == nil then
      return nil, "金额格式不合法"
    end
  end
  local jiao = 0
  local fen = 0
  if string.len(fracPart) >= 1 then
    jiao = tonumber(string.sub(fracPart, 1, 1)) or 0
  end
  if string.len(fracPart) >= 2 then
    fen = tonumber(string.sub(fracPart, 2, 2)) or 0
  end
  -- 第三位小数四舍五入 (纯字符串进位)
  if string.len(fracPart) >= 3 then
    local third = tonumber(string.sub(fracPart, 3, 3)) or 0
    if third >= 5 then
      fen = fen + 1
      if fen > 9 then
        fen = 0
        jiao = jiao + 1
      end
      if jiao > 9 then
        jiao = 0
        intPart = incInt(intPart)
      end
    end
  end

  local intCny = intToCny(intPart)
  local out = {}
  if intCny ~= "" then
    out[1] = intCny .. "元"
  end
  if jiao == 0 and fen == 0 then
    if intCny == "" then
      return "零元整"
    end
    out[#out + 1] = "整"
  else
    if jiao > 0 then
      out[#out + 1] = DIGITS[jiao + 1] .. "角"
    else
      if intCny ~= "" then out[#out + 1] = "零" end
    end
    if fen > 0 then
      out[#out + 1] = DIGITS[fen + 1] .. "分"
    end
  end
  local res = table.concat(out)
  if neg and res ~= "零元整" then
    res = "负" .. res
  end
  return res
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("amountInput", "")
  state.set("cnyResult", "")
  state.set("hasResult", false)
  clearError()
end

function convert()
  clearError()
  state.set("hasResult", false)
  local res, err = _toCny(state.get("amountInput") or "")
  if res == nil then
    setError(err)
    return nil
  end
  state.set("cnyResult", res)
  state.set("hasResult", true)
end

function pasteInput()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("amountInput", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
