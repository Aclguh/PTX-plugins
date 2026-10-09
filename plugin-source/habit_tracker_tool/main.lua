-- habit_tracker_tool — 习惯养成与打卡追踪器
-- 基于独立 SQLite 存储习惯项目、打卡历史与连胜天数统计

local habits = {}

local function getTodayStr()
  local ts = util.timestamp()
  local days = math.floor(ts / 86400)
  -- 简易相对日期标记: 转换为定长数字标识
  return tostring(days)
end

function _calcStreak(lastDayStr, todayStr, currentStreak)
  local cur = currentStreak or 0
  if lastDayStr == todayStr then
    return cur, false -- 今日已打卡
  end
  local lastDay = tonumber(lastDayStr) or 0
  local today = tonumber(todayStr) or 0
  if today - lastDay == 1 then
    return cur + 1, true -- 连击加 1
  end
  return 1, true -- 重新开始连击
end

local function renderHabitsList()
  if #habits == 0 then
    state.set("habitsText", "暂无习惯项目，请在下方输入并添加")
    state.set("habitSummary", "习惯: 0 项 | 今日已完成: 0 项")
    return nil
  end

  local todayStr = getTodayStr()
  local lines = {}
  local completedCount = 0

  for i = 1, #habits do
    local h = habits[i]
    local isDoneToday = (h.last_date == todayStr)
    local status = "○ 未打卡"
    if isDoneToday then
      status = "● 今日已打卡"
      completedCount = completedCount + 1
    end
    local hName = tostring(h.name or h.category or "习惯项目")
    local hStreak = tostring(h.streak or 0)
    local hTotal = tostring(h.total or 0)
    lines[#lines + 1] = "#" .. tostring(h.id or i) .. " 【" .. hName .. "】"
    lines[#lines + 1] = "   状态: " .. status .. " | 连续: " .. hStreak .. " 天 | 累计: " .. hTotal .. " 次"
    lines[#lines + 1] = "----------------------------------------"
  end

  state.set("habitsText", table.concat(lines, "\n"))
  state.set("habitSummary", "习惯: " .. #habits .. " 项 | 今日已打卡: " .. completedCount .. " 项")
end

local function reloadHabits()
  db.query("SELECT * FROM habits ORDER BY id ASC;", function(res)
    if res ~= nil and res.ok == true and res.rows ~= nil then
      habits = res.rows
    else
      habits = {}
    end
    renderHabitsList()
    return nil
  end)
end

-- ---------------- UI 事件 ----------------
function onInit()
  habits = {}
  state.set("habitsText", "正在加载习惯数据...")
  state.set("habitSummary", "--")
  state.set("newHabitName", "")
  state.set("checkinIdInput", "1")
  state.set("statusMsg", "坚持自律，滴水穿石")

  db.execute("CREATE TABLE IF NOT EXISTS habits (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, streak INTEGER, total INTEGER, last_date TEXT);", function(r1)
    db.query("SELECT count(*) as c FROM habits;", function(r2)
      local c = 0
      if r2 ~= nil and r2.rows ~= nil and #r2.rows > 0 then
        c = tonumber(r2.rows[1].c) or 0
      end
      if c == 0 then
        db.execute("INSERT INTO habits (name, streak, total, last_date) VALUES ('晨跑 / 健身运动 30分钟', 3, 12, ''), ('阅读技术专著 30分钟', 5, 20, ''), ('按时喝足 2000ml 水', 2, 8, '');", function(r3)
          reloadHabits()
          return nil
        end)
      else
        reloadHabits()
      end
      return nil
    end)
    return nil
  end)
end

function checkInHabit()
  local idStr = state.get("checkinIdInput") or "1"
  local targetId = tonumber(idStr)
  if targetId == nil then
    dialog.toast("请输入有效的习惯编号")
    return nil
  end

  local targetHabit = nil
  for i = 1, #habits do
    if habits[i].id == targetId then
      targetHabit = habits[i]
      break
    end
  end

  if targetHabit == nil then
    dialog.toast("未找到编号为 #" .. idStr .. " 的习惯")
    return nil
  end

  local today = getTodayStr()
  local newStreak, ok = _calcStreak(targetHabit.last_date, today, targetHabit.streak)
  if not ok then
    dialog.toast("该习惯今日已经打过卡啦！明天再来吧")
    return nil
  end

  local newTotal = (targetHabit.total or 0) + 1
  db.execute("UPDATE habits SET streak = " .. newStreak .. ", total = " .. newTotal .. ", last_date = '" .. today .. "' WHERE id = " .. targetId .. ";", function(r)
    dialog.toast("打卡成功！连续天数: " .. newStreak .. " 天")
    reloadHabits()
    return nil
  end)
end

function addHabit()
  local name = state.get("newHabitName") or ""
  if string.len(name) == 0 then
    dialog.toast("请输入习惯名称")
    return nil
  end

  db.execute("INSERT INTO habits (name, streak, total, last_date) VALUES ('" .. name .. "', 0, 0, '');", function(r)
    dialog.toast("新增习惯成功")
    state.set("newHabitName", "")
    reloadHabits()
    return nil
  end)
end

function copyHabitSummary()
  local txt = state.get("habitsText") or ""
  if string.len(txt) == 0 then
    dialog.toast("暂无内容可复制")
    return nil
  end
  clipboard.set(txt)
  dialog.toast("已复制打卡清单")
end
