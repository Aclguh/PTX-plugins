-- 嵌入式单片机点阵字模取模助手

local mode = "vertical" -- "horizontal" or "vertical" (SSD1306)
local isInverted = false

local font8x8_h = {
    ["0"] = {60, 66, 66, 66, 66, 66, 60, 0},
    ["1"] = {8, 24, 8, 8, 8, 8, 28, 0},
    ["2"] = {60, 66, 2, 28, 96, 64, 126, 0},
    ["3"] = {60, 66, 2, 28, 2, 66, 60, 0},
    ["4"] = {68, 68, 68, 126, 4, 4, 4, 0},
    ["5"] = {126, 64, 124, 2, 2, 66, 60, 0},
    ["A"] = {24, 36, 66, 126, 66, 66, 66, 0},
    ["B"] = {124, 66, 66, 124, 66, 66, 124, 0},
    ["C"] = {60, 66, 64, 64, 64, 66, 60, 0},
    ["P"] = {124, 66, 66, 124, 64, 64, 64, 0},
    ["T"] = {126, 24, 24, 24, 24, 24, 24, 0},
    ["X"] = {66, 66, 36, 24, 36, 66, 66, 0},
    [" "] = {0, 0, 0, 0, 0, 0, 0, 0},
    [":"] = {0, 24, 24, 0, 24, 24, 0, 0}
}

local function getCharRows(ch)
    local upper = string.upper(ch)
    local rows = font8x8_h[upper]
    if rows ~= nil then
        return rows
    end
    -- 默认方框图案
    return {126, 66, 66, 66, 66, 66, 126, 0}
end

local function rowsToCols(rows)
    local cols = {0, 0, 0, 0, 0, 0, 0, 0}
    local colIdx = 1
    while colIdx <= 8 do
        local bitMask = 2 ^ (8 - colIdx)
        local val = 0
        local rIdx = 1
        while rIdx <= 8 do
            local rowVal = rows[rIdx]
            if (rowVal % (bitMask * 2)) >= bitMask then
                val = val + 2 ^ (rIdx - 1)
            end
            rIdx = rIdx + 1
        end
        cols[colIdx] = val
        colIdx = colIdx + 1
    end
    return cols
end

function onInit()
    mode = "vertical"
    isInverted = false
    state.set("inputText", "PTX")
    state.set("modeDesc", "逐列取模 (SSD1306 列优先)")
    state.set("invertDesc", "正常 (无反色)")

    generateFont()
    return nil
end

function generateFont()
    local text = state.get("inputText") or "PTX"
    if string.len(text) == 0 then
        text = "P"
    end

    local codeBytes = {}
    local asciiPreviewLines = {"", "", "", "", "", "", "", ""}

    local i = 1
    while i <= string.len(text) do
        local ch = string.sub(text, i, i)
        local rows = getCharRows(ch)

        -- 渲染 ASCII 点阵
        local r = 1
        while r <= 8 do
            local rVal = rows[r]
            local lineStr = ""
            local c = 1
            while c <= 8 do
                local bitVal = math.floor(rVal / (2 ^ (8 - c))) % 2
                if isInverted then
                    bitVal = (bitVal == 1) and 0 or 1
                end
                lineStr = lineStr .. (bitVal == 1 and "█" or "░")
                c = c + 1
            end
            asciiPreviewLines[r] = asciiPreviewLines[r] .. lineStr .. " "
            r = r + 1
        end

        -- 生成字节
        local targetBytes = rows
        if mode == "vertical" then
            targetBytes = rowsToCols(rows)
        end

        local bIdx = 1
        while bIdx <= 8 do
            local b = targetBytes[bIdx]
            if isInverted then
                b = 255 - b
            end
            table.insert(codeBytes, string.format("0x%02X", b))
            bIdx = bIdx + 1
        end

        i = i + 1
    end

    local previewStr = table.concat(asciiPreviewLines, "\n")
    local cCode = string.format("// 8x8 字模数组 (%s, %s)\nconst uint8_t font8x8[] = {\n  %s\n};",
        mode == "vertical" and "逐列取模" or "逐行取模",
        isInverted and "反色" or "正常",
        table.concat(codeBytes, ", "))

    state.set("asciiVisual", previewStr)
    state.set("cCodeOutput", cCode)
    state.set("byteCountLabel", string.format("包含 %d 个字符，共生成 %d 字节字模", string.len(text), #codeBytes))
    return nil
end

function toggleMode()
    if mode == "vertical" then
        mode = "horizontal"
        state.set("modeDesc", "逐行取模 (行优先)")
    else
        mode = "vertical"
        state.set("modeDesc", "逐列取模 (SSD1306 列优先)")
    end
    generateFont()
    dialog.toast("已切换取模方式: " .. state.get("modeDesc"))
    return nil
end

function toggleInvert()
    isInverted = not isInverted
    state.set("invertDesc", isInverted and "已反色 (前景背景反转)" or "正常 (无反色)")
    generateFont()
    dialog.toast(state.get("invertDesc"))
    return nil
end

function copyCode()
    local text = state.get("cCodeOutput") or ""
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("C 语言字模数组已复制")
    return nil
end
