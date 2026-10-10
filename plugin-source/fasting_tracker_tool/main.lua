-- 轻断食倒计时与燃脂阶段看板

local targetHours = 16
local startTs = 0
local isFasting = false

local function getStageInfo(elapsedHours)
    if elapsedHours < 4.0 then
        return "阶段一：消化与吸收期 (0-4h)", "血糖和胰岛素处于峰值，身体正在消化最后一餐的碳水和脂肪。"
    else
        if elapsedHours < 8.0 then
            return "阶段二：血糖回落与糖原消耗期 (4-8h)", "胰岛素回落至基线，机体开始调动并消耗肝脏储存的糖原。"
        else
            if elapsedHours < 12.0 then
                return "阶段三：燃脂启动与代谢转换期 (8-12h)", "肝糖原几乎消耗殆尽，机体代谢正式向脂肪酸氧化供能切换！"
            else
                if elapsedHours < 18.0 then
                    return "阶段四：深度脂肪燃烧与轻度酮体期 (12-18h)", "游离脂肪酸大量进入线粒体氧化分解，体脂加速燃烧中。"
                else
                    return "阶段五：细胞自噬与抗衰修复期 (18h+)", "细胞自噬 (Autophagy) 达到高峰，机体深度回收受损蛋白与衰老细胞！"
                end
            end
        end
    end
end

local function updateDisplays(elapsedHours)
    local remainHours = targetHours - elapsedHours
    if remainHours < 0 then
        remainHours = 0
    end

    local stageTitle, stageDesc = getStageInfo(elapsedHours)
    local progress = math.floor((elapsedHours / targetHours) * 100)
    if progress > 100 then
        progress = 100
    end

    state.set("elapsedDisplay", string.format("已断食: %.1f 小时 / 目标 %d 小时", elapsedHours, targetHours))
    state.set("remainDisplay", string.format("剩余时间: %.1f 小时 (%d%%)", remainHours, progress))
    state.set("stageTitle", stageTitle)
    state.set("stageDesc", stageDesc)
    state.set("progressLabel", string.format("进度 %d%%", progress))
    state.set("modeDesc", string.format("当前模式: %d:%d", targetHours, 24 - targetHours))
    return nil
end

function onInit()
    targetHours = 16
    startTs = 0
    isFasting = false

    state.set("elapsedDisplay", "已断食: 12.5 小时 / 目标 16 小时")
    state.set("remainDisplay", "剩余时间: 3.5 小时 (78%)")
    state.set("stageTitle", "阶段四：深度脂肪燃烧与轻度酮体期 (12-18h)")
    state.set("stageDesc", "游离脂肪酸大量进入线粒体氧化分解，体脂加速燃烧中。")
    state.set("progressLabel", "进度 78%")
    state.set("modeDesc", "当前模式: 16:8 经典断食")
    state.set("statusLabel", "进行中")

    if storage ~= nil and storage.get ~= nil then
        pcall(function()
            storage.get("fasting_start_ts", function(val)
                if val ~= nil and val ~= "" then
                    local ts = tonumber(val) or 0
                    if ts > 0 and util ~= nil and util.timestamp ~= nil then
                        startTs = ts
                        isFasting = true
                        local now = util.timestamp()
                        local elapsedH = (now - startTs) / 3600.0
                        updateDisplays(elapsedH)
                        state.set("statusLabel", "断食进行中")
                    end
                end
            end)
        end)
    end
    return nil
end

function setMode(hours)
    targetHours = hours or 16
    state.set("modeDesc", string.format("当前模式: %d:%d", targetHours, 24 - targetHours))
    updateDisplays(12.5)
    dialog.toast(string.format("已切换至 %d:%d 断食模式", targetHours, 24 - targetHours))
    return nil
end

function startFasting()
    local now = 0
    if util ~= nil and util.timestamp ~= nil then
        now = util.timestamp()
    end
    startTs = now
    isFasting = true
    state.set("statusLabel", "断食计时中...")

    if storage ~= nil and storage.set ~= nil then
        pcall(function()
            storage.set("fasting_start_ts", tostring(now))
        end)
    end

    updateDisplays(0.0)
    dialog.toast("新一轮轻断食已开始计时！")
    return nil
end

function stopFasting()
    isFasting = false
    startTs = 0
    state.set("statusLabel", "断食已结束")

    if storage ~= nil and storage.remove ~= nil then
        pcall(function()
            storage.remove("fasting_start_ts")
        end)
    end

    dialog.toast("已结束当前断食周期，请补充温水或优质蛋白")
    return nil
end

function simulateElapsed(hours)
    updateDisplays(hours)
    dialog.toast(string.format("已载入断食 %d 小时阶段模拟", hours))
    return nil
end

function copyStatus()
    local text = string.format("轻断食状态报告:\n%s\n%s\n%s\n%s\n说明: %s",
        state.get("modeDesc") or "",
        state.get("elapsedDisplay") or "",
        state.get("remainDisplay") or "",
        state.get("stageTitle") or "",
        state.get("stageDesc") or "")
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("断食状态已复制")
    return nil
end
