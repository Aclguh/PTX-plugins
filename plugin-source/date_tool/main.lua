-- date_tool — 日期计算器
-- 宿主沙箱无 os 库, 历法换算自实现 (Hinnant days_from_civil / civil_from_days,
-- 与 timestamp_tool 同源); 星期以 1970-01-01 (星期四) 为锚

local DAYS_IN_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
local WEEKDAYS = { "星期四", "星期五", "星期六", "星期日", "星期一", "星期二", "星期三" }

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

-- 公历日期 -> 自 1970-01-01 起的天数 (支持负年份)
function _daysFromCivil(y, m, d)
  if m <= 2 then y = y - 1 end
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local doy = math.floor((153 * (m + (m > 2 and -3 or 9)) + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

-- 天数 -> 公历日期 (返回 y, m, d)
local function civilFromDays(z)
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

-- "YYYY-MM-DD" -> "YYYY-MM-DD 星期X (年内第 N 天)"; 非法返回 nil, err
-- 注意: _parseDate 失败只返回 (nil, msg) 两个值, 接收变量数必须与之对齐,
-- 否则错误消息会错位到月份变量而真正的 err 恒为 nil
function _describe(s)
  local y, m, d = _parseDate(s)
  if y == nil then return nil, m end
  local days = _daysFromCivil(y, m, d)
  local doy = days - _daysFromCivil(y, 1, 1) + 1
  return string.format("%04d-%02d-%02d", y, m, d) .. " " .. _weekdayName(days)
      .. " (年内第 " .. doy .. " 天)"
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _civilFromDays(z)
  return civilFromDays(z)
end

-- a - b 的间隔天数; 非法返回 nil, err
function _daysBetween(a, b)
  local ya, ma, da = _parseDate(a)
  if ya == nil then return nil, ma end
  local yb, mb, db = _parseDate(b)
  if yb == nil then return nil, mb end
  return _daysFromCivil(ya, ma, da) - _daysFromCivil(yb, mb, db)
end

-- 日期 + 天数偏移 -> "YYYY-MM-DD 星期X"; 非法返回 nil, err
function _addDays(dateStr, offset)
  local y, m, d = _parseDate(dateStr)
  if y == nil then return nil, m end
  local n = tonumber(offset)
  if n == nil then return nil, "天数偏移必须为整数" end
  if n ~= math.floor(n) then return nil, "天数偏移必须为整数" end
  local ny, nm, nd = civilFromDays(_daysFromCivil(y, m, d) + n)
  if ny < 1 then
    return nil, "结果超出支持范围 (年份 1-9999)"
  end
  if ny > 9999 then
    return nil, "结果超出支持范围 (年份 1-9999)"
  end
  return string.format("%04d-%02d-%02d", ny, nm, nd)
      .. " " .. _weekdayName(_daysFromCivil(ny, nm, nd))
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("dateA", "")
  state.set("dateB", "")
  state.set("baseDate", "")
  state.set("offsetDays", "7")
  state.set("tzOffset", "480")
  state.set("nowText", "")
  state.set("intervalResult", "")
  state.set("addResult", "")
  state.set("hasInterval", false)
  state.set("hasAdd", false)
  clearError()
  refreshToday()
end

function refreshToday()
  local ts = util.timestamp()
  local tz = tonumber(state.get("tzOffset") or "0") or 0
  local days = math.floor((ts + tz * 60) / 86400)
  local y, m, d = _civilFromDays(days)
  local wd = _weekdayName(days)
  state.set("nowText", "今天 (UTC" .. (tz >= 0 and "+" or "-")
      .. math.abs(tz) / 60 .. "): " .. string.format("%04d-%02d-%02d", y, m, d)
      .. " " .. wd)
end

function computeInterval()
  clearError()
  state.set("hasInterval", false)
  local da = state.get("dateA") or ""
  local db = state.get("dateB") or ""
  local descA, errA = _describe(da)
  if descA == nil then
    setError("日期 A: " .. errA)
    return nil
  end
  local descB, errB = _describe(db)
  if descB == nil then
    setError("日期 B: " .. errB)
    return nil
  end
  local diff, errD = _daysBetween(da, db)
  if diff == nil then
    setError(errD)
    return nil
  end
  local label = "相差"
  if diff < 0 then label = "早于" end
  state.set("intervalResult", descA .. "\n" .. descB
      .. "\n日期 A " .. label .. " 日期 B " .. math.abs(diff) .. " 天")
  state.set("hasInterval", true)
end

function computeAdd()
  clearError()
  state.set("hasAdd", false)
  local res, err = _addDays(state.get("baseDate") or "",
      state.get("offsetDays") or "0")
  if res == nil then
    setError(err)
    return nil
  end
  state.set("addResult", res)
  state.set("hasAdd", true)
end
