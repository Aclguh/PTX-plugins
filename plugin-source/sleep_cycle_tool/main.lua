-- 90 分钟 R90 睡眠周期推算器

local function formatTimeOfDay(totalMinutes)
    totalMinutes = (totalMinutes % 1440 + 1440) % 1440
    local h = math.floor(totalMinutes / 60)
    local m = totalMinutes % 60
    return string.format("%02d:%02d", h, m)
end

function onInit()
    state.set("targetWakeTime", "07:00")
    state.set("sleepNowTitle", "如果现在入睡 (包含 14 分钟入睡潜伏期)")
    state.set("wakeUpSlots", "• 周期 5 (7.5h 黄金推荐): 07:14 ⭐\n• 周期 6 (9.0h 充足): 08:44\n• 周期 4 (6.0h 适中): 05:44\n• 周期 3 (4.5h 应急): 04:14")
    state.set("targetBedSlots", "• 周期 5 (黄金 7.5h): 23:16 入睡 ⭐\n• 周期 6 (充足 9.0h): 21:46 入睡\n• 周期 4 (适中 6.0h): 00:46 入睡\n• 周期 3 (应急 4.5h): 02:16 入睡")
    state.set("scienceTip", "科学依据：人在浅睡阶段 (周期末端) 被唤醒时最具活力，而在慢波深睡阶段被唤醒会导致严重的睡眠惰性头晕。")

    calcSleepNow()
    return nil
end

function calcSleepNow()
    local curTotalMin = 23 * 60 + 30 -- 默认 23:30
    if util ~= nil and util.timestamp ~= nil then
        local ts = util.timestamp()
        local localTs = ts + 28800
        local secInDay = localTs % 86400
        curTotalMin = math.floor(secInDay / 60)
    end

    local sleepMin = curTotalMin + 14 -- 加 14 分钟入睡时间
    local c3 = formatTimeOfDay(sleepMin + 3 * 90)
    local c4 = formatTimeOfDay(sleepMin + 4 * 90)
    local c5 = formatTimeOfDay(sleepMin + 5 * 90)
    local c6 = formatTimeOfDay(sleepMin + 6 * 90)

    state.set("sleepNowTitle", string.format("如果当前 %s 入睡 (含14m入睡期)：", formatTimeOfDay(curTotalMin)))
    state.set("wakeUpSlots", string.format("• 周期 5 (7.5h 黄金推荐): %s 醒来 ⭐\n• 周期 6 (9.0h 深度充足): %s 醒来\n• 周期 4 (6.0h 适度清醒): %s 醒来\n• 周期 3 (4.5h 最低应急): %s 醒来",
        c5, c6, c4, c3))
    dialog.toast("已推算最佳醒来时间点")
    return nil
end

function calcTargetWake()
    local s = state.get("targetWakeTime") or "07:00"
    local colon = string.find(s, ":", 1, true)
    local h = 7
    local m = 0
    if colon then
        h = tonumber(string.sub(s, 1, colon - 1)) or 7
        m = tonumber(string.sub(s, colon + 1, string.len(s))) or 0
    end
    local targetMin = h * 60 + m

    local b5 = formatTimeOfDay(targetMin - 5 * 90 - 14)
    local b6 = formatTimeOfDay(targetMin - 6 * 90 - 14)
    local b4 = formatTimeOfDay(targetMin - 4 * 90 - 14)
    local b3 = formatTimeOfDay(targetMin - 3 * 90 - 14)

    state.set("targetBedSlots", string.format("若计划 %02d:%02d 起床，建议以下时刻上床关灯：\n• 周期 5 (7.5h 黄金推荐): %s 入睡 ⭐\n• 周期 6 (9.0h 充足长睡): %s 入睡\n• 周期 4 (6.0h 精炼作息): %s 入睡\n• 周期 3 (4.5h 应急极短): %s 入睡",
        h, m, b5, b6, b4, b3))
    dialog.toast(string.format("已计算目标 %02d:%02d 最佳入睡窗口", h, m))
    return nil
end

function copyAdvice()
    local text = string.format("R90 睡眠周期规划报告:\n%s\n%s\n%s\n%s",
        state.get("sleepNowTitle") or "",
        state.get("wakeUpSlots") or "",
        state.get("targetBedSlots") or "",
        state.get("scienceTip") or "")
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("作息规划已复制")
    return nil
end
