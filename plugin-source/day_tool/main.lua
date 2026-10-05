-- day_tool — 纪念日追踪 (4 固定槽位)
-- 历法换算与 date_tool 同源 (Hinnant days_from_civil);
-- 槽位存储格式与 memo_tool 同款: 逐行 urlEncode(标题) .. "|" .. urlEncode(日期)

local SLOT_KEY = "day_slots_v1"
local SLOT_MAX = 4
local WEEKDAYS = { "星期四", "星期五", "星期六", "星期日", "星期一", "星期二", "星期三" }
local DAYS_IN_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local labels = {}
local dates = {}
local selSlot = 1

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

local function trim(s)
  local a = 1
  local b = string.len(s)
  while a <= b and string.sub(s, a, a) == " " do a = a + 1 end
  while b >= a and string.sub(s, b, b) == " " do b = b - 1 end
  if a > b then return "" end
  return string.sub(s, a, b)
end

local function isLeap(y)
  return (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0
end

local function daysInMonth(y, m)
  if m == 2 and isLeap(y) then return 29 end
  return DAYS_IN_MONTH[m]
end

-- 公历日期 -> 自 1970-01-01 起的天数
function _daysFromCivil(y, m, d)
  if m <= 2 then y = y - 1 end
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local doy = math.floor((153 * (m + (m > 2 and -3 or 9)) + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

-- 天数 -> 公历日期 (返回 y, m, d)
function _civilFromDays(z)
  z = z + 719468
  local era = math.floor(z / 146097)
  local doe = z - era * 146097
  local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
  local mp = math.floor((5 * doy + 2) / 153)
  local d = doy - math.floor((153 * mp + 2) / 5) + 1
  local m = mp + (mp < 10 and 3 or -9)
  if m <= 2 then y = y + 1 end
  return y, m, d
end

-- "YYYY-MM-DD" -> y, m, d; 非法返回 nil, err
function _parseDate(s)
  local t = trim(s)
  local p1 = string.find(t, "-", 1, true)
  if p1 == nil then return nil, "日期格式应为 YYYY-MM-DD" end
  local p2 = string.find(t, "-", p1 + 1, true)
  if p2 == nil then return nil, "日期格式应为 YYYY-MM-DD" end
  if string.find(t, "-", p2 + 1, true) ~= nil then
    return nil, "日期格式应为 YYYY-MM-DD"
  end
  local y = tonumber(string.sub(t, 1, p1 - 1))
  local m = tonumber(string.sub(t, p1 + 1, p2 - 1))
  local d = tonumber(string.sub(t, p2 + 1))
  if y == nil then
    return nil, "年月日必须为数字"
  end
  if m == nil then
    return nil, "年月日必须为数字"
  end
  if d == nil then
    return nil, "年月日必须为数字"
  end
  if y < 1 then
    return nil, "年份支持 1-9999"
  end
  if y > 9999 then
    return nil, "年份支持 1-9999"
  end
  if m < 1 then
    return nil, "月份必须在 1-12 之间"
  end
  if m > 12 then
    return nil, "月份必须在 1-12 之间"
  end
  if d < 1 then
    return nil, y .. " 年 " .. m .. " 月不存在 " .. d .. " 日"
  end
  if d > daysInMonth(y, m) then
    return nil, y .. " 年 " .. m .. " 月不存在 " .. d .. " 日"
  end
  return y, m, d
end

function _weekdayName(days)
  return WEEKDAYS[(days % 7) + 1]
end

-- 槽位行: "2025-01-01 星期三 还有 93 天"; todayDays 为今天的 epoch 天数
function _slotLine(dateStr, todayDays)
  local y, m, d = _parseDate(dateStr)
  if y == nil then return nil, m end
  local days = _daysFromCivil(y, m, d)
  local delta = days - todayDays
  local rel = ""
  if delta > 0 then
    rel = "还有 " .. delta .. " 天"
  else
    if delta == 0 then
      rel = "就是今天"
    else
      rel = "已过去 " .. (0 - delta) .. " 天"
    end
  end
  return string.format("%04d-%02d-%02d", y, m, d) .. " " .. _weekdayName(days) .. " " .. rel
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

local function decodeSlots(raw)
  local ls = {}
  local ds = {}
  if raw and raw ~= "" then
    local lines = splitLines(raw)
    for i = 1, SLOT_MAX do
      local line = lines[i]
      if line and line ~= "" then
        local pos = string.find(line, "|", 1, true)
        if pos ~= nil then
          local okL, l = pcall(codec.urlDecode, string.sub(line, 1, pos - 1))
          local okD, dt = pcall(codec.urlDecode, string.sub(line, pos + 1))
          if okL and l then ls[i] = l end
          if okD and dt then ds[i] = dt end
        end
      end
    end
  end
  return ls, ds
end

local function encodeSlots()
  local lines = {}
  for i = 1, SLOT_MAX do
    local l = labels[i] or ""
    local d = dates[i] or ""
    local filled = l ~= ""
    if not filled then filled = d ~= "" end
    if filled then
      lines[i] = codec.urlEncode(l) .. "|" .. codec.urlEncode(d)
    else
      lines[i] = ""
    end
  end
  return table.concat(lines, "\n")
end

-- 今天 (按本地时区) 的 epoch 天数
function _todayDays()
  local ts = util.timestamp()
  local tz = tonumber(state.get("tzOffset") or "0") or 0
  return math.floor((ts + tz * 60) / 86400)
end

local function refreshSlots()
  local todayDays = _todayDays()
  for i = 1, SLOT_MAX do
    local l = labels[i] or ""
    local d = dates[i] or ""
    local filled = l ~= "" and d ~= ""
    state.set("s" .. i .. "set", filled)
    if filled then
      local line, err = _slotLine(d, todayDays)
      if line == nil then line = "日期无效: " .. tostring(err) end
      state.set("t" .. i, l)
      state.set("sub" .. i, line)
    else
      state.set("t" .. i, "")
      state.set("sub" .. i, "")
    end
  end
  local any = false
  for i = 1, SLOT_MAX do
    local l = labels[i] or ""
    local d = dates[i] or ""
    if l ~= "" and d ~= "" then any = true end
  end
  state.set("hasAny", any)
  state.set("hasAnyNot", not any)
  state.set("selSlotText", "当前槽位: " .. selSlot .. " / " .. SLOT_MAX)
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _decodeSlots(raw)
  local ls, ds = decodeSlots(raw)
  return { labels = ls, dates = ds }
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("dayLabel", "")
  state.set("dayDate", "")
  state.set("selSlotText", "")
  state.set("nowText", "")
  state.set("tzOffset", "480")
  state.set("hasAny", false)
  state.set("hasAnyNot", true)
  clearError()
  for i = 1, SLOT_MAX do
    state.set("s" .. i .. "set", false)
    state.set("t" .. i, "")
    state.set("sub" .. i, "")
  end
  refreshToday()
  refreshSlots()
  storage.get(SLOT_KEY, function(raw)
    labels, dates = decodeSlots(raw)
    refreshSlots()
  end)
end

function refreshToday()
  local days = _todayDays()
  local y, m, d = _civilFromDays(days)
  state.set("nowText", "今天是 " .. string.format("%04d-%02d-%02d", y, m, d)
      .. " " .. _weekdayName(days))
end

function selectSlot(n)
  local idx = math.floor(tonumber(n) or 0)
  if idx < 1 then return nil end
  if idx > SLOT_MAX then return nil end
  selSlot = idx
  state.set("dayLabel", labels[idx] or "")
  state.set("dayDate", dates[idx] or "")
  refreshSlots()
end

function saveSlot()
  clearError()
  local l = trim(state.get("dayLabel") or "")
  local d = trim(state.get("dayDate") or "")
  if l == "" then
    setError("请输入纪念日名称")
    return nil
  end
  if string.len(l) > 20 then
    setError("名称最多 20 字")
    return nil
  end
  local py, pm, pd = _parseDate(d)
  if py == nil then
    setError("日期: " .. tostring(pm))
    return nil
  end
  labels[selSlot] = l
  dates[selSlot] = string.format("%04d-%02d-%02d", py, pm, pd)
  storage.set(SLOT_KEY, encodeSlots())
  refreshSlots()
  dialog.toast("已保存到槽位 " .. selSlot)
end

function deleteSlot()
  local l = labels[selSlot] or ""
  if l == "" then
    dialog.toast("当前槽位为空")
    return nil
  end
  dialog.confirm("删除纪念日", "确定删除槽位 " .. selSlot .. " 的「" .. l .. "」吗？", function(ok)
    if ok then
      labels[selSlot] = nil
      dates[selSlot] = nil
      storage.set(SLOT_KEY, encodeSlots())
      refreshSlots()
      state.set("dayLabel", "")
      state.set("dayDate", "")
      dialog.toast("已删除")
    end
  end)
end
