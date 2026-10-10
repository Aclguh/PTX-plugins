-- SemVer 语义化版本比对与演算

local function trim(s)
    local len = string.len(s)
    local startIdx = 1
    while startIdx <= len and (string.sub(s, startIdx, startIdx) == " " or string.sub(s, startIdx, startIdx) == "\t") do
        startIdx = startIdx + 1
    end
    local endIdx = len
    while endIdx >= startIdx and (string.sub(s, endIdx, endIdx) == " " or string.sub(s, endIdx, endIdx) == "\t") do
        endIdx = endIdx - 1
    end
    if startIdx > endIdx then
        return ""
    end
    return string.sub(s, startIdx, endIdx)
end

local function parseSemver(str)
    str = trim(str)
    if string.sub(str, 1, 1) == "v" or string.sub(str, 1, 1) == "V" then
        str = string.sub(str, 2, string.len(str))
    end

    local build = ""
    local plusPos = string.find(str, "+", 1, true)
    if plusPos then
        build = string.sub(str, plusPos + 1, string.len(str))
        str = string.sub(str, 1, plusPos - 1)
    end

    local prerelease = ""
    local dashPos = string.find(str, "-", 1, true)
    if dashPos then
        prerelease = string.sub(str, dashPos + 1, string.len(str))
        str = string.sub(str, 1, dashPos - 1)
    end

    local dot1 = string.find(str, ".", 1, true)
    local major = 0
    local minor = 0
    local patch = 0

    if dot1 then
        major = tonumber(string.sub(str, 1, dot1 - 1)) or 0
        local rest = string.sub(str, dot1 + 1, string.len(str))
        local dot2 = string.find(rest, ".", 1, true)
        if dot2 then
            minor = tonumber(string.sub(rest, 1, dot2 - 1)) or 0
            patch = tonumber(string.sub(rest, dot2 + 1, string.len(rest))) or 0
        else
            minor = tonumber(rest) or 0
            patch = 0
        end
    else
        major = tonumber(str) or 0
    end

    return {
        major = major,
        minor = minor,
        patch = patch,
        prerelease = prerelease,
        build = build,
        raw = string.format("%d.%d.%d%s%s", major, minor, patch,
            prerelease ~= "" and ("-" .. prerelease) or "",
            build ~= "" and ("+" .. build) or "")
    }
end

local function compareSemver(v1, v2)
    if v1.major > v2.major then return 1 end
    if v1.major < v2.major then return -1 end
    if v1.minor > v2.minor then return 1 end
    if v1.minor < v2.minor then return -1 end
    if v1.patch > v2.patch then return 1 end
    if v1.patch < v2.patch then return -1 end

    -- 预发布版本比正式版小 (1.0.0-alpha < 1.0.0)
    if v1.prerelease == "" and v2.prerelease ~= "" then return 1 end
    if v1.prerelease ~= "" and v2.prerelease == "" then return -1 end
    if v1.prerelease > v2.prerelease then return 1 end
    if v1.prerelease < v2.prerelease then return -1 end

    return 0
end

local function satisfiesCaret(target, base)
    local minVer = base
    local maxVer = { major = base.major + 1, minor = 0, patch = 0, prerelease = "", build = "" }
    if base.major == 0 then
        if base.minor > 0 then
            maxVer = { major = 0, minor = base.minor + 1, patch = 0, prerelease = "", build = "" }
        else
            maxVer = { major = 0, minor = 0, patch = base.patch + 1, prerelease = "", build = "" }
        end
    end
    local geMin = compareSemver(target, minVer) >= 0
    local ltMax = compareSemver(target, maxVer) < 0
    return geMin and ltMax, string.format(">= %s < %d.%d.%d", minVer.raw, maxVer.major, maxVer.minor, maxVer.patch)
end

local function satisfiesTilde(target, base)
    local minVer = base
    local maxVer = { major = base.major, minor = base.minor + 1, patch = 0, prerelease = "", build = "" }
    local geMin = compareSemver(target, minVer) >= 0
    local ltMax = compareSemver(target, maxVer) < 0
    return geMin and ltMax, string.format(">= %s < %d.%d.0", minVer.raw, maxVer.major, maxVer.minor)
end

function onInit()
    state.set("versionA", "1.2.3")
    state.set("versionB", "1.3.0-rc.1")
    state.set("rangeExpr", "^1.2.0")
    state.set("cmpResult", "版本 A 与 B 比较结果")
    state.set("rangeResult", "范围区间兼容性判定结果")
    state.set("bumpNext", "主版本: 2.0.0 | 次版本: 1.3.0 | 修订号: 1.2.4")

    runAnalysis()
    return nil
end

function runAnalysis()
    local sA = state.get("versionA") or "1.2.3"
    local sB = state.get("versionB") or "1.3.0"
    local range = trim(state.get("rangeExpr") or "^1.2.0")

    local vA = parseSemver(sA)
    local vB = parseSemver(sB)

    local cmp = compareSemver(vA, vB)
    local rel = "=="
    if cmp > 0 then rel = "> (A 大于 B)"
    elseif cmp < 0 then rel = "< (A 小于 B)"
    else rel = "== (版本完全相同)"
    end
    state.set("cmpResult", string.format("比对结果: %s %s %s", vA.raw, rel, vB.raw))

    -- 区间匹配
    if string.sub(range, 1, 1) == "^" then
        local base = parseSemver(string.sub(range, 2, string.len(range)))
        local ok, expDesc = satisfiesCaret(vA, base)
        state.set("rangeResult", string.format("区间 %s (%s): %s %s", range, expDesc, vA.raw, ok and "✓ 兼容匹配" or "✗ 不匹配"))
    else
        if string.sub(range, 1, 1) == "~" then
            local base = parseSemver(string.sub(range, 2, string.len(range)))
            local ok, expDesc = satisfiesTilde(vA, base)
            state.set("rangeResult", string.format("区间 %s (%s): %s %s", range, expDesc, vA.raw, ok and "✓ 兼容匹配" or "✗ 不匹配"))
        else
            state.set("rangeResult", string.format("支持前缀 ^ 或 ~ (如 ^1.2.0 或 ~1.2.0)"))
        end
    end

    -- 下一版本演算 (基于 A)
    state.set("bumpNext", string.format("Bump Major: %d.0.0 | Bump Minor: %d.%d.0 | Bump Patch: %d.%d.%d",
        vA.major + 1, vA.major, vA.minor + 1, vA.major, vA.minor, vA.patch + 1))
    return nil
end

function bumpA(kind)
    local sA = state.get("versionA") or "1.2.3"
    local vA = parseSemver(sA)
    local nextVer = ""
    if kind == "major" then
        nextVer = string.format("%d.0.0", vA.major + 1)
    else
        if kind == "minor" then
            nextVer = string.format("%d.%d.0", vA.major, vA.minor + 1)
        else
            if kind == "patch" then
                nextVer = string.format("%d.%d.%d", vA.major, vA.minor, vA.patch + 1)
            else
                nextVer = string.format("%d.%d.%d-beta.1", vA.major, vA.minor, vA.patch)
            end
        end
    end
    state.set("versionA", nextVer)
    runAnalysis()
    dialog.toast("已跃迁版本 A 至: " .. nextVer)
    return nil
end

function copyResult()
    local text = string.format("SemVer 演算结果:\n版本 A: %s\n版本 B: %s\n%s\n%s\n%s",
        state.get("versionA") or "",
        state.get("versionB") or "",
        state.get("cmpResult") or "",
        state.get("rangeResult") or "",
        state.get("bumpNext") or "")
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("SemVer 结果已复制")
    return nil
end
