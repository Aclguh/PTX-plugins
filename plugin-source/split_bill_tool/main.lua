local function round2(num)
  return math.floor(num * 100 + 0.5) / 100
end

local function format_money(num)
  return string.format("%.2f", round2(num))
end

local function parse_tokens_from_line(line)
  local tokens = {}
  local len = string.len(line)
  local cur = {}
  for i = 1, len do
    local b = string.byte(line, i)
    if b == 32 or b == 9 or b == 44 or b == 58 or b == 65292 or b == 65306 then
      if #cur > 0 then
        tokens[#tokens + 1] = table.concat(cur)
        cur = {}
      end
    else
      cur[#cur + 1] = string.sub(line, i, i)
    end
  end
  if #cur > 0 then
    tokens[#tokens + 1] = table.concat(cur)
  end
  return tokens
end

local function split_lines(text)
  local lines = {}
  local len = string.len(text)
  local cur = {}
  for i = 1, len do
    local b = string.byte(text, i)
    if b == 10 or b == 13 then
      if #cur > 0 then
        lines[#lines + 1] = table.concat(cur)
        cur = {}
      end
    else
      cur[#cur + 1] = string.sub(line or text, i, i)
    end
  end
  if #cur > 0 then
    lines[#lines + 1] = table.concat(cur)
  end
  return lines
end

function _parse_participants(text)
  local lines = split_lines(text)
  local list = {}
  for i = 1, #lines do
    local rawLine = lines[i]
    if rawLine ~= "" and string.sub(rawLine, 1, 1) ~= "#" then
      local toks = parse_tokens_from_line(rawLine)
      if #toks >= 2 then
        local name = toks[1]
        local paid = tonumber(toks[2]) or 0
        local weight = 1.0
        if #toks >= 3 then
          weight = tonumber(toks[3]) or 1.0
        end
        if weight <= 0 then
          weight = 1.0
        end
        list[#list + 1] = {
          name = name,
          paid = paid,
          weight = weight
        }
      end
    end
  end
  return list
end

function _solve_settlements(participants, discount, tipPercent)
  local n = #participants
  if n == 0 then
    return nil, "未识别到有效的参与人员与垫付金额"
  end

  local totalPaid = 0
  local totalWeight = 0
  for i = 1, n do
    totalPaid = totalPaid + participants[i].paid
    totalWeight = totalWeight + participants[i].weight
  end

  local disc = discount or 0
  local tip = tipPercent or 0
  local baseExpense = totalPaid - disc
  if baseExpense < 0 then
    baseExpense = 0
  end
  local finalTotal = baseExpense * (1 + tip / 100)

  local perWeightCost = 0
  if totalWeight > 0 then
    perWeightCost = finalTotal / totalWeight
  end

  local details = {}
  local creditors = {}
  local debtors = {}

  for i = 1, n do
    local p = participants[i]
    local should = p.weight * perWeightCost
    local net = round2(p.paid - should)
    details[#details + 1] = {
      name = p.name,
      paid = p.paid,
      weight = p.weight,
      should = should,
      net = net
    }

    if net > 0.009 then
      creditors[#creditors + 1] = { name = p.name, net = net }
    elseif net < -0.009 then
      debtors[#debtors + 1] = { name = p.name, net = -net }
    end
  end

  local transfers = {}
  local cIdx = 1
  local dIdx = 1

  while cIdx <= #creditors and dIdx <= #debtors do
    local c = creditors[cIdx]
    local d = debtors[dIdx]
    local settle = c.net
    if d.net < settle then
      settle = d.net
    end

    if settle > 0.009 then
      transfers[#transfers + 1] = d.name .. "  ->  " .. c.name .. "  ¥" .. format_money(settle)
      c.net = round2(c.net - settle)
      d.net = round2(d.net - settle)
    end

    if c.net <= 0.009 then
      cIdx = cIdx + 1
    end
    if d.net <= 0.009 then
      dIdx = dIdx + 1
    end
  end

  return {
    totalPaid = totalPaid,
    finalTotal = finalTotal,
    totalWeight = totalWeight,
    details = details,
    transfers = transfers
  }, nil
end

function calculateBill()
  local text = state.get("inputText") or ""
  local discount = tonumber(state.get("discount") or "0") or 0
  local tip = tonumber(state.get("tipPercent") or "0") or 0

  local participants = _parse_participants(text)
  if #participants == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "请在输入框中按格式输入人员名单与垫付金额")
    state.set("hasResult", false)
    return nil
  end

  local res, err = _solve_settlements(participants, discount, tip)
  if err ~= nil then
    state.set("hasError", true)
    state.set("errorMsg", err)
    state.set("hasResult", false)
    return nil
  end

  local summaryLines = {}
  summaryLines[#summaryLines + 1] = "【账单汇总】"
  summaryLines[#summaryLines + 1] = "总支出: ¥" .. format_money(res.finalTotal) .. " (参与人数: " .. tostring(#participants) .. ")"
  if discount > 0 or tip > 0 then
    summaryLines[#summaryLines + 1] = "优惠减免: ¥" .. format_money(discount) .. " | 服务费率: " .. tostring(tip) .. "%"
  end
  summaryLines[#summaryLines + 1] = ""
  summaryLines[#summaryLines + 1] = "【个人分摊明细】"
  for i = 1, #res.details do
    local d = res.details[i]
    local status = ""
    if d.net > 0 then
      status = "应收 ¥" .. format_money(d.net)
    elseif d.net < 0 then
      status = "应付 ¥" .. format_money(-d.net)
    else
      status = "已结清 (¥0)"
    end
    summaryLines[#summaryLines + 1] = string.format("• %s: 已垫付 ¥%s, 应分摊 ¥%s (%s)", d.name, format_money(d.paid), format_money(d.should), status)
  end

  summaryLines[#summaryLines + 1] = ""
  summaryLines[#summaryLines + 1] = "【最优转账平账方案 (" .. tostring(#res.transfers) .. " 笔)】"
  if #res.transfers == 0 then
    summaryLines[#summaryLines + 1] = "所有人员垫付金额恰好相等，无需额外转账！"
  else
    for i = 1, #res.transfers do
      summaryLines[#summaryLines + 1] = tostring(i) .. ". " .. res.transfers[i]
    end
  end

  local outStr = table.concat(summaryLines, "\n")
  state.set("output", outStr)
  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function copyResult()
  local out = state.get("output") or ""
  if out ~= "" then
    clipboard.set(out)
    dialog.toast("已复制账单与转账明细")
  end
  return nil
end

function setPresetDinner()
  state.set("inputText", "张三 300\n李四 120\n王五 0\n赵六 60")
  state.set("discount", "0")
  state.set("tipPercent", "0")
  calculateBill()
  return nil
end

function setPresetRoommates()
  state.set("inputText", "室友A 560\n室友B 0\n室友C 0")
  state.set("discount", "20")
  state.set("tipPercent", "0")
  calculateBill()
  return nil
end

function setPresetWeighted()
  state.set("inputText", "小明 400 1\n小红 0 1\n张哥一家 100 2.5")
  state.set("discount", "0")
  state.set("tipPercent", "10")
  calculateBill()
  return nil
end

function clearAll()
  state.set("inputText", "")
  state.set("output", "")
  state.set("discount", "0")
  state.set("tipPercent", "0")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function onInit()
  setPresetDinner()
  return nil
end
