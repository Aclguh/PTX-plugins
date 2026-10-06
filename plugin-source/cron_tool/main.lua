-- cron_tool — Cron 表达式解析与未来执行时间预览
-- 5 段格式: [分钟 0-59] [小时 0-23] [日 1-31] [月 1-12] [星期 0-6 (0=周日)]

local WEEKDAY_NAMES = { "周日", "周一", "周二", "周三", "周四", "周五", "周六" }
local DEFAULT_TZ = 480 -- UTC+8 (480 分钟)

local function isLeap(y)
  if (y % 4 == 0 and y % 100 ~= 0) or (y % 400 == 0) then
    return true
  else
    return false
  end
end

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

local function daysFromCivil(y, m, d)
  if m <= 2 then y = y - 1 end
  local era = math.floor(y / 400)
  local yoe = y - era * 400
  local doy = math.floor((153 * (m + (m > 2 and -3 or 9)) + 2) / 5) + d - 1
  local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
  return era * 146097 + doe - 719468
end

local function splitSpaces(s)
  local parts = {}
  local len = string.len(s)
  local cur = {}
  for i = 1, len do
    local c = string.byte(s, i)
    if c == 32 or c == 9 then
      if #cur > 0 then
        parts[#parts + 1] = table.concat(cur)
        cur = {}
      end
    else
      cur[#cur + 1] = string.char(c)
    end
  end
  if #cur > 0 then
    parts[#parts + 1] = table.concat(cur)
  end
  return parts
end

function _parse_cron_field(field_str, min_val, max_val)
  local set = {}
  local items = {}
  local len = string.len(field_str)
  local cur = {}
  for i = 1, len do
    local c = string.byte(field_str, i)
    if c == 44 then -- ','
      if #cur > 0 then
        items[#items + 1] = table.concat(cur)
        cur = {}
      end
    else
      cur[#cur + 1] = string.char(c)
    end
  end
  if #cur > 0 then
    items[#items + 1] = table.concat(cur)
  end

  for _, item in ipairs(items) do
    local step = 1
    local range_str = item
    local slash_idx = string.find(item, "/", 1, true)
    if slash_idx ~= nil then
      range_str = string.sub(item, 1, slash_idx - 1)
      local step_str = string.sub(item, slash_idx + 1)
      step = tonumber(step_str) or 1
      if step <= 0 then step = 1 end
    end

    local r_start = min_val
    local r_end = max_val

    if range_str == "*" then
      r_start = min_val
      r_end = max_val
    else
      local dash_idx = string.find(range_str, "-", 1, true)
      if dash_idx ~= nil then
        local s1 = string.sub(range_str, 1, dash_idx - 1)
        local s2 = string.sub(range_str, dash_idx + 1)
        r_start = tonumber(s1) or min_val
        r_end = tonumber(s2) or max_val
      else
        local num = tonumber(range_str)
        if num ~= nil then
          r_start = num
          r_end = num
          if slash_idx ~= nil then
            r_end = max_val
          end
        end
      end
    end

    if r_start < min_val then r_start = min_val end
    if r_end > max_val then r_end = max_val end

    local v = r_start
    while v <= r_end do
      set[v] = true
      v = v + step
    end
  end

  -- 特殊处理：星期字段中 7 等同于 0 (周日)
  if min_val == 0 and max_val == 6 and set[7] then
    set[0] = true
    set[7] = nil
  end

  return set
end

function _explain_cron(expr)
  local parts = splitSpaces(expr)
  if #parts ~= 5 then
    return "格式错误：需要 5 段空格分隔的表达式 (分 时 日 月 周)"
  end

  local m, h, dom, mon, dow = parts[1], parts[2], parts[3], parts[4], parts[5]
  local desc = {}

  -- 月
  if mon ~= "*" then
    desc[#desc + 1] = mon .. " 月"
  end

  -- 日 / 周
  if dom ~= "*" and dow ~= "*" then
    desc[#desc + 1] = dom .. " 日且逢周 " .. dow
  elseif dom ~= "*" then
    desc[#desc + 1] = "每月 " .. dom .. " 日"
  elseif dow ~= "*" then
    if dow == "1-5" then
      desc[#desc + 1] = "工作日 (周一至周五)"
    elseif dow == "0,6" or dow == "6,0" then
      desc[#desc + 1] = "周末 (周六日)"
    else
      desc[#desc + 1] = "每周 " .. dow
    end
  else
    if mon == "*" then
      desc[#desc + 1] = "每天"
    end
  end

  -- 时 / 分
  if h == "*" and m == "*" then
    desc[#desc + 1] = "每分钟"
  elseif h == "*" and string.find(m, "*/", 1, true) == 1 then
    desc[#desc + 1] = "每隔 " .. string.sub(m, 3) .. " 分钟"
  elseif string.find(h, "*/", 1, true) == 1 and m == "0" then
    desc[#desc + 1] = "每隔 " .. string.sub(h, 3) .. " 小时整点"
  elseif h ~= "*" and m == "0" then
    desc[#desc + 1] = string.format("%02d:00", tonumber(h) or 0)
  elseif h ~= "*" and m ~= "*" then
    desc[#desc + 1] = string.format("%02d:%02d", tonumber(h) or 0, tonumber(m) or 0)
  elseif h == "*" then
    desc[#desc + 1] = "每小时的第 " .. m .. " 分钟"
  end

  desc[#desc + 1] = "执行"
  return table.concat(desc, " ")
end

function _next_runs(expr, baseEpoch, count, tzMin)
  local parts = splitSpaces(expr)
  if #parts ~= 5 then return {} end

  local m_set = _parse_cron_field(parts[1], 0, 59)
  local h_set = _parse_cron_field(parts[2], 0, 23)
  local dom_set = _parse_cron_field(parts[3], 1, 31)
  local mon_set = _parse_cron_field(parts[4], 1, 12)
  local dow_set = _parse_cron_field(parts[5], 0, 6)

  local dom_any = (parts[3] == "*")
  local dow_any = (parts[5] == "*")

  local tz = tzMin or DEFAULT_TZ
  local startSec = baseEpoch + tz * 60
  -- 向上对齐到下一整分钟
  local curMin = math.floor(startSec / 60) + 1

  local results = {}
  local maxMinutes = 100000 -- 最多扫描约 70 天
  local scanned = 0

  while #results < count and scanned < maxMinutes do
    local sec = curMin * 60
    local days = math.floor(sec / 86400)
    local secsOfDay = sec - days * 86400
    local hh = math.floor(secsOfDay / 3600)
    local mi = math.floor((secsOfDay - hh * 3600) / 60)

    if m_set[mi] and h_set[hh] then
      local y, m, d = civilFromDays(days)
      if mon_set[m] then
        local wDay = (days + 4) % 7 -- 0=周日, 1=周一...
        local dayMatch = false
        if dom_any and dow_any then
          dayMatch = true
        elseif dom_any then
          dayMatch = (dow_set[wDay] == true)
        elseif dow_any then
          dayMatch = (dom_set[d] == true)
        else
          dayMatch = (dom_set[d] == true) or (dow_set[wDay] == true)
        end

        if dayMatch then
          local wName = WEEKDAY_NAMES[wDay + 1]
          results[#results + 1] = string.format("%04d-%02d-%02d %02d:%02d:00 (%s)", y, m, d, hh, mi, wName)
        end
      end
    end

    curMin = curMin + 1
    scanned = scanned + 1
  end

  return results
end

function parseCron()
  local expr = state.get("cronExpr") or ""
  local parts = splitSpaces(expr)
  if #parts ~= 5 then
    state.set("hasError", true)
    state.set("errorMsg", "表达式格式错误：请输入 5 位以空格分隔的字段 (分 时 日 月 周)")
    state.set("hasResult", false)
    return nil
  end

  local expl = _explain_cron(expr)
  local nowEpoch = util.timestamp()
  local runs = _next_runs(expr, nowEpoch, 5, DEFAULT_TZ)

  state.set("hasError", false)
  state.set("errorMsg", "")
  state.set("explanation", expl)
  state.set("nextRuns", table.concat(runs, "\n"))
  state.set("hasResult", true)
  return nil
end

function setPreset5m()
  state.set("cronExpr", "*/5 * * * *")
  parseCron()
  return nil
end

function setPresetHour()
  state.set("cronExpr", "0 * * * *")
  parseCron()
  return nil
end

function setPresetDay()
  state.set("cronExpr", "0 0 * * *")
  parseCron()
  return nil
end

function setPresetWorkday()
  state.set("cronExpr", "0 9 * * 1-5")
  parseCron()
  return nil
end

function clearAll()
  state.set("cronExpr", "")
  state.set("explanation", "")
  state.set("nextRuns", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function pasteExpr()
  clipboard.get(function(text)
    if text ~= nil then
      state.set("cronExpr", text)
      parseCron()
    end
    return nil
  end)
  return nil
end

function onInit()
  state.set("cronExpr", "*/15 * * * *")
  state.set("explanation", "")
  state.set("nextRuns", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  parseCron()
  return nil
end
