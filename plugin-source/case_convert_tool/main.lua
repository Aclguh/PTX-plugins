-- case_convert_tool — 变量命名风格转换
-- 支持 camelCase, PascalCase, snake_case, kebab-case, CONSTANT_CASE, Title Case 等
-- 纯字符扫描切词，遵循 lua_dardo 坑位约束 (无 0x 字面量, string.len, return nil)

local function isUpper(cp)
  if cp >= 65 and cp <= 90 then return true else return false end
end

local function isLower(cp)
  if cp >= 97 and cp <= 122 then return true else return false end
end

local function isDigit(cp)
  if cp >= 48 and cp <= 57 then return true else return false end
end

local function isDelimiter(cp)
  if cp == 32 or cp == 9 or cp == 10 or cp == 13 or cp == 45 or cp == 95 or cp == 46 or cp == 47 or cp == 92 or cp == 58 then
    return true
  else
    return false
  end
end

local function toLowerChar(cp)
  if cp >= 65 and cp <= 90 then
    return string.char(cp + 32)
  else
    return string.char(cp)
  end
end

local function toUpperChar(cp)
  if cp >= 97 and cp <= 122 then
    return string.char(cp - 32)
  else
    return string.char(cp)
  end
end

local function capitalize(word)
  local len = string.len(word)
  if len == 0 then return "" end
  local first = string.byte(word, 1)
  local rest = ""
  if len > 1 then
    rest = string.sub(word, 2)
  end
  return toUpperChar(first) .. rest
end

local function upperWord(word)
  local len = string.len(word)
  local out = {}
  for i = 1, len do
    local cp = string.byte(word, i)
    out[i] = toUpperChar(cp)
  end
  return table.concat(out)
end

function _split_words(text)
  local words = {}
  local len = string.len(text)
  if len == 0 then return words end

  local cur = {}
  local i = 1
  while i <= len do
    local cp = string.byte(text, i)
    if isDelimiter(cp) then
      if #cur > 0 then
        words[#words + 1] = table.concat(cur)
        cur = {}
      end
    else
      local nextCp = 0
      if i + 1 <= len then
        nextCp = string.byte(text, i + 1)
      end

      local prevCp = 0
      if i - 1 >= 1 then
        prevCp = string.byte(text, i - 1)
      end

      local shouldSplit = false
      if isUpper(cp) then
        if isLower(prevCp) or isDigit(prevCp) then
          shouldSplit = true
        elseif isUpper(prevCp) and isLower(nextCp) then
          shouldSplit = true
        end
      end

      if shouldSplit and #cur > 0 then
        words[#words + 1] = table.concat(cur)
        cur = {}
      end

      cur[#cur + 1] = toLowerChar(cp)
    end
    i = i + 1
  end

  if #cur > 0 then
    words[#words + 1] = table.concat(cur)
  end

  return words
end

function _to_camel(words)
  if #words == 0 then return "" end
  local out = { words[1] }
  for i = 2, #words do
    out[#out + 1] = capitalize(words[i])
  end
  return table.concat(out)
end

function _to_pascal(words)
  if #words == 0 then return "" end
  local out = {}
  for i = 1, #words do
    out[#out + 1] = capitalize(words[i])
  end
  return table.concat(out)
end

function _to_snake(words)
  return table.concat(words, "_")
end

function _to_kebab(words)
  return table.concat(words, "-")
end

function _to_constant(words)
  local out = {}
  for i = 1, #words do
    out[#out + 1] = upperWord(words[i])
  end
  return table.concat(out, "_")
end

function _to_title(words)
  local out = {}
  for i = 1, #words do
    out[#out + 1] = capitalize(words[i])
  end
  return table.concat(out, " ")
end

function _to_dot(words)
  return table.concat(words, ".")
end

function _to_path(words)
  return table.concat(words, "/")
end

function convert()
  local input = state.get("input") or ""
  if string.len(input) == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入待转换的变量名或文本")
    state.set("hasResult", false)
    return nil
  end

  local words = _split_words(input)
  if #words == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "未检测到有效字符或单词")
    state.set("hasResult", false)
    return nil
  end

  state.set("hasError", false)
  state.set("errorMsg", "")
  state.set("camelCase", _to_camel(words))
  state.set("pascalCase", _to_pascal(words))
  state.set("snakeCase", _to_snake(words))
  state.set("kebabCase", _to_kebab(words))
  state.set("constantCase", _to_constant(words))
  state.set("titleCase", _to_title(words))
  state.set("dotCase", _to_dot(words))
  state.set("pathCase", _to_path(words))
  state.set("hasResult", true)
  return nil
end

function clearAll()
  state.set("input", "")
  state.set("camelCase", "")
  state.set("pascalCase", "")
  state.set("snakeCase", "")
  state.set("kebabCase", "")
  state.set("constantCase", "")
  state.set("titleCase", "")
  state.set("dotCase", "")
  state.set("pathCase", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function pasteInput()
  clipboard.get(function(text)
    if text ~= nil then
      state.set("input", text)
      convert()
    end
    return nil
  end)
  return nil
end

function onInit()
  state.set("input", "")
  state.set("camelCase", "")
  state.set("pascalCase", "")
  state.set("snakeCase", "")
  state.set("kebabCase", "")
  state.set("constantCase", "")
  state.set("titleCase", "")
  state.set("dotCase", "")
  state.set("pathCase", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end
