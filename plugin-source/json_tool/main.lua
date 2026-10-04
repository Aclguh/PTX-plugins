-- json_tool — JSON 格式化 / 压缩 / 校验
-- 单趟流式处理: 边严格校验边输出, 保留原始键序; 错误带行列号
-- 沙箱无模式匹配可用, 全部判断基于 string.byte 码点

local INPUT_MAX = 200000
local DEPTH_MAX = 128

local function process(text, indentWidth)
  local len = string.len(text)
  local pos = 1
  local line, col = 1, 0
  local out = {}
  local stats = { nodes = 0, maxDepth = 0, rootType = nil }
  local indentStr = indentWidth > 0 and string.rep(" ", indentWidth) or ""

  local function advance()
    local c = string.sub(text, pos, pos)
    if c == "\n" then
      line = line + 1
      col = 0
    else
      col = col + 1
    end
    pos = pos + 1
  end

  local function fail(msg)
    error({ msg = msg, line = line, col = col }, 0)
  end

  local function skipWs()
    while pos <= len do
      local b = string.byte(text, pos)
      if b == 32 or b == 9 or b == 10 or b == 13 then
        advance()
      else
        break
      end
    end
  end

  local function write(s)
    out[#out + 1] = s
  end

  local function writeBreak(level)
    if indentWidth > 0 then
      write("\n")
      write(string.rep(indentStr, level))
    end
  end

  local function isHexDigit(b)
    return (b >= 48 and b <= 57) or (b >= 65 and b <= 70) or (b >= 97 and b <= 102)
  end

  local function parseString()
    local startPos = pos
    advance() -- 开引号
    while true do
      if pos > len then fail("字符串未闭合") end
      local b = string.byte(text, pos)
      if b == 34 then -- "
        advance()
        break
      elseif b == 92 then -- 反斜杠
        advance()
        if pos > len then fail("字符串未闭合") end
        local e = string.byte(text, pos)
        if e == 117 then -- u
          advance()
          for _ = 1, 4 do
            if pos > len then fail("\\u 转义缺少 4 位十六进制") end
            if not isHexDigit(string.byte(text, pos)) then
              fail("\\u 转义含非法十六进制字符")
            end
            advance()
          end
        elseif e == 34 or e == 92 or e == 47 or e == 98 or e == 102 or e == 110 or e == 114 or e == 116 then
          advance()
        else
          fail("非法转义字符")
        end
      elseif b == 10 then
        fail("字符串内不允许裸换行")
      elseif b < 32 then
        fail("字符串内含未转义控制字符")
      else
        advance()
      end
    end
    write(string.sub(text, startPos, pos - 1))
    stats.nodes = stats.nodes + 1
  end

  local function parseNumber()
    local startPos = pos
    if string.byte(text, pos) == 45 then advance() end -- '-'
    local b = string.byte(text, pos)
    if b == 48 then
      advance()
    elseif b ~= nil and b >= 49 and b <= 57 then
      while pos <= len do
        b = string.byte(text, pos)
        if b >= 48 and b <= 57 then advance() else break end
      end
    else
      fail("非法数字")
    end
    if string.byte(text, pos) == 46 then -- '.'
      advance()
      local digits = 0
      while pos <= len do
        b = string.byte(text, pos)
        if b >= 48 and b <= 57 then
          advance()
          digits = digits + 1
        else
          break
        end
      end
      if digits == 0 then fail("小数点后缺少数字") end
    end
    b = string.byte(text, pos)
    if b == 101 or b == 69 then -- e / E
      advance()
      b = string.byte(text, pos)
      if b == 43 or b == 45 then advance() end
      local digits = 0
      while pos <= len do
        b = string.byte(text, pos)
        if b >= 48 and b <= 57 then
          advance()
          digits = digits + 1
        else
          break
        end
      end
      if digits == 0 then fail("指数部分缺少数字") end
    end
    write(string.sub(text, startPos, pos - 1))
    stats.nodes = stats.nodes + 1
  end

  local function parseLiteral(word, value)
    if string.sub(text, pos, pos + string.len(word) - 1) == word then
      for _ = 1, string.len(word) do advance() end
      write(value)
      stats.nodes = stats.nodes + 1
    else
      fail("非法字面量 (应为 " .. word .. ")")
    end
  end

  local parseValue

  local function parseObject(depth, level)
    stats.nodes = stats.nodes + 1
    if depth > stats.maxDepth then stats.maxDepth = depth end
    advance() -- '{'
    skipWs()
    if string.byte(text, pos) == 125 then -- '}'
      advance()
      write("{}")
      return nil
    end
    write("{")
    local members = 0
    while true do
      skipWs()
      if pos > len then fail("对象未闭合") end
      if string.byte(text, pos) == 125 then -- '}'
        advance()
        break
      end
      if members > 0 then
        if string.byte(text, pos) ~= 44 then fail("对象成员之间缺少逗号") end
        advance()
        skipWs()
        if string.byte(text, pos) == 125 then fail("对象存在多余逗号") end
        write(",")
      end
      writeBreak(level + 1)
      if string.byte(text, pos) ~= 34 then fail("对象的键必须是字符串") end
      parseString()
      skipWs()
      if string.byte(text, pos) ~= 58 then fail("对象的键后缺少冒号") end
      advance()
      if indentWidth > 0 then write(": ") else write(":") end
      parseValue(depth + 1, level + 1)
      members = members + 1
    end
    if members > 0 then writeBreak(level) end
    write("}")
  end

  local function parseArray(depth, level)
    stats.nodes = stats.nodes + 1
    if depth > stats.maxDepth then stats.maxDepth = depth end
    advance() -- '['
    skipWs()
    if string.byte(text, pos) == 93 then -- ']'
      advance()
      write("[]")
      return nil
    end
    write("[")
    local items = 0
    while true do
      skipWs()
      if pos > len then fail("数组未闭合") end
      if string.byte(text, pos) == 93 then -- ']'
        advance()
        break
      end
      if items > 0 then
        if string.byte(text, pos) ~= 44 then fail("数组元素之间缺少逗号") end
        advance()
        skipWs()
        if string.byte(text, pos) == 93 then fail("数组存在多余逗号") end
        write(",")
      end
      writeBreak(level + 1)
      parseValue(depth + 1, level + 1)
      items = items + 1
    end
    if items > 0 then writeBreak(level) end
    write("]")
  end

  parseValue = function(depth, level)
    if depth > DEPTH_MAX then fail("嵌套深度超过 " .. DEPTH_MAX) end
    skipWs()
    if pos > len then fail("意外的结尾") end
    if stats.rootType == nil then
      stats.maxDepth = 1
    end
    local b = string.byte(text, pos)
    if b == 123 then -- {
      if stats.rootType == nil then stats.rootType = "object" end
      parseObject(depth, level)
    elseif b == 91 then -- [
      if stats.rootType == nil then stats.rootType = "array" end
      parseArray(depth, level)
    elseif b == 34 then -- "
      if stats.rootType == nil then stats.rootType = "string" end
      parseString()
    elseif b == 45 or (b >= 48 and b <= 57) then
      if stats.rootType == nil then stats.rootType = "number" end
      parseNumber()
    elseif b == 116 then -- t
      if stats.rootType == nil then stats.rootType = "boolean" end
      parseLiteral("true", "true")
    elseif b == 102 then -- f
      if stats.rootType == nil then stats.rootType = "boolean" end
      parseLiteral("false", "false")
    elseif b == 110 then -- n
      if stats.rootType == nil then stats.rootType = "null" end
      parseLiteral("null", "null")
    else
      fail("非法的值起始字符")
    end
  end

  parseValue(1, 0)
  skipWs()
  if pos <= len then
    fail("值之后存在多余内容")
  end
  return table.concat(out), stats
end

-- ---------------- 测试钩子 (harness 专用) ----------------
-- 与插件主路径行为一致: 解析失败返回 nil, 不向调用方抛错
function _jsonFormat(text, indent)
  local ok, out = pcall(process, text, indent or 2)
  if not ok then return nil end
  return out
end

function _jsonMinify(text)
  local ok, out = pcall(process, text, 0)
  if not ok then return nil end
  return out
end

-- ---------------- 插件状态与交互 ----------------
local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

function onInit()
  state.set("jsonInput", "")
  state.set("jsonOutput", "")
  state.set("jsonInfo", "")
  state.set("hasOutput", false)
  state.set("indentSize", 2)
  state.set("indentLabel", "缩进: 2 空格")
  clearError()
end

local function run(pretty)
  clearError()
  state.set("hasOutput", false)
  state.set("jsonOutput", "")
  state.set("jsonInfo", "")
  local text = state.get("jsonInput") or ""
  if text == "" then
    setError("请输入 JSON 文本")
    return nil
  end
  if string.len(text) > INPUT_MAX then
    setError("输入过长 (上限 " .. INPUT_MAX / 1000 .. "k 字符)")
    return nil
  end
  local indent = pretty and (state.get("indentSize") or 2) or 0
  local ok, out, stats = pcall(process, text, indent)
  if not ok then
    if type(out) == "table" then
      setError("解析失败 (第 " .. out.line .. " 行 第 " .. out.col .. " 列): " .. out.msg)
    else
      setError("解析失败: " .. tostring(out))
    end
    return nil
  end
  state.set("jsonOutput", out)
  state.set("jsonInfo", "类型: " .. (stats.rootType or "?") .. " · 节点: " .. stats.nodes
      .. " · 深度: " .. stats.maxDepth .. " · 输出 " .. string.len(out) .. " 字符")
  state.set("hasOutput", true)
  dialog.toast("处理完成")
end

function formatJson()
  run(true)
end

function minifyJson()
  run(false)
end

function setIndent(n)
  n = math.floor(tonumber(n) or 2)
  state.set("indentSize", n)
  state.set("indentLabel", "缩进: " .. n .. " 空格")
end

function cycleIndent()
  if (state.get("indentSize") or 2) == 2 then
    setIndent(4)
  else
    setIndent(2)
  end
end

function pasteJson()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("jsonInput", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
