-- YAML ↔ JSON 极简轻量互转器

local function trim(s)
    local len = string.len(s)
    local startIdx = 1
    while startIdx <= len and (string.sub(s, startIdx, startIdx) == " " or string.sub(s, startIdx, startIdx) == "\t" or string.sub(s, startIdx, startIdx) == "\r") do
        startIdx = startIdx + 1
    end
    local endIdx = len
    while endIdx >= startIdx and (string.sub(s, endIdx, endIdx) == " " or string.sub(s, endIdx, endIdx) == "\t" or string.sub(s, endIdx, endIdx) == "\r") do
        endIdx = endIdx - 1
    end
    if startIdx > endIdx then
        return ""
    end
    return string.sub(s, startIdx, endIdx)
end

local function splitLines(text)
    local lines = {}
    local startPos = 1
    local len = string.len(text)
    while startPos <= len do
        local nl = string.find(text, "\n", startPos, true)
        if nl then
            table.insert(lines, string.sub(text, startPos, nl - 1))
            startPos = nl + 1
        else
            table.insert(lines, string.sub(text, startPos, len))
            break
        end
    end
    return lines
end

local function tableToYaml(val, indent)
    local indentSpaces = ""
    local i = 1
    while i <= indent do
        indentSpaces = indentSpaces .. " "
        i = i + 1
    end

    if type(val) ~= "table" then
        if type(val) == "string" then
            return val
        else
            return tostring(val)
        end
    end

    local isArray = (val[1] ~= nil)
    local out = ""
    if isArray then
        local idx = 1
        while val[idx] ~= nil do
            local item = val[idx]
            if type(item) == "table" then
                out = out .. indentSpaces .. "-\n" .. tableToYaml(item, indent + 2)
            else
                out = out .. indentSpaces .. "- " .. tostring(item) .. "\n"
            end
            idx = idx + 1
        end
    else
        for k, v in pairs(val) do
            if type(v) == "table" then
                out = out .. indentSpaces .. tostring(k) .. ":\n" .. tableToYaml(v, indent + 2)
            else
                out = out .. indentSpaces .. tostring(k) .. ": " .. tostring(v) .. "\n"
            end
        end
    end
    return out
end

local function parseYamlLineValue(valStr)
    valStr = trim(valStr)
    if valStr == "true" then return true end
    if valStr == "false" then return false end
    if valStr == "null" or valStr == "~" or valStr == "" then return nil end
    local num = tonumber(valStr)
    if num ~= nil then return num end
    -- 去除首尾引号
    local len = string.len(valStr)
    if len >= 2 then
        local first = string.sub(valStr, 1, 1)
        local last = string.sub(valStr, len, len)
        if (first == '"' and last == '"') or (first == "'" and last == "'") then
            return string.sub(valStr, 2, len - 1)
        end
    end
    return valStr
end

local function simpleYamlToTable(yamlStr)
    local lines = splitLines(yamlStr)
    local root = {}
    local stack = { { indent = -1, tbl = root } }

    local lineIdx = 1
    while lineIdx <= #lines do
        local rawLine = lines[lineIdx]
        local trimmed = trim(rawLine)
        if trimmed ~= "" and string.sub(trimmed, 1, 1) ~= "#" then
            -- 计算缩进
            local indent = 0
            while indent < string.len(rawLine) and string.sub(rawLine, indent + 1, indent + 1) == " " do
                indent = indent + 1
            end

            while #stack > 1 and stack[#stack].indent >= indent do
                table.remove(stack)
            end
            local curTbl = stack[#stack].tbl

            local colonPos = string.find(trimmed, ":", 1, true)
            if string.sub(trimmed, 1, 2) == "- " then
                -- 列表项
                local itemVal = trim(string.sub(trimmed, 3, string.len(trimmed)))
                table.insert(curTbl, parseYamlLineValue(itemVal))
            else
                if colonPos then
                    local k = trim(string.sub(trimmed, 1, colonPos - 1))
                    local v = trim(string.sub(trimmed, colonPos + 1, string.len(trimmed)))
                    if v == "" then
                        local newTbl = {}
                        curTbl[k] = newTbl
                        table.insert(stack, { indent = indent, tbl = newTbl })
                    else
                        curTbl[k] = parseYamlLineValue(v)
                    end
                else
                    curTbl[trimmed] = true
                end
            end
        end
        lineIdx = lineIdx + 1
    end
    return root
end

function onInit()
    local sampleYaml = "name: PluginToolbox\nversion: 1.0.0\nenabled: true\nport: 8080\nfeatures:\n  - sandbox\n  - dynamic_ui\n  - native_api\nauthor: Antigravity\n"
    state.set("inputContent", sampleYaml)
    state.set("outputContent", "点击下方「YAML 转 JSON」或「JSON 转 YAML」")
    state.set("statusMsg", "就绪：已载入 YAML 样例")
    return nil
end

function yamlToJson()
    local text = state.get("inputContent") or ""
    if trim(text) == "" then
        dialog.toast("请输入 YAML 文本内容")
        return nil
    end

    local ok, tbl = pcall(function()
        return simpleYamlToTable(text)
    end)

    if not ok or tbl == nil then
        state.set("statusMsg", "YAML 解析失败，请检查格式")
        dialog.toast("YAML 解析失败")
        return nil
    end

    local jsonOk, jsonText = pcall(function()
        return json.encode(tbl)
    end)

    if jsonOk and jsonText ~= nil then
        state.set("outputContent", jsonText)
        state.set("statusMsg", "YAML 成功转换为标准 JSON 格式")
        dialog.toast("转换完成")
    else
        state.set("statusMsg", "JSON 序列化失败")
        dialog.toast("转换错误")
    end
    return nil
end

function jsonToYaml()
    local text = state.get("inputContent") or ""
    if trim(text) == "" then
        dialog.toast("请输入 JSON 文本内容")
        return nil
    end

    local ok, tbl = pcall(function()
        return json.decode(text)
    end)

    if not ok or tbl == nil then
        state.set("statusMsg", "JSON 解析失败，请确保格式合法")
        dialog.toast("JSON 语法解析失败")
        return nil
    end

    local yamlOk, yamlText = pcall(function()
        return tableToYaml(tbl, 0)
    end)

    if yamlOk and yamlText ~= nil then
        state.set("outputContent", yamlText)
        state.set("statusMsg", "JSON 成功格式化为层级 YAML 结构")
        dialog.toast("转换完成")
    else
        state.set("statusMsg", "YAML 序列化失败")
        dialog.toast("转换错误")
    end
    return nil
end

function loadSample(kind)
    if kind == "docker" then
        local y = "version: '3.8'\nservices:\n  web:\n    image: nginx:alpine\n    ports:\n      - 80:80\n    restart: always\n"
        state.set("inputContent", y)
        state.set("statusMsg", "已载入 Docker Compose 配置文件样例")
    else
        local j = '{\n  "apiVersion": "v1",\n  "kind": "Pod",\n  "metadata": {\n    "name": "toolbox-pod"\n  },\n  "spec": {\n    "containers": [\n      {\n        "name": "worker",\n        "image": "busybox"\n      }\n    ]\n  }\n}'
        state.set("inputContent", j)
        state.set("statusMsg", "已载入 Kubernetes Pod JSON 样例")
    end
    dialog.toast("样例载入成功")
    return nil
end

function copyOutput()
    local text = state.get("outputContent") or ""
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("结果已复制到剪贴板")
    return nil
end
