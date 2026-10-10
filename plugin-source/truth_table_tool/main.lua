-- truth_table_tool: 命题逻辑与真值表生成器

local function isAlpha(b)
  if b >= 65 and b <= 90 then
    return true
  end
  if b >= 97 and b <= 122 then
    return true
  end
  return false
end

local function tokenize(expr)
  local tokens = {}
  local len = string.len(expr)
  local i = 1
  while i <= len do
    local b = string.byte(expr, i)
    if b == 32 or b == 9 or b == 10 or b == 13 then
      i = i + 1
    elseif b == 40 then
      tokens[#tokens + 1] = { type = "LPAREN", val = "(" }
      i = i + 1
    elseif b == 41 then
      tokens[#tokens + 1] = { type = "RPAREN", val = ")" }
      i = i + 1
    elseif b == 33 or b == 126 then
      tokens[#tokens + 1] = { type = "NOT", val = "not" }
      i = i + 1
    elseif b == 38 then
      tokens[#tokens + 1] = { type = "AND", val = "and" }
      i = i + 1
    elseif b == 124 then
      tokens[#tokens + 1] = { type = "OR", val = "or" }
      i = i + 1
    elseif b == 60 then
      -- 检查 <-> 或 <=>
      local s3 = string.sub(expr, i, i + 2)
      if s3 == "<->" or s3 == "<=>" then
        tokens[#tokens + 1] = { type = "EQUIV", val = "<->" }
        i = i + 3
      else
        tokens[#tokens + 1] = { type = "UNKNOWN", val = "<" }
        i = i + 1
      end
    elseif b == 45 or b == 61 then
      -- 检查 -> 或 =>
      local s2 = string.sub(expr, i, i + 1)
      if s2 == "->" or s2 == "=>" then
        tokens[#tokens + 1] = { type = "IMPLIES", val = "->" }
        i = i + 2
      else
        tokens[#tokens + 1] = { type = "UNKNOWN", val = string.sub(expr, i, i) }
        i = i + 1
      end
    else
      if isAlpha(b) then
        local startIdx = i
        while i <= len and isAlpha(string.byte(expr, i)) do
          i = i + 1
        end
        local word = string.lower(string.sub(expr, startIdx, i - 1))
        if word == "not" then
          tokens[#tokens + 1] = { type = "NOT", val = "not" }
        elseif word == "and" then
          tokens[#tokens + 1] = { type = "AND", val = "and" }
        elseif word == "or" then
          tokens[#tokens + 1] = { type = "OR", val = "or" }
        elseif word == "xor" then
          tokens[#tokens + 1] = { type = "XOR", val = "xor" }
        elseif word == "true" or word == "t" or word == "1" then
          tokens[#tokens + 1] = { type = "CONST", val = true }
        elseif word == "false" or word == "f" or word == "0" then
          tokens[#tokens + 1] = { type = "CONST", val = false }
        else
          tokens[#tokens + 1] = { type = "VAR", val = word }
        end
      else
        tokens[#tokens + 1] = { type = "UNKNOWN", val = string.sub(expr, i, i) }
        i = i + 1
      end
    end
  end
  return tokens
end

local function extractVariables(tokens)
  local varsMap = {}
  local varsList = {}
  local cnt = #tokens
  local i = 1
  while i <= cnt do
    local t = tokens[i]
    if t.type == "VAR" then
      if varsMap[t.val] == nil then
        varsMap[t.val] = true
        varsList[#varsList + 1] = t.val
      end
    end
    i = i + 1
  end
  table.sort(varsList)
  return varsList
end

local function evaluateAST(tokens, env)
  local pos = 1
  local total = #tokens

  local function peek()
    if pos <= total then
      return tokens[pos]
    end
    return { type = "EOF", val = "" }
  end

  local function consume()
    local t = peek()
    pos = pos + 1
    return t
  end

  local parseEquiv, parseImplies, parseOr, parseAnd, parseNot, parsePrimary

  parsePrimary = function()
    local t = peek()
    if t.type == "LPAREN" then
      consume()
      local val = parseEquiv()
      local r = peek()
      if r.type == "RPAREN" then
        consume()
      end
      return val
    elseif t.type == "CONST" then
      consume()
      return t.val
    elseif t.type == "VAR" then
      consume()
      local v = env[t.val]
      if v == nil then
        return false
      end
      return v
    end
    consume()
    return false
  end

  parseNot = function()
    local t = peek()
    if t.type == "NOT" then
      consume()
      return not parseNot()
    end
    return parsePrimary()
  end

  parseAnd = function()
    local left = parseNot()
    while peek().type == "AND" do
      consume()
      local right = parseNot()
      left = left and right
    end
    return left
  end

  parseOr = function()
    local left = parseAnd()
    while peek().type == "OR" or peek().type == "XOR" do
      local op = consume()
      local right = parseAnd()
      if op.type == "XOR" then
        left = (left ~= right)
      else
        left = left or right
      end
    end
    return left
  end

  parseImplies = function()
    local left = parseOr()
    if peek().type == "IMPLIES" then
      consume()
      local right = parseImplies()
      -- a -> b 等价于 (not a) or b
      left = (not left) or right
    end
    return left
  end

  parseEquiv = function()
    local left = parseImplies()
    while peek().type == "EQUIV" do
      consume()
      local right = parseImplies()
      left = (left == right)
    end
    return left
  end

  return parseEquiv()
end

function generate()
  local raw = state.get("logicExpr")
  if raw == nil or string.len(raw) == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入逻辑公式")
    state.set("hasResult", false)
    return nil
  end

  local tokens = tokenize(raw)
  if #tokens == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "无法解析公式中的标记")
    state.set("hasResult", false)
    return nil
  end

  local vars = extractVariables(tokens)
  local varCount = #vars
  if varCount > 5 then
    state.set("hasError", true)
    state.set("errorMsg", "变元过多 (> 5 个)，行数将超过 32 行限制")
    state.set("hasResult", false)
    return nil
  end

  state.set("hasError", false)
  state.set("errorMsg", "")

  local totalRows = 2 ^ varCount
  local trueCount = 0
  local falseCount = 0

  -- 构建表头
  local header = "| "
  local sep = "| "
  local vIdx = 1
  while vIdx <= varCount do
    header = header .. vars[vIdx] .. " | "
    sep = sep .. "--- | "
    vIdx = vIdx + 1
  end
  header = header .. raw .. " |\n"
  sep = sep .. "--- |\n"

  local rowsText = header .. sep

  -- 枚举 0 到 totalRows - 1
  local r = 0
  while r < totalRows do
    local env = {}
    local rowLine = "| "
    local vi = 1
    while vi <= varCount do
      local shift = 2 ^ (varCount - vi)
      local bitVal = math.floor(r / shift) % 2
      local boolVal = (bitVal == 1)
      env[vars[vi]] = boolVal
      if boolVal then
        rowLine = rowLine .. "T | "
      else
        rowLine = rowLine .. "F | "
      end
      vi = vi + 1
    end

    local ok, evalRes = pcall(function()
      return evaluateAST(tokens, env)
    end)

    if not ok then
      state.set("hasError", true)
      state.set("errorMsg", "公式语法错误，请检查括号与算符")
      state.set("hasResult", false)
      return nil
    end

    if evalRes then
      trueCount = trueCount + 1
      rowLine = rowLine .. "T |\n"
    else
      falseCount = falseCount + 1
      rowLine = rowLine .. "F |\n"
    end

    rowsText = rowsText .. rowLine
    r = r + 1
  end

  local classification = ""
  if trueCount == totalRows then
    classification = "永真式 / 重言式 (Tautology)"
  elseif falseCount == totalRows then
    classification = "永假式 / 矛盾式 (Contradiction)"
  else
    classification = "可满足式 (Satisfiable, 真值数: " .. tostring(trueCount) .. "/" .. tostring(totalRows) .. ")"
  end

  state.set("hasResult", true)
  state.set("truthTableOutput", rowsText)
  state.set("formulaClassification", classification)
  state.set("totalRows", totalRows)
  state.set("trueCount", trueCount)
  state.set("falseCount", falseCount)

  return nil
end

function onInit()
  state.set("logicExpr", "(p and q) -> r")
  state.set("truthTableOutput", "")
  state.set("formulaClassification", "")
  state.set("totalRows", 0)
  state.set("trueCount", 0)
  state.set("falseCount", 0)
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  generate()
  return nil
end

function setExample(ex)
  if ex == "demorgan" then
    state.set("logicExpr", "not (p and q) <-> (not p or not q)")
  elseif ex == "contra" then
    state.set("logicExpr", "(p -> q) <-> (not q -> not p)")
  elseif ex == "excluded" then
    state.set("logicExpr", "p or not p")
  elseif ex == "modus" then
    state.set("logicExpr", "((p -> q) and p) -> q")
  else
    state.set("logicExpr", "(p and q) -> r")
  end
  generate()
  return nil
end

function copyTable()
  local tbl = state.get("truthTableOutput")
  if tbl ~= nil then
    clipboard.set(tbl)
    dialog.toast("已复制真值表 Markdown")
  end
  return nil
end

function clearAll()
  state.set("logicExpr", "")
  state.set("hasResult", false)
  state.set("truthTableOutput", "")
  state.set("formulaClassification", "")
  return nil
end
