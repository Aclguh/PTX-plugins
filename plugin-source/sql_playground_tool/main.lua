-- sql_playground_tool — SQL 交互演练台与查询测试器
-- 运行在独立沙箱 SQLite 上，支持交互式执行与结果排版

local function trim(s)
  if s == nil then return "" end
  local a = 1
  local b = string.len(s)
  while a <= b and (string.sub(s, a, a) == " " or string.sub(s, a, a) == "\t" or string.sub(s, a, a) == "\n") do
    a = a + 1
  end
  while b >= a and (string.sub(s, b, b) == " " or string.sub(s, b, b) == "\t" or string.sub(s, b, b) == "\n") do
    b = b - 1
  end
  if a > b then return "" end
  return string.sub(s, a, b)
end

function _isSelectQuery(sql)
  local t = trim(sql)
  if string.len(t) < 6 then return false end
  local lead = string.lower(string.sub(t, 1, 6))
  return lead == "select" or lead == "pragma" or lead == "explai"
end

function _formatRowsAsTable(rows)
  if rows == nil or #rows == 0 then
    return "【查询完成】返回 0 行数据"
  end
  local lines = {}
  lines[#lines + 1] = "【查询成功】返回 " .. #rows .. " 行记录："
  lines[#lines + 1] = "----------------------------------------"
  for i = 1, #rows do
    local r = rows[i]
    local pairsList = {}
    for k, v in pairs(r) do
      pairsList[#pairsList + 1] = tostring(k) .. ": " .. tostring(v)
    end
    lines[#lines + 1] = "[" .. i .. "] " .. table.concat(pairsList, " | ")
  end
  lines[#lines + 1] = "----------------------------------------"
  return table.concat(lines, "\n")
end

-- ---------------- UI 事件 ----------------
function onInit()
  state.set("sqlInput", "SELECT * FROM test_students;")
  state.set("resultText", "点击「执行 SQL」或选择上方预设语句")
  state.set("hasResult", true)
  state.set("statusMsg", "SQLite 引擎就绪")

  db.execute("CREATE TABLE IF NOT EXISTS test_students (id INTEGER PRIMARY KEY, name TEXT, score REAL);", function(res)
    db.execute("INSERT OR IGNORE INTO test_students (id, name, score) VALUES (1, '张三', 92.5), (2, '李四', 88.0), (3, '王五', 96.0);", function(r2)
      return nil
    end)
    return nil
  end)
end

function presetSelectAll()
  state.set("sqlInput", "SELECT * FROM test_students;")
  state.set("statusMsg", "已载入全表查询语句")
end

function presetAggregate()
  state.set("sqlInput", "SELECT count(*) AS total_count, max(score) AS max_score, avg(score) AS avg_score FROM test_students;")
  state.set("statusMsg", "已载入聚合统计语句")
end

function presetInsert()
  local rScore = math.random(70, 99)
  state.set("sqlInput", "INSERT INTO test_students (name, score) VALUES ('新同学', " .. rScore .. ");")
  state.set("statusMsg", "已载入插入数据语句")
end

function presetResetTable()
  db.execute("DROP TABLE IF EXISTS test_students;", function(r1)
    db.execute("CREATE TABLE test_students (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, score REAL);", function(r2)
      db.execute("INSERT INTO test_students (name, score) VALUES ('张三', 92.5), ('李四', 88.0), ('王五', 96.0);", function(r3)
        state.set("resultText", "已成功重置示例表 test_students 并插入 3 条基准数据")
        state.set("statusMsg", "表结构与数据已重置")
        dialog.toast("重置完成")
        return nil
      end)
      return nil
    end)
    return nil
  end)
end

function executeSql()
  local sql = trim(state.get("sqlInput") or "")
  if string.len(sql) == 0 then
    state.set("statusMsg", "SQL 语句不能为空")
    dialog.toast("请输入 SQL 语句")
    return nil
  end

  state.set("statusMsg", "正在执行...")
  if _isSelectQuery(sql) then
    db.query(sql, function(res)
      if res ~= nil and res.ok == true then
        local formatted = _formatRowsAsTable(res.rows)
        state.set("resultText", formatted)
        state.set("statusMsg", "执行成功")
      else
        local err = "执行失败"
        if res ~= nil and res.error ~= nil then err = res.error end
        state.set("resultText", "【执行错误】\n" .. err)
        state.set("statusMsg", "执行出错")
      end
      return nil
    end)
  else
    db.execute(sql, function(res)
      if res ~= nil and res.ok == true then
        local affected = 0
        if res.affectedRows ~= nil then affected = res.affectedRows end
        state.set("resultText", "【执行成功】\n受影响行数: " .. affected)
        state.set("statusMsg", "操作完成 (影响 " .. affected .. " 行)")
      else
        local err = "执行失败"
        if res ~= nil and res.error ~= nil then err = res.error end
        state.set("resultText", "【执行错误】\n" .. err)
        state.set("statusMsg", "执行出错")
      end
      return nil
    end)
  end
end

function copyResult()
  local text = state.get("resultText") or ""
  if string.len(text) == 0 then
    dialog.toast("暂无结果可复制")
    return nil
  end
  clipboard.set(text)
  dialog.toast("已复制到剪贴板")
end
