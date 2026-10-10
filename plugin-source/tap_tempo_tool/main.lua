-- BPM 节拍测速与心率估测器

local tapTimes = {}
local currentBpm = 120.0
local lastTapMs = 0

local function getTempoName(bpm)
    if bpm < 60 then
        return "Largo 广板 (<60)"
    else
        if bpm < 76 then
            return "Adagio 柔板 (60-76)"
        else
            if bpm < 108 then
                return "Andante 行板 (76-108)"
            else
                if bpm < 120 then
                    return "Moderato 中板 (108-120)"
                else
                    if bpm < 168 then
                        return "Allegro 快板 (120-168)"
                    else
                        return "Presto 急板 (>168)"
                    end
                end
            end
        end
    end
end

local function getHrZone(bpm)
    if bpm < 60 then
        return "静息偏慢心率 (缓和状态)"
    else
        if bpm <= 100 then
            return "正常静息心率 (60-100 BPM)"
        else
            if bpm <= 135 then
                return "低强度燃脂区 (100-135 BPM)"
            else
                if bpm <= 165 then
                    return "有氧耐力心率区 (135-165 BPM)"
                else
                    return "极限高强度无氧区 (>165 BPM)"
                end
            end
        end
    end
end

local function updateDisplays(bpm, count)
    currentBpm = bpm
    state.set("bpmDisplay", string.format("%.1f", bpm))
    state.set("tapCount", count)
    state.set("tapCountLabel", string.format("已连续敲击 %d 次", count))
    state.set("tempoTerm", getTempoName(bpm))
    state.set("hrZone", getHrZone(bpm))
    state.set("intervalMs", string.format("均值间隔: %.1f ms", 60000.0 / bpm))
    return nil
end

function onInit()
    tapTimes = {}
    lastTapMs = 0
    currentBpm = 120.0
    state.set("bpmDisplay", "120.0")
    state.set("tapCount", 0)
    state.set("tapCountLabel", "点击下方「TAP 拍打」开始测速")
    state.set("tempoTerm", "Moderato 中板")
    state.set("hrZone", "有氧心率基准")
    state.set("intervalMs", "均值间隔: 500.0 ms")
    return nil
end

function tapTempo()
    local nowMs = 0
    if util ~= nil and util.timestampMs ~= nil then
        nowMs = util.timestampMs()
    end

    -- 触觉轻震反馈
    if haptic ~= nil then
        pcall(function()
            haptic.light()
        end)
    end

    if lastTapMs > 0 then
        local delta = nowMs - lastTapMs
        if delta > 2500 then
            -- 停顿超过 2.5 秒，自动重新开始
            tapTimes = {}
        else
            table.insert(tapTimes, delta)
            if #tapTimes > 12 then
                table.remove(tapTimes, 1)
            end
        end
    end
    lastTapMs = nowMs

    local n = #tapTimes
    if n > 0 then
        local sum = 0
        local i = 1
        while i <= n do
            sum = sum + tapTimes[i]
            i = i + 1
        end
        local avgInterval = sum / n
        if avgInterval > 0 then
            local bpm = 60000.0 / avgInterval
            updateDisplays(bpm, n + 1)
        end
    else
        state.set("tapCount", 1)
        state.set("tapCountLabel", "已记录第 1 次敲击，请保持节奏连续敲击...")
    end
    return nil
end

function resetTempo()
    tapTimes = {}
    lastTapMs = 0
    currentBpm = 120.0
    onInit()
    dialog.toast("节拍器测速已重置")
    return nil
end

function copyBpm()
    local text = string.format("BPM 测速结果:\n速度: %s BPM\n音乐术语: %s\n估算心率区: %s\n%s",
        state.get("bpmDisplay") or "120.0",
        state.get("tempoTerm") or "",
        state.get("hrZone") or "",
        state.get("intervalMs") or "")
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("BPM 数据已复制")
    return nil
end

function simulateTaps(fixedBpm)
    local targetInterval = 60000.0 / (fixedBpm or 120.0)
    tapTimes = {targetInterval, targetInterval, targetInterval, targetInterval}
    updateDisplays(fixedBpm or 120.0, 5)
    return nil
end
