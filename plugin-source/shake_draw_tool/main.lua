-- shake_draw_tool — 摇一摇抽签决策箱
-- 结合传感器动作感知与随机算法，支持预设池与自定义候选选项

local history = {}

local PRESET_FOOD = "火锅\n冒菜\n兰州牛肉拉面\n汉堡披萨\n轻食沙拉\n黄焖鸡米饭\n柳州螺蛳粉\n日料寿司\n麻辣烫\n自制减脂餐"
local PRESET_PARTY = "大冒险: 模仿一种动物叫声30秒\n真心话: 分享最近最社死的一件事\n大冒险: 给微信置顶第三人发一个表情包\n真心话: 迄今为止做过最叛逆的事\n大冒险: 对右边的人深情朗诵一段诗歌\n真心话: 手机里最舍不得删的一张照片是关于谁"
local PRESET_COIN = "正面 (肯定 / YES)\n反面 (否定 / NO)\n天意难违 (稍后再作决定)"

local function splitLines(text)
  local list = {}
  if text == nil then return list end
  local start = 1
  while true do
    local pos = string.find(text, "\n", start, true)
    if pos == nil then
      local piece = string.sub(text, start)
      if string.len(piece) > 0 then list[#list + 1] = piece end
      return list
    end
    local piece = string.sub(text, start, pos - 1)
    if string.len(piece) > 0 then list[#list + 1] = piece end
    start = pos + 1
  end
end

function _pickRandom(list)
  if list == nil or #list == 0 then return nil end
  local idx = math.random(1, #list)
  return list[idx]
end

local function recordHistory(item)
  table.insert(history, 1, item)
  while #history > 5 do
    table.remove(history)
  end
  local lines = {}
  for i = 1, #history do
    lines[#lines + 1] = "[" .. i .. "] " .. history[i]
  end
  state.set("historyText", table.concat(lines, "\n"))
  state.set("hasHistory", true)
end

-- ---------------- UI 事件 ----------------
function onInit()
  math.randomseed(util.timestampMs() % 2147483647)
  history = {}

  state.set("optionsText", PRESET_FOOD)
  state.set("chosenResult", "点击「抽签决策」揭晓结果")
  state.set("hasResult", true)
  state.set("hasHistory", false)
  state.set("historyText", "")
  state.set("statusMsg", "当前候选池: 10 个选项")
end

function setPresetFood()
  state.set("optionsText", PRESET_FOOD)
  state.set("statusMsg", "已载入美食推荐候选池")
end

function setPresetParty()
  state.set("optionsText", PRESET_PARTY)
  state.set("statusMsg", "已载入聚会真心话大冒险候选池")
end

function setPresetCoin()
  state.set("optionsText", PRESET_COIN)
  state.set("statusMsg", "已载入硬币与二选一候选池")
end

function drawOption()
  local raw = state.get("optionsText") or ""
  local list = splitLines(raw)
  if #list == 0 then
    dialog.toast("候选池为空，请先输入选项")
    return nil
  end

  local chosen = _pickRandom(list)
  haptic.heavy()
  state.set("chosenResult", "🎯 " .. chosen)
  state.set("statusMsg", "抽签完成！来自 " .. #list .. " 个候选")
  recordHistory(chosen)
  dialog.toast("抽取成功: " .. chosen)
end

function shakeDetectAndDraw()
  local acc = sensor.getAccelerometer()
  local delta = 0.0
  if acc ~= nil then
    local ax = math.abs(acc.x)
    local ay = math.abs(acc.y)
    local az = math.abs(acc.z)
    delta = math.abs(ax + ay + az - 9.8)
  end

  state.set("statusMsg", "摇动强度检测: " .. string.format("%.1f", delta))
  drawOption()
end

function copyResult()
  local res = state.get("chosenResult") or ""
  if string.len(res) == 0 then
    dialog.toast("暂无结果可复制")
    return nil
  end
  clipboard.set(res)
  dialog.toast("已复制到剪贴板")
end
