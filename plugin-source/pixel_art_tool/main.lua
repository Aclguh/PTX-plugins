-- 像素画画板与点阵图标设计

local gridRows = {
    {0,1,1,0,0,1,1,0},
    {1,1,1,1,1,1,1,1},
    {1,1,1,1,1,1,1,1},
    {1,1,1,1,1,1,1,1},
    {0,1,1,1,1,1,1,0},
    {0,0,1,1,1,1,0,0},
    {0,0,0,1,1,0,0,0},
    {0,0,0,0,0,0,0,0}
}

local presets = {
    heart = {
        {0,1,1,0,0,1,1,0},
        {1,1,1,1,1,1,1,1},
        {1,1,1,1,1,1,1,1},
        {1,1,1,1,1,1,1,1},
        {0,1,1,1,1,1,1,0},
        {0,0,1,1,1,1,0,0},
        {0,0,0,1,1,0,0,0},
        {0,0,0,0,0,0,0,0}
    },
    smile = {
        {0,0,1,1,1,1,0,0},
        {0,1,0,0,0,0,1,0},
        {1,0,1,0,0,1,0,1},
        {1,0,0,0,0,0,0,1},
        {1,0,1,0,0,1,0,1},
        {1,0,0,1,1,0,0,1},
        {0,1,0,0,0,0,1,0},
        {0,0,1,1,1,1,0,0}
    },
    ghost = {
        {0,0,1,1,1,1,0,0},
        {0,1,1,1,1,1,1,0},
        {1,1,0,1,1,0,1,1},
        {1,1,0,1,1,0,1,1},
        {1,1,1,1,1,1,1,1},
        {1,1,1,1,1,1,1,1},
        {1,0,1,1,0,1,1,0},
        {1,0,0,1,0,0,1,0}
    },
    sword = {
        {0,0,0,0,0,0,1,1},
        {0,0,0,0,0,1,1,0},
        {0,0,0,0,1,1,0,0},
        {0,0,0,1,1,0,0,0},
        {0,1,1,1,0,0,0,0},
        {1,1,1,0,0,0,0,0},
        {0,1,0,0,0,0,0,0},
        {1,0,0,0,0,0,0,0}
    }
}

local function renderArt()
    local asciiLines = {}
    local byteList = {}
    local r = 1
    while r <= 8 do
        local line = ""
        local bVal = 0
        local c = 1
        while c <= 8 do
            local val = gridRows[r][c]
            line = line .. (val == 1 and "■ " or "□ ")
            bVal = bVal * 2 + val
            c = c + 1
        end
        table.insert(asciiLines, line)
        table.insert(byteList, string.format("0x%02X", bVal))
        r = r + 1
    end

    local asciiStr = table.concat(asciiLines, "\n")
    local cCode = "const uint8_t sprite8x8[] = { " .. table.concat(byteList, ", ") .. " };"

    state.set("asciiVisual", asciiStr)
    state.set("cCodeDisplay", cCode)
    return nil
end

function onInit()
    gridRows = presets.heart
    state.set("presetTitle", "当前图案: 爱心 (Heart)")
    renderArt()
    return nil
end

function loadPreset(name)
    local p = presets[name]
    if p ~= nil then
        gridRows = p
        state.set("presetTitle", "当前图案: " .. name)
        renderArt()
        dialog.toast("已载入预设: " .. name)
    end
    return nil
end

function invertArt()
    local r = 1
    while r <= 8 do
        local c = 1
        while c <= 8 do
            gridRows[r][c] = (gridRows[r][c] == 1) and 0 or 1
            c = c + 1
        end
        r = r + 1
    end
    renderArt()
    dialog.toast("像素画布已反转色彩")
    return nil
end

function clearArt()
    local r = 1
    while r <= 8 do
        local c = 1
        while c <= 8 do
            gridRows[r][c] = 0
            c = c + 1
        end
        r = r + 1
    end
    renderArt()
    dialog.toast("像素画布已清空")
    return nil
end

function copyArt(kind)
    local text = ""
    if kind == "c" then
        text = state.get("cCodeDisplay") or ""
    else
        text = state.get("asciiVisual") or ""
    end
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("像素数据已复制")
    return nil
end
