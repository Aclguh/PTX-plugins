-- ledger_tool main.lua
-- 极简 SQLite 记账本

local currentType = "支出"
local currentCategory = "餐饮"
local cachedRows = {}

function _calcBalance(expense, income)
  local exp = expense or 0.0
  local inc = income or 0.0
  return inc - exp
end

local function formatRowsText(rows)
  if rows == nil or #rows == 0 then
    return "暂无账目流水，请录入第一笔收支"
  end
  local lines = {}
  for i = 1, #rows do
    local r = rows[i]
    local sign = "-"
    if r.type == "收入" then sign = "+" end
    local note = r.note
    if note == nil or string.len(note) == 0 then note = "无备注" end
    local line = string.format("#%s [%s·%s] %s¥%.2f (%s)",
      tostring(r.id or i),
      tostring(r.type or "支出"),
      tostring(r.category or "其他"),
      sign,
      tonumber(r.amount) or 0.0,
      note)
    table.insert(lines, line)
  end
  return table.concat(lines, "\n")
end

function onInit()
  currentType = "支出"
  currentCategory = "餐饮"
  cachedRows = {}

  state.set("totalExpense", "0.00")
  state.set("totalIncome", "0.00")
  state.set("balance", "0.00")
  state.set("recordCount", 0)
  state.set("selectedType", "支出")
  state.set("selectedCategory", "餐饮")
  state.set("inputAmount", "")
  state.set("inputNote", "")
  state.set("recordsText", "正在加载 SQLite 账本...")

  db.execute("CREATE TABLE IF NOT EXISTS ledger_records (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, category TEXT, amount REAL, note TEXT, created_at TEXT)", function(res)
    loadRecords()
    return nil
  end)

  return nil
end

function setTypeExpense()
  currentType = "支出"
  state.set("selectedType", "支出")
  return nil
end

function setTypeIncome()
  currentType = "收入"
  state.set("selectedType", "收入")
  return nil
end

function setCatFood()
  currentCategory = "餐饮"
  state.set("selectedCategory", "餐饮")
  return nil
end

function setCatTransport()
  currentCategory = "交通"
  state.set("selectedCategory", "交通")
  return nil
end

function setCatShopping()
  currentCategory = "购物"
  state.set("selectedCategory", "购物")
  return nil
end

function setCatSalary()
  currentCategory = "工资"
  state.set("selectedCategory", "工资")
  return nil
end

local function escapeSql(s)
  if s == nil then return "" end
  local out = {}
  local len = string.len(s)
  local i = 1
  while i <= len do
    local c = string.sub(s, i, i)
    if c == "'" then
      out[#out + 1] = "''"
    else
      out[#out + 1] = c
    end
    i = i + 1
  end
  return table.concat(out)
end

local function getTodayDateStr()
  local ts = util.timestamp()
  local days = math.floor(ts / 86400) + 719468
  local era = math.floor(days / 146097)
  local doe = days - era * 146097
  local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
  local mp = math.floor((5 * doy + 2) / 153)
  local d = doy - math.floor((153 * mp + 2) / 5) + 1
  local m = mp + (mp < 10 and 3 or -9)
  if m <= 2 then y = y + 1 end
  return string.format("%04d-%02d-%02d", y, m, d)
end

function addRecord()
  local rawAmt = state.get("inputAmount")
  local amt = tonumber(rawAmt)
  if amt == nil or amt <= 0 then
    dialog.toast("请输入有效正数金额")
    return nil
  end

  local note = state.get("inputNote")
  if note == nil then note = "" end
  local dateStr = getTodayDateStr()
  local safeNote = escapeSql(note)

  local sql = string.format("INSERT INTO ledger_records (type, category, amount, note, created_at) VALUES ('%s', '%s', %.2f, '%s', '%s')",
    escapeSql(currentType), escapeSql(currentCategory), amt, safeNote, dateStr)

  db.execute(sql, function(res)
    state.set("inputAmount", "")
    state.set("inputNote", "")
    dialog.toast("记录已保存")
    loadRecords()
    return nil
  end)

  return nil
end

function loadRecords()
  db.query("SELECT * FROM ledger_records ORDER BY id DESC", function(res)
    local rows = {}
    if res ~= nil and res.rows ~= nil then
      rows = res.rows
    end
    cachedRows = rows

    local sumExp = 0.0
    local sumInc = 0.0
    for i = 1, #rows do
      local r = rows[i]
      local a = tonumber(r.amount) or 0.0
      if r.type == "收入" then
        sumInc = sumInc + a
      else
        sumExp = sumExp + a
      end
    end

    local bal = _calcBalance(sumExp, sumInc)

    state.set("totalExpense", string.format("%.2f", sumExp))
    state.set("totalIncome", string.format("%.2f", sumInc))
    state.set("balance", string.format("%.2f", bal))
    state.set("recordCount", #rows)
    state.set("recordsText", formatRowsText(rows))
    return nil
  end)

  return nil
end

function clearAll()
  dialog.confirm("确认清空", "是否确定清空全部 SQLite 账目？不可恢复", function(ok)
    if ok == true then
      db.execute("DELETE FROM ledger_records", function(res)
        dialog.toast("账本已清空")
        loadRecords()
        return nil
      end)
    end
    return nil
  end)
  return nil
end

function exportCsv()
  if #cachedRows == 0 then
    dialog.toast("暂无记录可导出")
    return nil
  end

  local lines = {"序号,类型,分类,金额,备注"}
  for i = 1, #cachedRows do
    local r = cachedRows[i]
    local line = string.format("%s,%s,%s,%.2f,%s",
      tostring(r.id or i),
      tostring(r.type or "支出"),
      tostring(r.category or "其他"),
      tonumber(r.amount) or 0.0,
      tostring(r.note or ""))
    table.insert(lines, line)
  end

  local csv = table.concat(lines, "\n")
  clipboard.set(csv)
  dialog.toast("已导出 CSV 并复制到剪贴板")
  return nil
end
