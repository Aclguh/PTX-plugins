-- Linux Chmod 权限与掩码换算

local perms = {
    ur = true, uw = true, ux = true,
    gr = true, gw = false, gx = true,
    or_ = true, ow = false, ox = true
}

local function calcPerms()
    local u = (perms.ur and 4 or 0) + (perms.uw and 2 or 0) + (perms.ux and 1 or 0)
    local g = (perms.gr and 4 or 0) + (perms.gw and 2 or 0) + (perms.gx and 1 or 0)
    local o = (perms.or_ and 4 or 0) + (perms.ow and 2 or 0) + (perms.ox and 1 or 0)
    local octalStr = string.format("%d%d%d", u, g, o)

    local symStr = "-"
    symStr = symStr .. (perms.ur and "r" or "-")
    symStr = symStr .. (perms.uw and "w" or "-")
    symStr = symStr .. (perms.ux and "x" or "-")
    symStr = symStr .. (perms.gr and "r" or "-")
    symStr = symStr .. (perms.gw and "w" or "-")
    symStr = symStr .. (perms.gx and "x" or "-")
    symStr = symStr .. (perms.or_ and "r" or "-")
    symStr = symStr .. (perms.ow and "w" or "-")
    symStr = symStr .. (perms.ox and "x" or "-")

    local uStr = (perms.ur and "r" or "") .. (perms.uw and "w" or "") .. (perms.ux and "x" or "")
    local gStr = (perms.gr and "r" or "") .. (perms.gw and "w" or "") .. (perms.gx and "x" or "")
    local oStr = (perms.or_ and "r" or "") .. (perms.ow and "w" or "") .. (perms.ox and "x" or "")
    local ugoStr = string.format("u=%s,g=%s,o=%s", uStr, gStr, oStr)

    state.set("octalValue", octalStr)
    state.set("symbolicValue", symStr)
    state.set("ugoValue", ugoStr)
    state.set("cmdValue", "chmod " .. octalStr .. " <file>")

    -- 更新标签
    state.set("labelUR", perms.ur and "[X] 读 r" or "[ ] 读 r")
    state.set("labelUW", perms.uw and "[X] 写 w" or "[ ] 写 w")
    state.set("labelUX", perms.ux and "[X] 执 x" or "[ ] 执 x")
    state.set("labelGR", perms.gr and "[X] 读 r" or "[ ] 读 r")
    state.set("labelGW", perms.gw and "[X] 写 w" or "[ ] 写 w")
    state.set("labelGX", perms.gx and "[X] 执 x" or "[ ] 执 x")
    state.set("labelOR", perms.or_ and "[X] 读 r" or "[ ] 读 r")
    state.set("labelOW", perms.ow and "[X] 写 w" or "[ ] 写 w")
    state.set("labelOX", perms.ox and "[X] 执 x" or "[ ] 执 x")
    return nil
end

function onInit()
    perms.ur = true
    perms.uw = true
    perms.ux = true
    perms.gr = true
    perms.gw = false
    perms.gx = true
    perms.or_ = true
    perms.ow = false
    perms.ox = true

    state.set("inputOctal", "755")
    calcPerms()
    return nil
end

function toggleBit(key)
    if key == "ur" then perms.ur = not perms.ur
    elseif key == "uw" then perms.uw = not perms.uw
    elseif key == "ux" then perms.ux = not perms.ux
    elseif key == "gr" then perms.gr = not perms.gr
    elseif key == "gw" then perms.gw = not perms.gw
    elseif key == "gx" then perms.gx = not perms.gx
    elseif key == "or" then perms.or_ = not perms.or_
    elseif key == "ow" then perms.ow = not perms.ow
    elseif key == "ox" then perms.ox = not perms.ox
    end
    calcPerms()
    return nil
end

local function parseDigit(d)
    local n = tonumber(d) or 0
    local r = (n >= 4)
    if r then n = n - 4 end
    local w = (n >= 2)
    if w then n = n - 2 end
    local x = (n >= 1)
    return r, w, x
end

function parseOctalInput()
    local s = state.get("inputOctal") or ""
    if string.len(s) >= 3 then
        local c1 = string.sub(s, 1, 1)
        local c2 = string.sub(s, 2, 2)
        local c3 = string.sub(s, 3, 3)
        perms.ur, perms.uw, perms.ux = parseDigit(c1)
        perms.gr, perms.gw, perms.gx = parseDigit(c2)
        perms.or_, perms.ow, perms.ox = parseDigit(c3)
        calcPerms()
        dialog.toast("已根据八进制反向解析勾选状态")
    else
        dialog.toast("请输入完整 3 位八进制数值（如 755）")
    end
    return nil
end

function setPreset(code)
    state.set("inputOctal", code)
    local c1 = string.sub(code, 1, 1)
    local c2 = string.sub(code, 2, 2)
    local c3 = string.sub(code, 3, 3)
    perms.ur, perms.uw, perms.ux = parseDigit(c1)
    perms.gr, perms.gw, perms.gx = parseDigit(c2)
    perms.or_, perms.ow, perms.ox = parseDigit(c3)
    calcPerms()
    dialog.toast("已应用预设: " .. code)
    return nil
end

function copyCommand()
    local cmd = state.get("cmdValue") or "chmod 755 <file>"
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(cmd)
        end)
    end
    dialog.toast("命令已复制: " .. cmd)
    return nil
end
