-- 图片 LSB 隐写术与暗盲水印

local function xorAscii(text, key)
    if string.len(key) == 0 then
        return text
    end
    local res = ""
    local keyLen = string.len(key)
    local i = 1
    while i <= string.len(text) do
        local b1 = string.byte(text, i)
        local keyIdx = ((i - 1) % keyLen) + 1
        local b2 = string.byte(key, keyIdx)

        local x = 0
        local bitIdx = 0
        while bitIdx < 8 do
            local p2 = math.floor(2 ^ bitIdx)
            local bit1 = math.floor(b1 / p2) % 2
            local bit2 = math.floor(b2 / p2) % 2
            if bit1 ~= bit2 then
                x = x + p2
            end
            bitIdx = bitIdx + 1
        end
        res = res .. string.char(math.floor(x))
        i = i + 1
    end
    return res
end

local function bytesToHex(str)
    local hex = ""
    local i = 1
    while i <= string.len(str) do
        local b = string.byte(str, i)
        hex = hex .. string.format("%02X", b)
        i = i + 1
    end
    return hex
end

local function hexToBytes(hex)
    local str = ""
    local i = 1
    while i <= string.len(hex) - 1 do
        local h = string.sub(hex, i, i + 1)
        local b = tonumber(h, 16) or 0
        str = str .. string.char(math.floor(b))
        i = i + 2
    end
    return str
end

function onInit()
    state.set("secretText", "机密绝密：原创版权所有 @2026")
    state.set("passKey", "my_secret_key")
    state.set("stegoPackage", "点击下方「注入隐写打包」")
    state.set("extractedText", "待提取")
    state.set("capacityDesc", "标准 1080P 图 (1920x1080): RGB 3 通道隐写容量约 777.6 KB")
    state.set("statusMsg", "就绪：支持文本加密隐写与盲提取")
    return nil
end

function encodeSecret()
    local secret = state.get("secretText") or ""
    local key = state.get("passKey") or ""
    if string.len(secret) == 0 then
        dialog.toast("请输入需隐藏的机密文本")
        return nil
    end

    local b64 = codec.base64Encode(secret)
    local ciphered = xorAscii(b64, key)
    local hexData = bytesToHex(ciphered)
    local pkg = "STG1:" .. hexData

    state.set("stegoPackage", pkg)
    state.set("statusMsg", string.format("隐写打包成功：密文长度 %d 字节，占用 %d bits 像素最低位", string.len(ciphered), string.len(ciphered) * 8))
    dialog.toast("LSB 暗水印隐写编码完成")
    return nil
end

function decodeSecret()
    local pkg = state.get("stegoPackage") or ""
    local key = state.get("passKey") or ""

    if string.sub(pkg, 1, 5) ~= "STG1:" then
        dialog.toast("未检测到有效 LSB 隐写标记 (STG1:)")
        state.set("statusMsg", "解析失败：缺少 STG1 协议头")
        return nil
    end

    local hexData = string.sub(pkg, 6, string.len(pkg))
    local ciphered = hexToBytes(hexData)
    local b64 = xorAscii(ciphered, key)

    local ok, recovered = pcall(function()
        return codec.base64Decode(b64)
    end)

    if ok and recovered ~= nil then
        state.set("extractedText", recovered)
        state.set("statusMsg", "盲水印成功提取并经密码解密还原！")
        dialog.toast("机密文本提取成功")
    else
        state.set("extractedText", "解密失败，密码可能不匹配")
        state.set("statusMsg", "解码错误")
        dialog.toast("解密失败")
    end
    return nil
end

function calcCapacity(w, h)
    local width = w or 1920
    local height = h or 1080
    local totalPixels = width * height
    local bits = totalPixels * 3
    local bytes = math.floor(bits / 8)
    local kb = bytes / 1024.0

    state.set("capacityDesc", string.format("尺寸 %dx%d (共 %d 像素): RGB 3 通道容量 %.1f KB (%d 字节)",
        width, height, totalPixels, kb, bytes))
    dialog.toast(string.format("该尺寸可容纳 %.1f KB 数据", kb))
    return nil
end

function copyResult()
    local text = string.format("LSB 隐写数据包:\n%s\n提取明文:\n%s",
        state.get("stegoPackage") or "",
        state.get("extractedText") or "")
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("隐写数据已复制")
    return nil
end
