-- compound_tool — 复利与定投计算器

local function strLen(s)
  if s == nil then return 0 end
  return string.len(s)
end

local function trim(s)
  if s == nil then return "" end
  local len = strLen(s)
  local i = 1
  while i <= len do
    local c = string.sub(s, i, i)
    if c ~= " " and c ~= "\t" and c ~= "\r" and c ~= "\n" then
      break
    end
    i = i + 1
  end
  local j = len
  while j >= i do
    local c = string.sub(s, j, j)
    if c ~= " " and c ~= "\t" and c ~= "\r" and c ~= "\n" then
      break
    end
    j = j - 1
  end
  if i > j then return "" end
  return string.sub(s, i, j)
end

local function formatMoney(val)
  if val == nil then return "0.00" end
  local isNeg = false
  if val < 0 then
    isNeg = true
    val = -val
  end
  local rounded = math.floor(val * 100 + 0.5) / 100
  local intPart = math.floor(rounded)
  local fracPart = math.floor((rounded - intPart) * 100 + 0.5)

  local intStr = tostring(intPart)
  local fracStr = tostring(fracPart)
  if strLen(fracStr) == 1 then
    fracStr = "0" .. fracStr
  elseif strLen(fracStr) == 0 then
    fracStr = "00"
  end

  -- Add comma thousands separators
  local len = strLen(intStr)
  local chunks = {}
  local start = len
  while start > 0 do
    local from = start - 2
    if from < 1 then from = 1 end
    chunks[#chunks + 1] = string.sub(intStr, from, start)
    start = from - 1
  end

  local rev = {}
  for k = #chunks, 1, -1 do
    rev[#rev + 1] = chunks[k]
  end
  local formattedInt = table.concat(rev, ",")

  local res = formattedInt .. "." .. fracStr
  if isNeg then
    return "-" .. res
  end
  return res
end

function _calc_compound(principal, pmt, freq, annualRatePct, years, inflationPct)
  local P0 = tonumber(principal) or 0
  local PMT = tonumber(pmt) or 0
  local rAnnual = (tonumber(annualRatePct) or 0) / 100
  local Y = tonumber(years) or 0
  local infRate = (tonumber(inflationPct) or 0) / 100

  if Y <= 0 then
    return nil, "投资年限必须大于 0"
  end
  if P0 < 0 or PMT < 0 then
    return nil, "金额不能为负数"
  end

  local m = 12
  if freq == "year" then
    m = 1
  elseif freq == "none" then
    m = 0
    PMT = 0
  end

  local totalPeriods = 0
  local rPeriod = 0
  local fvPrincipal = 0
  local fvPeriodic = 0
  local totalPrincipal = 0

  if m > 0 then
    totalPeriods = Y * m
    rPeriod = rAnnual / m
    if rPeriod > 0 then
      fvPrincipal = P0 * ((1 + rPeriod) ^ totalPeriods)
      fvPeriodic = PMT * ((((1 + rPeriod) ^ totalPeriods) - 1) / rPeriod) * (1 + rPeriod)
    else
      fvPrincipal = P0
      fvPeriodic = PMT * totalPeriods
    end
    totalPrincipal = P0 + PMT * totalPeriods
  else
    totalPeriods = Y
    if rAnnual > 0 then
      fvPrincipal = P0 * ((1 + rAnnual) ^ Y)
    else
      fvPrincipal = P0
    end
    fvPeriodic = 0
    totalPrincipal = P0
  end

  local totalFv = fvPrincipal + fvPeriodic
  local totalProfit = totalFv - totalPrincipal
  local profitPct = 0
  if totalPrincipal > 0 then
    profitPct = (totalProfit / totalPrincipal) * 100
  end

  local realPurchasing = totalFv
  if infRate > 0 then
    local discount = (1 + infRate) ^ Y
    realPurchasing = totalFv / discount
  end

  return {
    totalFv = totalFv,
    totalPrincipal = totalPrincipal,
    totalProfit = totalProfit,
    profitPct = profitPct,
    realPurchasing = realPurchasing,
    totalPeriods = totalPeriods,
    years = Y
  }, nil
end

function calculate()
  local p0Str = state.get("initPrincipal") or "10000"
  local pmtStr = state.get("periodicDeposit") or "1000"
  local freq = state.get("depositFreq") or "month"
  local rateStr = state.get("annualRate") or "6"
  local yearStr = state.get("durationYears") or "10"
  local infStr = state.get("inflationRate") or "2.5"

  local res, err = _calc_compound(p0Str, pmtStr, freq, rateStr, yearStr, infStr)
  if res == nil then
    state.set("hasError", true)
    state.set("errorMsg", err or "计算错误")
    state.set("hasResult", false)
    return nil
  end

  state.set("resTotalFv", "¥ " .. formatMoney(res.totalFv))
  state.set("resPrincipal", "¥ " .. formatMoney(res.totalPrincipal))
  state.set("resProfit", "¥ " .. formatMoney(res.totalProfit) .. " (" .. string.format("%.1f", res.profitPct) .. "%)")
  state.set("resPurchasing", "¥ " .. formatMoney(res.realPurchasing))
  state.set("resPeriodInfo", "投资 " .. tostring(res.years) .. " 年 (共 " .. tostring(res.totalPeriods) .. " 期投入)")

  local copyContent = "【复利与定投测算结果】\n" ..
                      "最终资产总额: ¥ " .. formatMoney(res.totalFv) .. "\n" ..
                      "累计投入本金: ¥ " .. formatMoney(res.totalPrincipal) .. "\n" ..
                      "投资净收益: ¥ " .. formatMoney(res.totalProfit) .. " (" .. string.format("%.1f", res.profitPct) .. "%)\n" ..
                      "通胀折算购买力: ¥ " .. formatMoney(res.realPurchasing) .. "\n" ..
                      "投资周期: " .. tostring(res.years) .. " 年"
  state.set("copyText", copyContent)

  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function setFreq(f)
  state.set("depositFreq", f)
  calculate()
  return nil
end

function applyPreset(name)
  if name == "steady" then
    state.set("initPrincipal", "50000")
    state.set("periodicDeposit", "0")
    state.set("depositFreq", "none")
    state.set("annualRate", "3.5")
    state.set("durationYears", "15")
  elseif name == "fund" then
    state.set("initPrincipal", "10000")
    state.set("periodicDeposit", "2000")
    state.set("depositFreq", "month")
    state.set("annualRate", "8")
    state.set("durationYears", "10")
  elseif name == "pension" then
    state.set("initPrincipal", "20000")
    state.set("periodicDeposit", "1500")
    state.set("depositFreq", "month")
    state.set("annualRate", "5")
    state.set("durationYears", "25")
  end
  calculate()
  return nil
end

function copyResult()
  local text = state.get("copyText") or ""
  if text ~= "" and clipboard and clipboard.set then
    clipboard.set(text)
  end
  if dialog and dialog.toast then
    dialog.toast("已复制收益测算报告")
  end
  return nil
end

function onInit()
  state.set("initPrincipal", "10000")
  state.set("periodicDeposit", "1000")
  state.set("depositFreq", "month")
  state.set("annualRate", "6")
  state.set("durationYears", "10")
  state.set("inflationRate", "2.5")
  state.set("resTotalFv", "")
  state.set("resPrincipal", "")
  state.set("resProfit", "")
  state.set("resPurchasing", "")
  state.set("resPeriodInfo", "")
  state.set("copyText", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  calculate()
  return nil
end
