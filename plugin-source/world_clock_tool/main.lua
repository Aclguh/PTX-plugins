-- world_clock_tool — 世界时钟与时区换算

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

local WEEKDAYS = {
  [0] = "周日", [1] = "周一", [2] = "周二",
  [3] = "周三", [4] = "周四", [5] = "周五", [6] = "周六"
}

-- Howard Hinnant 日历换算 (days from 1970-01-01 -> Year, Month, Day)
function _days_to_civil(days)
  local z = days + 719468
  local era = 0
  if z >= 0 then
    era = math.floor(z / 146097)
  else
    era = math.floor((z - 146096) / 146097)
  end
  local doe = z - era * 146097
  local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
  local mp = math.floor((5 * doy + 2) / 153)
  local d = doy - math.floor((153 * mp + 2) / 5) + 1
  local m = 0
  if mp < 10 then
    m = mp + 3
  else
    m = mp - 9
  end
  if m <= 2 then
    y = y + 1
  end
  return y, m, d
end

-- Civil date -> days since 1970-01-01
function _civil_to_days(y, m, d)
  local yAdj = y
  if m <= 2 then
    yAdj = yAdj - 1
  end
  local era = 0
  if yAdj >= 0 then
    era = math.floor(yAdj / 400)
  else
    era = math.floor((yAdj - 399) / 400)
  end
  local yoe = yAdj - era * 400
  local doy = 0
  if m > 2 then
    doy = math.floor((153 * (m - 3) + 2) / 5) + d - 1
  else
    doy = math.floor((153 * (m + 9) + 2) / 5) + d - 1
  end
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

function _format_tz_time(utcTimestamp, offsetHours)
  local t = utcTimestamp + math.floor(offsetHours * 3600)
  local days = math.floor(t / 86400)
  local secOfDay = t % 86400
  if secOfDay < 0 then
    secOfDay = secOfDay + 86400
    days = days - 1
  end

  local hour = math.floor(secOfDay / 3600)
  local min = math.floor((secOfDay % 3600) / 60)
  local sec = secOfDay % 60

  local wd = (days + 4) % 7
  if wd < 0 then wd = wd + 7 end

  local y, m, d = _days_to_civil(days)

  local isWorkHour = (hour >= 9 and hour < 18)
  local workTag = isWorkHour and "🟢 办公时间" or "🌙 非工作时间"

  local dateStr = string.format("%04d-%02d-%02d", y, m, d)
  local timeStr = string.format("%02d:%02d:%02d", hour, min, sec)
  local weekdayStr = WEEKDAYS[wd] or ""

  return {
    date = dateStr,
    time = timeStr,
    weekday = weekdayStr,
    hour = hour,
    full = dateStr .. " " .. timeStr .. " " .. weekdayStr,
    isWork = isWorkHour,
    workTag = workTag
  }
end

local CITIES = {
  { id = "bj", name = "北京 / 上海 (UTC+8)", offset = 8 },
  { id = "tk", name = "东京 / 首尔 (UTC+9)", offset = 9 },
  { id = "lon", name = "伦敦 / UTC (UTC+0)", offset = 0 },
  { id = "par", name = "巴黎 / 柏林 (UTC+1)", offset = 1 },
  { id = "ny", name = "纽约 / 美东 (UTC-5)", offset = -5 },
  { id = "sf", name = "旧金山 / 美西 (UTC-8)", offset = -8 },
  { id = "syd", name = "悉尼 (UTC+11)", offset = 11 },
  { id = "dxb", name = "迪拜 (UTC+4)", offset = 4 }
}

function updateClocks(utcSec)
  local baseSec = utcSec
  if baseSec == nil then
    if util and util.timestamp then
      baseSec = util.timestamp()
    else
      baseSec = 1727654400
    end
  end

  state.set("curUtcTimestamp", tostring(baseSec))

  local reportLines = {}
  reportLines[#reportLines + 1] = "【全球主要时区对应时间】"

  for i = 1, #CITIES do
    local c = CITIES[i]
    local res = _format_tz_time(baseSec, c.offset)
    local line = c.name .. ": " .. res.time .. " (" .. res.date .. " " .. res.weekday .. ") " .. res.workTag
    reportLines[#reportLines + 1] = line
    state.set("time_" .. c.id, res.time .. "  " .. res.weekday .. "  " .. res.workTag)
    state.set("date_" .. c.id, res.date)
  end

  state.set("copyText", table.concat(reportLines, "\n"))
  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function refreshCurrent()
  local nowSec = 1727654400
  if util and util.timestamp then
    nowSec = util.timestamp()
  end
  updateClocks(nowSec)
  return nil
end

function convertInputTime()
  -- Input string like 2026-10-07 14:00
  local raw = trim(state.get("customTime") or "")
  if raw == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入时间 (格式: YYYY-MM-DD HH:MM)")
    return nil
  end

  local spacePos = string.find(raw, " ", 1, true)
  if not spacePos then
    state.set("hasError", true)
    state.set("errorMsg", "格式需为 YYYY-MM-DD HH:MM (日期与时间用空格分隔)")
    return nil
  end

  local datePart = string.sub(raw, 1, spacePos - 1)
  local timePart = string.sub(raw, spacePos + 1)

  local dp = {}
  local start = 1
  while true do
    local p = string.find(datePart, "-", start, true)
    if not p then
      dp[#dp + 1] = string.sub(datePart, start)
      break
    end
    dp[#dp + 1] = string.sub(datePart, start, p - 1)
    start = p + 1
  end

  if #dp ~= 3 then
    state.set("hasError", true)
    state.set("errorMsg", "日期格式错误，应如 2026-10-07")
    return nil
  end

  local y = tonumber(dp[1])
  local m = tonumber(dp[2])
  local d = tonumber(dp[3])
  if y == nil or m == nil or d == nil or m < 1 or m > 12 or d < 1 or d > 31 then
    state.set("hasError", true)
    state.set("errorMsg", "无效的日期数字")
    return nil
  end

  local colonPos = string.find(timePart, ":", 1, true)
  if not colonPos then
    state.set("hasError", true)
    state.set("errorMsg", "时间格式错误，应如 14:00")
    return nil
  end

  local h = tonumber(string.sub(timePart, 1, colonPos - 1))
  local min = tonumber(string.sub(timePart, colonPos + 1))
  if h == nil or min == nil or h < 0 or h > 23 or min < 0 or min > 59 then
    state.set("hasError", true)
    state.set("errorMsg", "时间数字范围无效 (小时 0~23, 分钟 0~59)")
    return nil
  end

  local baseOffset = tonumber(state.get("baseTzOffset") or "8") or 8
  local days = _civil_to_days(y, m, d)
  local localSec = days * 86400 + h * 3600 + min * 60
  local utcSec = localSec - math.floor(baseOffset * 3600)

  updateClocks(utcSec)
  return nil
end

function copyResult()
  local text = state.get("copyText") or ""
  if text ~= "" and clipboard and clipboard.set then
    clipboard.set(text)
  end
  if dialog and dialog.toast then
    dialog.toast("已复制全球时间排期")
  end
  return nil
end

function onInit()
  state.set("customTime", "2026-10-07 14:00")
  state.set("baseTzOffset", "8")
  state.set("curUtcTimestamp", "")
  state.set("time_bj", "")
  state.set("date_bj", "")
  state.set("time_tk", "")
  state.set("date_tk", "")
  state.set("time_lon", "")
  state.set("date_lon", "")
  state.set("time_par", "")
  state.set("date_par", "")
  state.set("time_ny", "")
  state.set("date_ny", "")
  state.set("time_sf", "")
  state.set("date_sf", "")
  state.set("time_syd", "")
  state.set("date_syd", "")
  state.set("time_dxb", "")
  state.set("date_dxb", "")
  state.set("copyText", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  refreshCurrent()
  return nil
end
