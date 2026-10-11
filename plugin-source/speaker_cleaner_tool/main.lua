-- 扬声器排水与清灰震动器

local currentMode = "dust"
local isRunning = false

function onInit()
    currentMode = "dust"
    isRunning = false
    state.set("mode", "dust")
    state.set("modeTitle", "扬声器清灰模式 (165Hz)")
    state.set("modeDesc", "利用 165Hz 声波共振震落微孔浮尘。请将音量调至最大并将扬声器朝下。")
    state.set("frequency", 165)
    state.set("durationSec", 30)
    state.set("isRunning", false)
    state.set("statusText", "状态：就绪，请调大设备音量")
    state.set("progressPercent", "0%")
    state.set("remainingSec", 30)
    state.set("hasCompleted", false)
    return nil
end

function setMode(mode)
    if mode == "dust" then
        currentMode = "dust"
        state.set("mode", "dust")
        state.set("modeTitle", "扬声器清灰模式 (165Hz)")
        state.set("modeDesc", "利用 165Hz 声波共振震落微孔浮尘。请将音量调至最大并将扬声器朝下。")
        state.set("frequency", 165)
    else
        if mode == "water" then
            currentMode = "water"
            state.set("mode", "water")
            state.set("modeTitle", "强力排水模式 (180Hz)")
            state.set("modeDesc", "以 180Hz 连续音频气流将扬声器滤网表面积水向外吹出。")
            state.set("frequency", 180)
        else
            currentMode = "pulse"
            state.set("mode", "pulse")
            state.set("modeTitle", "低频共振脉冲 (120Hz)")
            state.set("modeDesc", "120Hz 超重低音频波与线性马达交替冲击，疏通顽固受潮杂质。")
            state.set("frequency", 120)
        end
    end
    state.set("statusText", "已切换至: " .. state.get("modeTitle"))
    return nil
end

function startCleaning()
    if isRunning then
        return nil
    end
    isRunning = true
    state.set("isRunning", true)
    state.set("hasCompleted", false)
    state.set("statusText", "正在发射共振声波与气流...")
    state.set("remainingSec", 30)
    state.set("progressPercent", "10%")

    -- 保持屏幕常亮
    if screen ~= nil then
        pcall(function()
            screen.setKeepScreenOn(true)
        end)
    end

    -- 触发音频播放
    local freq = state.get("frequency") or 165
    if audio ~= nil then
        pcall(function()
            audio.playTone(freq, 30)
        end)
    end

    -- 触发马达震动
    if haptic ~= nil then
        pcall(function()
            haptic.heavy()
        end)
    end

    dialog.toast("声波清理已启动，请将机身向下倾斜")
    return nil
end

function stopCleaning()
    isRunning = false
    state.set("isRunning", false)
    state.set("statusText", "清理已终止")

    if audio ~= nil then
        pcall(function()
            audio.stop()
        end)
    end
    if screen ~= nil then
        pcall(function()
            screen.setKeepScreenOn(false)
        end)
    end

    dialog.toast("声波播放已停止")
    return nil
end

function finishCleaning()
    isRunning = false
    state.set("isRunning", false)
    state.set("hasCompleted", true)
    state.set("statusText", "清理完成！扬声器声波脉冲冲刷完毕")
    state.set("progressPercent", "100%")
    state.set("remainingSec", 0)

    if audio ~= nil then
        pcall(function()
            audio.stop()
        end)
    end
    if screen ~= nil then
        pcall(function()
            screen.setKeepScreenOn(false)
        end)
    end
    if haptic ~= nil then
        pcall(function()
            haptic.light()
        end)
    end

    dialog.toast("扬声器排水清灰完成")
    return nil
end

function onDispose()
    if isRunning then
        stopCleaning()
    end
    return nil
end
