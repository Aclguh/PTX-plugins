-- 触觉盲感暗度报时器

local curH = 16
local curM = 45
local isDark = false

local function calculateTactile(h, m)
    -- 12 小时制时针
    local h12 = h % 12
    if h12 == 0 then
        h12 = 12
    end
    local quarters = math.floor(m / 15)
    local remainMin = m % 15

    local formula = string.format("时震: %d 次重震 | 刻震: %d 次中震 | 零头: %d 次轻震", h12, quarters, remainMin)
    state.set("tactileFormula", formula)
    state.set("timeDisplay", string.format("%02d:%02d", h, m))
    state.set("hoursHaptic", h12)
    state.set("quartersHaptic", quarters)
    state.set("minutesHaptic", remainMin)
    return h12, quarters, remainMin
end

function onInit()
    isDark = false
    curH = 16
    curM = 45

    if util ~= nil and util.timestamp ~= nil then
        local ts = util.timestamp()
        -- UTC+8 偏移 8*3600 秒
        local localTs = ts + 28800
        local secInDay = localTs % 86400
        curH = math.floor(secInDay / 3600)
        curM = math.floor((secInDay % 3600) / 60)
    end

    state.set("screenBgColor", "#FFFFFF")
    state.set("isDarkMode", false)
    state.set("vibeLog", "就绪：轻触「立即触觉报时」体验震动")

    calculateTactile(curH, curM)
    return nil
end

function triggerVibrate()
    local h12, quarters, remainMin = calculateTactile(curH, curM)

    -- 触发震动
    if haptic ~= nil then
        pcall(function()
            local i = 1
            while i <= h12 do
                haptic.heavy()
                i = i + 1
            end
            local j = 1
            while j <= quarters do
                haptic.medium()
                j = j + 1
            end
            local k = 1
            while k <= remainMin do
                haptic.light()
                k = k + 1
            end
        end)
    end

    state.set("vibeLog", string.format("已发送报时脉冲：%d次重震 + %d次中震 + %d次轻震", h12, quarters, remainMin))
    dialog.toast(string.format("触觉脉冲发送完毕 (%02d:%02d)", curH, curM))
    return nil
end

function toggleDarkMode()
    isDark = not isDark
    state.set("isDarkMode", isDark)
    if isDark then
        state.set("screenBgColor", "#121212")
        dialog.toast("已开启纯黑暗光防窥模式")
    else
        state.set("screenBgColor", "#FFFFFF")
        dialog.toast("已退出纯黑模式")
    end
    return nil
end

function setTestTime(h, m)
    curH = h or 12
    curM = m or 0
    calculateTactile(curH, curM)
    state.set("vibeLog", string.format("已设置测试时间: %02d:%02d", curH, curM))
    return nil
end
