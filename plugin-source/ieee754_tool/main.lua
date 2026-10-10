-- IEEE 754 浮点数二进制剖析器

local function intToBinStr(val, bits)
    local s = ""
    local i = bits - 1
    while i >= 0 do
        local p = math.floor(2 ^ i)
        if val >= p then
            s = s .. "1"
            val = val - p
        else
            s = s .. "0"
        end
        i = i - 1
    end
    return s
end

local function binStrToHexStr(b)
    local hexMap = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"}
    local hex = ""
    local i = 1
    while i <= string.len(b) do
        local nibble = string.sub(b, i, i + 3)
        local n = 0
        local j = 1
        while j <= string.len(nibble) do
            local ch = string.sub(nibble, j, j)
            n = n * 2 + (ch == "1" and 1 or 0)
            j = j + 1
        end
        hex = hex .. hexMap[n + 1]
        i = i + 4
    end
    return hex
end

local function parseSingle(val)
    local sign = 0
    if val < 0 then
        sign = 1
        val = -val
    end

    local expField = 0
    local fracField = 0
    local expUnbiased = 0
    local significandStr = "1.0000000"

    if val == 0 then
        expField = 0
        fracField = 0
        expUnbiased = 0
        significandStr = "0.0000000"
    else
        local e = math.floor(math.log(val) / math.log(2.0))
        local scaled = val / (2.0 ^ e)
        if scaled >= 2.0 then
            e = e + 1
            scaled = scaled / 2.0
        else
            if scaled < 1.0 then
                e = e - 1
                scaled = scaled * 2.0
            end
        end

        local biasedE = e + 127
        if biasedE >= 255 then
            expField = 255
            fracField = 0
            expUnbiased = 128
            significandStr = "Infinity"
        else
            if biasedE <= 0 then
                expField = 0
                fracField = math.floor(val / (2.0 ^ -126) * 8388608.0 + 0.5)
                expUnbiased = -126
                significandStr = "0 (次正规数)"
            else
                expField = biasedE
                expUnbiased = e
                local fracPart = scaled - 1.0
                fracField = math.floor(fracPart * 8388608.0 + 0.5)
                if fracField >= 8388608 then
                    fracField = 0
                    expField = expField + 1
                    expUnbiased = expUnbiased + 1
                end
                significandStr = string.format("1 + %d/8388608 ≈ %.7f", fracField, 1.0 + fracField / 8388608.0)
            end
        end
    end

    local signBin = tostring(sign)
    local expBin = intToBinStr(expField, 8)
    local fracBin = intToBinStr(fracField, 23)
    local allBin = signBin .. expBin .. fracBin
    local hexVal = binStrToHexStr(allBin)

    state.set("hexDisplay", "0x" .. hexVal)
    state.set("binFull", signBin .. " " .. expBin .. " " .. fracBin)
    state.set("signBitDesc", string.format("符号位 S = %s (%s)", signBin, sign == 0 and "正数 +" or "负数 -"))
    state.set("expDesc", string.format("阶码 E = %s (%d - 127 = %d)", expBin, expField, expUnbiased))
    state.set("fracDesc", string.format("尾数 M = %s (%s)", fracBin, significandStr))

    local trapNote = "普通浮点值"
    if val == 0.1 then
        trapNote = "注意: 0.1 无法用有限二进制精确表示，尾数无限循环截断产生微小误差 (0.10000000149...)"
    else
        if val == 0.2 then
            trapNote = "注意: 0.2 同样存在尾数截断误差，0.1 + 0.2 累加后导致 != 0.3"
        else
            if val == 0.3 then
                trapNote = "注意: 0.3 的位模式与 (0.1+0.2) 略有偏差，因而 0.1 + 0.2 ~= 0.3"
            end
        end
    end
    state.set("trapNote", trapNote)
    return nil
end

function onInit()
    state.set("inputFloat", "0.1")
    parseSingle(0.1)
    return nil
end

function calculateFloat()
    local s = state.get("inputFloat") or "0.1"
    local v = tonumber(s)
    if v == nil then
        dialog.toast("请输入有效数值 (如 0.1, -12.5, 3.14)")
        return nil
    end
    parseSingle(v)
    dialog.toast("位模式剖析完成")
    return nil
end

function setPreset(val)
    state.set("inputFloat", tostring(val))
    parseSingle(val)
    dialog.toast("已载入数值: " .. tostring(val))
    return nil
end

function copyResult()
    local text = string.format("IEEE 754 (32-bit 单精度) 剖析:\n数值: %s\n十六进制: %s\n二进制: %s\n%s\n%s\n%s\n%s",
        state.get("inputFloat") or "",
        state.get("hexDisplay") or "",
        state.get("binFull") or "",
        state.get("signBitDesc") or "",
        state.get("expDesc") or "",
        state.get("fracDesc") or "",
        state.get("trapNote") or "")
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("二进制位模式已复制")
    return nil
end
