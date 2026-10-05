-- loan_tool — 贷款计算器
-- 等额本息: 月供 = P*r*(1+r)^n / ((1+r)^n - 1), r 为月利率;
-- 等额本金: 每月本金 P/n, 第 k 月利息 = (P - (k-1)*P/n)*r;
-- (1+r)^n 用循环乘实现, 规避浮点幂的实现差异

local METHOD_INTEREST = 1
local METHOD_PRINCIPAL = 2

local method = METHOD_INTEREST

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

function _pow1p(r, n)
  local acc = 1.0
  for _ = 1, n do
    acc = acc * (1.0 + r)
  end
  return acc
end

-- 等额本息月供; 本金/利率/期数非法时返回 nil
function _equalPayment(principal, annualRatePct, months)
  if principal <= 0 then return nil end
  if months < 1 then return nil end
  local r = annualRatePct / 100.0 / 12.0
  if r <= 0 then
    return principal / months
  end
  local p = _pow1p(r, months)
  return principal * r * p / (p - 1.0)
end

-- 等额本金: 返回 首月, 末月, 每月递减, 总利息
function _equalPrincipal(principal, annualRatePct, months)
  if principal <= 0 then return nil end
  if months < 1 then return nil end
  local r = annualRatePct / 100.0 / 12.0
  local mp = principal / months
  local first = mp + principal * r
  local last = mp + mp * r
  local stepDown = mp * r
  local totalInterest = principal * r * (months + 1) / 2.0
  return first, last, stepDown, totalInterest
end

-- 整数解析: 非法或带小数返回 nil
function _toInt(s)
  local n = tonumber(s)
  if n == nil then return nil end
  if n ~= math.floor(n) then return nil end
  return n
end

local function fmt2(v)
  return string.format("%.2f", v)
end

local function fmtWan(v)
  return fmt2(v / 10000.0) .. " 万元"
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("loanAmt", "100")
  state.set("loanRate", "3.25")
  state.set("loanYears", "30")
  state.set("methodLbl", "等额本息")
  state.set("resultText", "")
  state.set("hasResult", false)
  clearError()
end

function toggleMethod()
  if method == METHOD_INTEREST then
    method = METHOD_PRINCIPAL
    state.set("methodLbl", "等额本金")
  else
    method = METHOD_INTEREST
    state.set("methodLbl", "等额本息")
  end
end

function computeLoan()
  clearError()
  state.set("hasResult", false)
  local amt = tonumber(state.get("loanAmt") or "")
  local rate = tonumber(state.get("loanRate") or "")
  local years = _toInt(state.get("loanYears") or "")
  if amt == nil then
    setError("贷款总额必须为数字")
    return nil
  end
  if rate == nil then
    setError("年利率必须为数字")
    return nil
  end
  if years == nil then
    setError("贷款年限必须为整数")
    return nil
  end
  if amt <= 0 then
    setError("贷款总额必须大于 0")
    return nil
  end
  if rate < 0 then
    setError("年利率不能为负数")
    return nil
  end
  if rate > 36 then
    setError("年利率请输入 0-36 之间的数值")
    return nil
  end
  if years < 1 then
    setError("贷款年限至少 1 年")
    return nil
  end
  if years > 50 then
    setError("贷款年限最多 50 年")
    return nil
  end
  local principal = amt * 10000.0
  local months = years * 12
  if method == METHOD_INTEREST then
    local monthly = _equalPayment(principal, rate, months)
    local total = monthly * months
    local totalInt = total - principal
    state.set("resultText", "等额本息 (" .. years .. " 年 " .. months .. " 期)\n"
        .. "每月还款: " .. fmt2(monthly) .. " 元\n"
        .. "利息总额: " .. fmt2(totalInt) .. " 元 (" .. fmtWan(totalInt) .. ")\n"
        .. "还款总额: " .. fmt2(total) .. " 元 (" .. fmtWan(total) .. ")")
  else
    local first, last, stepDown, totalInt = _equalPrincipal(principal, rate, months)
    local total = principal + totalInt
    state.set("resultText", "等额本金 (" .. years .. " 年 " .. months .. " 期)\n"
        .. "首月还款: " .. fmt2(first) .. " 元\n"
        .. "末月还款: " .. fmt2(last) .. " 元\n"
        .. "每月递减: " .. fmt2(stepDown) .. " 元\n"
        .. "利息总额: " .. fmt2(totalInt) .. " 元 (" .. fmtWan(totalInt) .. ")\n"
        .. "还款总额: " .. fmt2(total) .. " 元 (" .. fmtWan(total) .. ")")
  end
  state.set("hasResult", true)
end
