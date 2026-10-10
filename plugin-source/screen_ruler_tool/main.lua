-- 物理屏幕高精度游标卡尺

local currentMm = 25.4
local calibFactor = 1.0
local zeroOffsetMm = 0.0

local function updateDisplays()
    local effMm = currentMm - zeroOffsetMm
    if effMm < 0 then
        effMm = 0
    end
    local effCm = effMm / 10.0
    local effInch = effMm / 25.4

    state.set("displayMm", string.format("%.2f mm", effMm))
    state.set("displayCm", string.format("%.3f cm", effCm))
    state.set("displayInch", string.format("%.3f in", effInch))
    state.set("rawMm", string.format("%.2f", effMm))

    -- 绘制字符刻度标尺
    local rulerTicks = ""
    local intMm = math.floor(effMm)
    local step = 5
    if intMm > 60 then
        step = 10
    end
    local i = 0
    while i <= intMm do
        if i % 10 == 0 then
            rulerTicks = rulerTicks .. "|" .. tostring(i) .. "cm|"
        else
            rulerTicks = rulerTicks .. ":"
        end
        i = i + step
    end
    state.set("rulerVisual", "|0|" .. rulerTicks .. "> (" .. string.format("%.1f", effMm) .. "mm)")
    return nil
end

function onInit()
    currentMm = 25.4
    calibFactor = 1.0
    zeroOffsetMm = 0.0

    local pr = 2.75
    if system ~= nil and system.pixelRatio ~= nil then
        local ok, res = pcall(function() return system.pixelRatio() end)
        if ok and res ~= nil and res > 0 then
            pr = res
        end
    end
    local dpi = pr * 160.0
    local pxMm = dpi / 25.4
    state.set("dpiInfo", string.format("屏幕像素比: %.2f | 估算 DPI: %.1f | 像素密度: %.2f px/mm", pr, dpi, pxMm))
    state.set("calibDesc", "基准倍率 1.000")
    state.set("hasCalibrated", false)

    updateDisplays()
    return nil
end

function adjustMm(delta)
    currentMm = currentMm + delta
    if currentMm < 0 then
        currentMm = 0
    end
    if currentMm > 250 then
        currentMm = 250
    end
    updateDisplays()
    return nil
end

function setPreset(kind)
    if kind == "coin" then
        currentMm = 25.0 -- 1元硬币直径 25mm
        state.set("calibDesc", "标准件：新版1元硬币 (25.0mm)")
    else
        if kind == "card_w" then
            currentMm = 53.98 -- 银行卡宽度
            state.set("calibDesc", "标准件：标准卡片宽 (54.0mm)")
        else
            if kind == "card_l" then
                currentMm = 85.60 -- 银行卡长度
                state.set("calibDesc", "标准件：标准卡片长 (85.6mm)")
            else
                currentMm = 12.30 -- Nano-SIM 长度
                state.set("calibDesc", "标准件：Nano-SIM 卡 (12.3mm)")
            end
        end
    end
    updateDisplays()
    dialog.toast("已载入参考标准件尺寸")
    return nil
end

function zeroCalibrate()
    zeroOffsetMm = currentMm
    state.set("hasCalibrated", true)
    state.set("calibDesc", string.format("已设为相对零点 (偏置 %.2f mm)", zeroOffsetMm))
    updateDisplays()
    dialog.toast("当前游标位置已校准归零")
    return nil
end

function resetCalibrate()
    zeroOffsetMm = 0.0
    state.set("hasCalibrated", false)
    state.set("calibDesc", "已恢复绝对零点")
    updateDisplays()
    dialog.toast("已重置归零偏置")
    return nil
end

function copyMeasurement()
    local text = string.format("屏幕卡尺测量结果:\n毫米: %s\n厘米: %s\n英寸: %s",
        state.get("displayMm") or "",
        state.get("displayCm") or "",
        state.get("displayInch") or "")
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("测量尺寸已复制到剪贴板")
    return nil
end
