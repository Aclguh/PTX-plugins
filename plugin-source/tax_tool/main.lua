-- tax_tool — 个税计算器 (月薪版)
-- 按月 5000 元起征点的七级超额累进税率 (速算扣除数版):
--   应纳税额 = 应纳税所得额 * 税率 - 速算扣除数
-- 应纳税所得额 = 税前月薪 - 5000 - 五险一金 - 专项附加扣除

local TAX_BASE = 5000

-- 上限, 税率, 速算扣除数
local BRACKETS = {
  { 3000, 0.03, 0 },
  { 12000, 0.10, 210 },
  { 25000, 0.20, 1410 },
  { 35000, 0.25, 2660 },
  { 55000, 0.30, 4410 },
  { 80000, 0.35, 7160 },
  { 0, 0.45, 15160 }, -- 上限 0 表示不封顶
}

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

-- 应纳税所得额 -> 应纳税额, 税率, 速算扣除数, 档位序号
function _taxOf(taxable)
  if taxable <= 0 then
    return 0, 0, 0, 0
  end
  for i = 1, 7 do
    local b = BRACKETS[i]
    if b[1] == 0 then
      return taxable * b[2] - b[3], b[2], b[3], i
    end
    if taxable <= b[1] then
      return taxable * b[2] - b[3], b[2], b[3], i
    end
  end
  return 0, 0, 0, 0
end

local function fmtPct(rate)
  local pct = rate * 100
  if pct == math.floor(pct) then
    return string.format("%d", pct) .. "%"
  end
  return string.format("%.1f", pct) .. "%"
end

local function fmt2(v)
  return string.format("%.2f", v)
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("taxSalary", "")
  state.set("taxInsurance", "0")
  state.set("taxSpecial", "0")
  state.set("resultText", "")
  state.set("hasResult", false)
  clearError()
end

function computeTax()
  clearError()
  state.set("hasResult", false)
  local salary = tonumber(state.get("taxSalary") or "")
  local insurance = tonumber(state.get("taxInsurance") or "0")
  local special = tonumber(state.get("taxSpecial") or "0")
  if salary == nil then
    setError("税前月薪必须为数字")
    return nil
  end
  if insurance == nil then
    setError("五险一金必须为数字")
    return nil
  end
  if special == nil then
    setError("专项附加扣除必须为数字")
    return nil
  end
  if salary < 0 then
    setError("税前月薪不能为负数")
    return nil
  end
  if insurance < 0 then
    setError("五险一金不能为负数")
    return nil
  end
  if special < 0 then
    setError("专项附加扣除不能为负数")
    return nil
  end
  local taxable = salary - TAX_BASE - insurance - special
  local tax, rate, quick, level = _taxOf(taxable)
  local afterTax = salary - insurance - tax
  local line1 = "应纳税所得额: " .. fmt2(taxable) .. " 元"
  if taxable <= 0 then
    line1 = "应纳税所得额: " .. fmt2(taxable) .. " 元 (未超过起征点)"
  end
  state.set("resultText", line1 .. "\n"
      .. "适用税率: " .. fmtPct(rate) .. " (第 " .. level .. " 档, 速算扣除 " .. fmt2(quick) .. ")\n"
      .. "应缴个税: " .. fmt2(tax) .. " 元\n"
      .. "税后收入: " .. fmt2(afterTax) .. " 元")
  state.set("hasResult", true)
end
