-- memo_tool — 备忘录 (6 固定槽位)
-- 沙箱 UI 无动态列表, 槽位以 ListTile 固定树 + visible 显隐呈现;
-- 存储格式: 逐行 urlEncode(标题) .. "|" .. urlEncode(内容), '|' 与换行
-- 均会被 urlEncode 转义, 行切分安全

local SLOT_KEY = "memo_slots_v1"
local SLOT_MAX = 6
local PREVIEW_LEN = 30

local titles = {}
local bodies = {}
local selSlot = 1

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

local function splitLines(s)
  local out = {}
  local start = 1
  while true do
    local pos = string.find(s, "\n", start, true)
    if pos == nil then
      out[#out + 1] = string.sub(s, start)
      return out
    end
    out[#out + 1] = string.sub(s, start, pos - 1)
    start = pos + 1
  end
end

local function truncate(s, n)
  if string.len(s) > n then
    return string.sub(s, 1, n) .. "..."
  end
  return s
end

local function decodeSlots(raw)
  local ts, bs = {}, {}
  if raw and raw ~= "" then
    local lines = splitLines(raw)
    for i = 1, SLOT_MAX do
      local line = lines[i]
      if line and line ~= "" then
        local pos = string.find(line, "|", 1, true)
        if pos ~= nil then
          local okT, t = pcall(codec.urlDecode, string.sub(line, 1, pos - 1))
          local okB, b = pcall(codec.urlDecode, string.sub(line, pos + 1))
          if okT and t then ts[i] = t end
          if okB and b then bs[i] = b end
        end
      end
    end
  end
  return ts, bs
end

local function encodeSlots()
  local lines = {}
  for i = 1, SLOT_MAX do
    local t = titles[i] or ""
    local b = bodies[i] or ""
    local filled = t ~= ""
    if not filled then filled = b ~= "" end
    if filled then
      lines[i] = codec.urlEncode(t) .. "|" .. codec.urlEncode(b)
    else
      lines[i] = ""
    end
  end
  return table.concat(lines, "\n")
end

local function hasAnyMemo()
  for i = 1, SLOT_MAX do
    local t = titles[i] or ""
    local b = bodies[i] or ""
    local filled = t ~= ""
    if not filled then filled = b ~= "" end
    if filled then return true end
  end
  return false
end

local function refreshSlots()
  for i = 1, SLOT_MAX do
    local t = titles[i] or ""
    local b = bodies[i] or ""
    local filled = t ~= "" or b ~= ""
    state.set("s" .. i .. "set", filled)
    if filled then
      local title = t
      if title == "" then title = "(无标题)" end
      state.set("t" .. i, truncate(title, 24))
      state.set("sub" .. i, truncate(table.concat(splitLines(b), " "), PREVIEW_LEN))
    else
      state.set("t" .. i, "")
      state.set("sub" .. i, "")
    end
  end
  state.set("hasMemo", hasAnyMemo())
  state.set("hasMemoNot", not hasAnyMemo())
  state.set("selSlotText", "当前槽位: " .. selSlot .. " / " .. SLOT_MAX)
end

local function saveSlots()
  storage.set(SLOT_KEY, encodeSlots())
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _decodeSlots(raw)
  local ts, bs = decodeSlots(raw)
  return { titles = ts, bodies = bs }
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("noteTitle", "")
  state.set("noteBody", "")
  state.set("selSlotText", "")
  state.set("hasMemo", false)
  state.set("hasMemoNot", true)
  clearError()
  for i = 1, SLOT_MAX do
    state.set("s" .. i .. "set", false)
    state.set("t" .. i, "")
    state.set("sub" .. i, "")
  end
  refreshSlots()
  storage.get(SLOT_KEY, function(raw)
    titles, bodies = decodeSlots(raw)
    refreshSlots()
  end)
end

function selectSlot(n)
  local idx = math.floor(tonumber(n) or 0)
  if idx < 1 then return nil end
  if idx > SLOT_MAX then return nil end
  selSlot = idx
  state.set("noteTitle", titles[idx] or "")
  state.set("noteBody", bodies[idx] or "")
  refreshSlots()
end

function saveCurrent()
  clearError()
  local t = state.get("noteTitle") or ""
  local b = state.get("noteBody") or ""
  if t == "" and b == "" then
    setError("标题与内容不能同时为空")
    return nil
  end
  titles[selSlot] = t
  bodies[selSlot] = b
  saveSlots()
  refreshSlots()
  dialog.toast("已保存到槽位 " .. selSlot)
end

function newMemo()
  for i = 1, SLOT_MAX do
    local t = titles[i] or ""
    local b = bodies[i] or ""
    if t == "" and b == "" then
      selectSlot(i)
      dialog.toast("已切换到空槽位 " .. i)
      return nil
    end
  end
  dialog.toast("备忘已满, 请先删除部分内容")
end

function deleteSlot()
  local t = titles[selSlot] or ""
  local b = bodies[selSlot] or ""
  if t == "" and b == "" then
    dialog.toast("当前槽位为空")
    return nil
  end
  dialog.confirm("删除备忘", "确定删除槽位 " .. selSlot .. " 的备忘吗？", function(ok)
    if ok then
      titles[selSlot] = nil
      bodies[selSlot] = nil
      saveSlots()
      refreshSlots()
      state.set("noteTitle", "")
      state.set("noteBody", "")
      dialog.toast("已删除")
    end
  end)
end
