-- timestamp_tool — 时间戳转换
-- 宿主沙箱无 os 库, 历法换算自实现 (Hinnant days_from_civil / civil_from_days)

local function isLeap(y)
  return (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0
end

local DAYS_IN_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local function daysInMonth(y, m)
  if m == 2 and isLeap(y) then return 29 end
  return DAYS_IN_MONTH[m]
end

-- 公历日期 -> 自 1970-01-01 起的天数 (Howard Hinnant 算法, 支持负年份)
local function daysFromCivil(y, m, d)
  if m <= 2 then y = y - 1 end
  local era = math.floor(y / 400)
  local yoe = y - era * 400                                  -- [0, 399]
  local doy = math.floor((153 * (m + (m > 2 and -3 or 9)) + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

-- 天数 -> 公历日期 (返回 y, m, d)
local function civilFromDays(z)
  z = z + 719468
  local era = math.floor(z / 146097)
  local doe = z - era * 146097                               -- [0, 146096]
  local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
  local mp = math.floor((5 * doy + 2) / 153)
  local d = doy - math.floor((153 * mp + 2) / 5) + 1
  local m = mp + (mp < 10 and 3 or -9)
  if m <= 2 then y = y + 1 end
  return y, m, d
end

local WEEKDAYS = { "星期四", "星期五", "星期六", "星期日", "星期一", "星期二", "星期三" }

-- Unix 秒 -> "YYYY-MM-DD HH:MM:SS 星期X" (可附加时区偏移分钟)
local function formatEpoch(sec, tzMinutes)
  local shifted = sec + (tzMinutes or 0) * 60
  local days = math.floor(shifted / 86400)
  local secsOfDay = shifted - days * 86400
  if secsOfDay < 0 then
    secsOfDay = secsOfDay + 86400
    days = days - 1
  end
  local y, m, d = civilFromDays(days)
  local hh = math.floor(secsOfDay / 3600)
  local mi = math.floor((secsOfDay - hh * 3600) / 60)
  local ss = secsOfDay - hh * 3600 - mi * 60
  local wd = WEEKDAYS[(days % 7) + 1]
  return string.format("%04d-%02d-%02d %02d:%02d:%02d %s", y, m, d, hh, mi, ss, wd)
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _formatEpoch(sec, tz)
  return formatEpoch(sec, tz)
end

function _dateToEpoch(y, mo, d, h, mi, s)
  return daysFromCivil(y, mo, d) * 86400 + h * 3600 + mi * 60 + s
end

-- ---------------- 插件状态与交互 ----------------
local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

function onInit()
  state.set("tsInput", "")
  state.set("tzOffset", "480")
  state.set("tsResult", "")
  state.set("hasTsResult", false)
  state.set("dY", "2024"); state.set("dMo", "10"); state.set("dD", "1")
  state.set("dH", "12"); state.set("dMi", "0"); state.set("dS", "0")
  state.set("dateResult", "")
  state.set("hasDateResult", false)
  clearError()
  refreshNow()
end

function refreshNow()
  local ts = util.timestamp()
  state.set("nowText", formatEpoch(ts, 0)
      .. "\nUnix 秒: " .. ts .. " · 毫秒: " .. ts * 1000)
end

function tsToDate()
  clearError()
  state.set("hasTsResult", false)
  local raw = state.get("tsInput") or ""
  if raw == "" then
    setError("请输入时间戳")
    return nil
  end
  local v = tonumber(raw)
  -- 注意: 宿主 VM 对函数内多条件 or 链存在上下文相关的误编译 (实测同语句
  -- 在 chunk 顶层正常、在函数体内失效), 多条件守卫一律用嵌套 if 规避
  if v == nil then
    setError("时间戳必须是正整数")
    return nil
  end
  if v < 0 then
    setError("时间戳必须是正整数")
    return nil
  end
  if v ~= math.floor(v) then
    setError("时间戳必须是正整数")
    return nil
  end
  -- 毫秒自动识别: >= 1e12 视为毫秒
  local isMs = v >= 1000000000000
  local sec = isMs and math.floor(v / 1000) or v
  if sec > 253402300799 then
    setError("时间戳超出可表示范围 (公元 9999 年之后)")
    return nil
  end
  local tz = tonumber(state.get("tzOffset") or "0") or 0
  local lines = { (isMs and "毫秒" or "秒") .. "时间戳: " .. v }
  lines[#lines + 1] = "UTC: " .. formatEpoch(sec, 0)
  lines[#lines + 1] = "UTC" .. (tz >= 0 and "+" or "-") .. math.abs(tz) / 60 .. ": " .. formatEpoch(sec, tz)
  state.set("tsResult", table.concat(lines, "\n"))
  state.set("hasTsResult", true)
end

function dateToTs()
  clearError()
  state.set("hasDateResult", false)
  local y = tonumber(state.get("dY"))
  local mo = tonumber(state.get("dMo"))
  local d = tonumber(state.get("dD"))
  local h = tonumber(state.get("dH")) or 0
  local mi = tonumber(state.get("dMi")) or 0
  local s = tonumber(state.get("dS")) or 0
  if y == nil or mo == nil or d == nil then
    setError("年月日必须为数字")
    return nil
  end
  if mo < 1 or mo > 12 then
    setError("月份必须在 1-12 之间")
    return nil
  end
  if d < 1 or d > daysInMonth(y, mo) then
    setError("该月不存在 " .. d .. " 日")
    return nil
  end
  if h < 0 or h > 23 or mi < 0 or mi > 59 or s < 0 or s > 59 then
    setError("时间必须在 24 时制范围内")
    return nil
  end
  local epoch = daysFromCivil(y, mo, d) * 86400 + h * 3600 + mi * 60 + s
  local tz = tonumber(state.get("tzOffset") or "0") or 0
  state.set("dateResult", "Unix 秒: " .. epoch
      .. "\nUnix 毫秒: " .. epoch * 1000
      .. "\n按当前时区偏移为: " .. formatEpoch(epoch, tz))
  state.set("hasDateResult", true)
end

function pasteTs()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("tsInput", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
