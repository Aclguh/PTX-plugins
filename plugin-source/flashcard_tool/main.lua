-- flashcard_tool — 间隔重复记忆闪卡
-- 基于独立 SQLite 存储知识卡片，结合简明间隔复习算法

local cards = {}
local currentIndex = 1
local isAnswerVisible = false
local currentMode = "review" -- "review" | "add"

function _calcNextInterval(currentInterval, rating)
  local cur = currentInterval or 1
  if rating == "forget" then
    return 1
  elseif rating == "good" then
    return cur + 2
  elseif rating == "easy" then
    return cur * 2 + 1
  end
  return cur + 1
end

local function renderCard()
  if #cards == 0 then
    state.set("hasCard", false)
    state.set("cardProgress", "0 / 0")
    state.set("frontText", "卡片库为空，请点击下方「录入新卡」添加")
    state.set("backText", "")
    state.set("isAnswerVisible", false)
    return nil
  end

  if currentIndex > #cards then currentIndex = 1 end
  if currentIndex < 1 then currentIndex = 1 end

  local c = cards[currentIndex]
  state.set("hasCard", true)
  state.set("cardProgress", "卡片 " .. tostring(currentIndex) .. " / " .. tostring(#cards))
  state.set("frontText", c.front or "")
  state.set("backText", c.back or "")
  state.set("cardInterval", "复习间隔: " .. tostring(c.interval or 1) .. " 天 | 熟练度: " .. tostring(c.reps or 0))
  state.set("isAnswerVisible", isAnswerVisible)
end

local function reloadCards()
  db.query("SELECT * FROM flashcards ORDER BY id ASC;", function(res)
    if res ~= nil and res.ok == true and res.rows ~= nil then
      cards = res.rows
    else
      cards = {}
    end
    state.set("totalCount", tostring(#cards))
    renderCard()
    return nil
  end)
end

-- ---------------- UI 事件 ----------------
function onInit()
  cards = {}
  currentIndex = 1
  isAnswerVisible = false
  currentMode = "review"

  state.set("isReviewMode", true)
  state.set("isAddMode", false)
  state.set("hasCard", false)
  state.set("cardProgress", "--")
  state.set("frontText", "正在加载闪卡...")
  state.set("backText", "")
  state.set("cardInterval", "--")
  state.set("isAnswerVisible", false)
  state.set("inputFront", "")
  state.set("inputBack", "")
  state.set("totalCount", "0")
  state.set("statusMsg", "准备复习")

  db.execute("CREATE TABLE IF NOT EXISTS flashcards (id INTEGER PRIMARY KEY AUTOINCREMENT, front TEXT, back TEXT, interval INTEGER, reps INTEGER);", function(r1)
    db.query("SELECT count(*) as c FROM flashcards;", function(r2)
      local c = 0
      if r2 ~= nil and r2.rows ~= nil and #r2.rows > 0 then
        c = tonumber(r2.rows[1].c) or 0
      end
      if c == 0 then
        -- 预设几张高频词汇示例卡片
        db.execute("INSERT INTO flashcards (front, back, interval, reps) VALUES ('Ephemeral', '短暂的，瞬息即逝的 (adj.)', 1, 0), ('Ubiquitous', '无处不在的，普遍存在的 (adj.)', 1, 0), ('Idempotent', '幂等的（多次操作具有相同副作用）', 1, 0);", function(r3)
          reloadCards()
          return nil
        end)
      else
        reloadCards()
      end
      return nil
    end)
    return nil
  end)
end

function toggleAnswer()
  isAnswerVisible = not isAnswerVisible
  state.set("isAnswerVisible", isAnswerVisible)
end

function rateForget()
  if #cards == 0 then return nil end
  local c = cards[currentIndex]
  local nextInt = _calcNextInterval(c.interval, "forget")
  local reps = (c.reps or 0)
  db.execute("UPDATE flashcards SET interval = " .. nextInt .. ", reps = " .. reps .. " WHERE id = " .. c.id .. ";", function(r)
    c.interval = nextInt
    c.reps = reps
    currentIndex = currentIndex + 1
    if currentIndex > #cards then currentIndex = 1 end
    isAnswerVisible = false
    renderCard()
    dialog.toast("已记为遗忘，稍后复习")
    return nil
  end)
end

function rateGood()
  if #cards == 0 then return nil end
  local c = cards[currentIndex]
  local nextInt = _calcNextInterval(c.interval, "good")
  local reps = (c.reps or 0) + 1
  db.execute("UPDATE flashcards SET interval = " .. nextInt .. ", reps = " .. reps .. " WHERE id = " .. c.id .. ";", function(r)
    c.interval = nextInt
    c.reps = reps
    currentIndex = currentIndex + 1
    if currentIndex > #cards then currentIndex = 1 end
    isAnswerVisible = false
    renderCard()
    dialog.toast("已掌握，下次间隔延长")
    return nil
  end)
end

function rateEasy()
  if #cards == 0 then return nil end
  local c = cards[currentIndex]
  local nextInt = _calcNextInterval(c.interval, "easy")
  local reps = (c.reps or 0) + 2
  db.execute("UPDATE flashcards SET interval = " .. nextInt .. ", reps = " .. reps .. " WHERE id = " .. c.id .. ";", function(r)
    c.interval = nextInt
    c.reps = reps
    currentIndex = currentIndex + 1
    if currentIndex > #cards then currentIndex = 1 end
    isAnswerVisible = false
    renderCard()
    dialog.toast("轻松掌握，间隔大幅加倍")
    return nil
  end)
end

function nextCard()
  if #cards == 0 then return nil end
  currentIndex = currentIndex + 1
  if currentIndex > #cards then currentIndex = 1 end
  isAnswerVisible = false
  renderCard()
end

function switchReviewMode()
  currentMode = "review"
  state.set("isReviewMode", true)
  state.set("isAddMode", false)
  reloadCards()
end

function switchAddMode()
  currentMode = "add"
  state.set("isReviewMode", false)
  state.set("isAddMode", true)
end

function addNewCard()
  local front = state.get("inputFront") or ""
  local back = state.get("inputBack") or ""
  if string.len(front) == 0 or string.len(back) == 0 then
    dialog.toast("卡片正面与背面均不能为空")
    return nil
  end

  db.execute("INSERT INTO flashcards (front, back, interval, reps) VALUES ('" .. front .. "', '" .. back .. "', 1, 0);", function(r)
    dialog.toast("新卡片添加成功")
    state.set("inputFront", "")
    state.set("inputBack", "")
    switchReviewMode()
    return nil
  end)
end
