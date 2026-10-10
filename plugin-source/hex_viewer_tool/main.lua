-- 文件与文本 16 进制转储查看器

local bytesPerLine = 16

local function buildHexDump(text, perLine)
    local len = string.len(text)
    if len == 0 then
        return "", 0, 0, 0, 0
    end

    local lines = {}
    local offset = 0
    local printable = 0
    local nonPrintable = 0
    local nullBytes = 0

    while offset < len do
        local hexPart = ""
        local asciiPart = ""
        local i = 1
        while i <= perLine do
            local idx = offset + i
            if idx <= len then
                local b = string.byte(text, idx)
                if b == 0 then
                    nullBytes = nullBytes + 1
                end
                if b >= 32 and b <= 126 then
                    printable = printable + 1
                    asciiPart = asciiPart .. string.sub(text, idx, idx)
                else
                    nonPrintable = nonPrintable + 1
                    asciiPart = asciiPart .. "."
                end
                hexPart = hexPart .. string.format("%02X ", b)
            else
                hexPart = hexPart .. "   "
            end

            -- 中间留双空格分隔
            if perLine == 16 and i == 8 then
                hexPart = hexPart .. " "
            end
            i = i + 1
        end

        local line = string.format("%08X:  %s |%s|", offset, hexPart, asciiPart)
        table.insert(lines, line)
        offset = offset + perLine
    end

    local out = table.concat(lines, "\n")
    return out, len, printable, nonPrintable, nullBytes
end

function onInit()
    bytesPerLine = 16
    local defaultText = "Hello World!\nPluginToolbox PTX v1.0\r\n" .. string.char(0) .. "TestBinary"
    state.set("inputText", defaultText)
    state.set("perLineDesc", "每行 16 字节")

    generateDump()
    return nil
end

function generateDump()
    local text = state.get("inputText") or ""
    local dump, total, pr, npr, nulls = buildHexDump(text, bytesPerLine)

    state.set("hexDumpOutput", dump)
    state.set("statsText", string.format("总字节: %d B | 可打印: %d | 控制/不可见: %d | 空字节(0x00): %d", total, pr, npr, nulls))
    return nil
end

function setLineBytes(n)
    bytesPerLine = n or 16
    state.set("perLineDesc", string.format("每行 %d 字节", bytesPerLine))
    generateDump()
    dialog.toast(string.format("已切换为每行 %d 字节转储", bytesPerLine))
    return nil
end

function copyDump()
    local text = state.get("hexDumpOutput") or ""
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("十六进制转储已复制")
    return nil
end
