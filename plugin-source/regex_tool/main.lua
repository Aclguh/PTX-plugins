-- regex_tool — 正则表达式测试
-- 宿主沙箱无 PCRE, 内置自实现迷你正则引擎: 递归下降解析 + CPS 回溯匹配,
-- 按码点匹配 (兼容中文); 支持 ^ $ . [] () (?:) | * + ? {n,m} (含懒惰),
-- \d \D \w \W \s \S \b \B 与常见转义; 标志: i (ASCII 大小写折叠)
-- 防灾设计: 模式 ≤ 500 字符, 输入 ≤ 20000 字符, 匹配结果 ≤ 200 条,
-- 灾难性回溯由宿主指令数预算兜底 (pcall 降级为友好提示)

local PATTERN_MAX = 500
local SUBJECT_MAX = 20000
local MATCH_MAX = 200

-- 预定义类展开 (码点区间)
local CLASS_RANGES = {
  d = { { 48, 57 } },
  w = { { 48, 57 }, { 65, 90 }, { 95, 95 }, { 97, 122 } },
  s = { { 9, 13 }, { 32, 32 } },
}

local function foldCp(c)
  if c >= 65 and c <= 90 then return c + 32 end
  return c
end

-- ---------------- 模式解析 ----------------
local function parsePattern(pattern, caseFold)
  local pos = 1
  local len = string.len(pattern)
  local nGroups = 0

  local function peek()
    if pos > len then return nil end
    return string.byte(pattern, pos)
  end

  local function nextCh()
    local c = string.byte(pattern, pos)
    pos = pos + 1
    return c
  end

  local function fail(msg)
    error({ msg = msg }, 0)
  end

  -- 转义: 返回 码点(字面量) / {cls='d'|'D'|'w'|'W'|'s'|'S'} / {anchor='wb'|'B'}
  local function parseEscape(inClass)
    local c = nextCh()
    if c == nil then fail("转义符后缺少字符") end
    if c == 100 then return { cls = "d" }      -- d
    elseif c == 68 then return { cls = "D" }   -- D
    elseif c == 119 then return { cls = "w" }  -- w
    elseif c == 87 then return { cls = "W" }   -- W
    elseif c == 115 then return { cls = "s" }  -- s
    elseif c == 83 then return { cls = "S" }   -- S
    elseif c == 110 then return 10             -- \n
    elseif c == 116 then return 9              -- \t
    elseif c == 114 then return 13             -- \r
    elseif c == 102 then return 12             -- \f
    elseif c == 118 then return 11             -- \v
    elseif c == 48 then return 0               -- \0
    elseif c == 98 and not inClass then return { anchor = "wb" }  -- \b
    elseif c == 66 and not inClass then return { anchor = "B" }   -- \B
    else return c end  -- \. \\ \[ \( 等按字面量
  end

  -- 解析器内部互相循环引用 (parseAtom -> parseAlt -> parseSeq ->
  -- parseQuantified -> parseAtom), 局部函数必须先前向声明, 否则后续
  -- 声明在编译期不可见, 调用得到 nil
  local parseAtom, parseQuantified, parseSeq, parseAlt

  local function parseClass()
    local neg = false
    if peek() == 94 then -- '^'
      neg = true
      nextCh()
    end
    local ranges = {}
    local first = true
    while true do
      local c = peek()
      if c == nil then fail("字符类未闭合") end
      if c == 93 and not first then -- ']'
        nextCh()
        break
      end
      first = false
      local lo
      if c == 92 then
        nextCh()
        local e = parseEscape(true)
        if type(e) == "table" and e.cls then
          for _, r in ipairs(CLASS_RANGES[e.cls]) do
            ranges[#ranges + 1] = r
          end
        else
          lo = e
        end
      else
        nextCh()
        lo = c
      end
      if lo ~= nil then
        -- 范围 a-z (排除末尾 '-' 字面量情况)
        if peek() == 45 and pos + 1 <= len and string.byte(pattern, pos + 1) ~= 93 then
          nextCh() -- '-'
          local hi = peek()
          if hi == 92 then
            nextCh()
            local e2 = parseEscape(true)
            if type(e2) == "table" then fail("范围端点不能是类缩写") end
            hi = e2
          else
            nextCh()
          end
          if hi < lo then fail("字符类范围上下界颠倒") end
          ranges[#ranges + 1] = { lo, hi }
        else
          ranges[#ranges + 1] = { lo, lo }
        end
      end
    end
    if #ranges == 0 then fail("空的字符类") end
    return { t = "cls", ranges = ranges, neg = neg }
  end

  local function parseNumberLiteral()
    local n = 0
    local digits = 0
    while peek() ~= nil and peek() >= 48 and peek() <= 57 do
      n = n * 10 + (nextCh() - 48)
      digits = digits + 1
    end
    if digits == 0 then return nil end
    return n
  end

  parseAtom = function()
    local c = peek()
    if c == 40 then -- '('
      nextCh()
      local idx = nil
      if peek() == 63 then -- '(?'
        nextCh()
        if peek() ~= 58 then fail("仅支持 (?: 非捕获组") end
        nextCh()
      else
        nGroups = nGroups + 1
        idx = nGroups
      end
      local child = parseAlt()
      if peek() ~= 41 then fail("括号未闭合") end
      nextCh()
      return { t = "grp", idx = idx, child = child }
    elseif c == 91 then -- '['
      nextCh()
      return parseClass()
    elseif c == 46 then -- '.'
      nextCh()
      return { t = "any" }
    elseif c == 94 then -- '^'
      nextCh()
      return { t = "bol" }
    elseif c == 36 then -- '$'
      nextCh()
      return { t = "eol" }
    elseif c == 92 then -- '\'
      nextCh()
      local e = parseEscape(false)
      if type(e) == "table" and e.cls then
        local key = string.lower(e.cls)
        return { t = "cls", ranges = CLASS_RANGES[key], neg = (key ~= e.cls) }
      elseif type(e) == "table" and e.anchor then
        return { t = "wb", neg = (e.anchor == "B") }
      else
        return { t = "char", cp = e }
      end
    elseif c == 42 or c == 43 or c == 63 then
      fail("量词前缺少可重复元素")
    elseif c == 41 then
      fail("多余的右括号")
    else
      nextCh()
      return { t = "char", cp = c }
    end
  end

  parseQuantified = function()
    local atom = parseAtom()
    local min, max = 1, 1
    local c = peek()
    if c == 42 then
      nextCh()
      min, max = 0, nil
    elseif c == 43 then
      nextCh()
      min, max = 1, nil
    elseif c == 63 then
      nextCh()
      min, max = 0, 1
    elseif c == 123 then -- '{'
      local save = pos
      nextCh()
      local n1 = parseNumberLiteral()
      if n1 == nil then
        pos = save -- '{' 当字面量
        return atom
      end
      if peek() == 44 then -- ','
        nextCh()
        local n2 = parseNumberLiteral()
        if n2 == nil then
          min, max = n1, nil
        else
          min, max = n1, n2
        end
      else
        min, max = n1, n1
      end
      if peek() ~= 125 then -- '}'
        pos = save
        return atom
      end
      nextCh()
    else
      return atom
    end
    local lazy = false
    if peek() == 63 then
      nextCh()
      lazy = true
    end
    if max ~= nil and min > max then fail("量词上下界颠倒") end
    return { t = "rep", child = atom, min = min, max = max, lazy = lazy }
  end

  parseSeq = function()
    local items = {}
    while true do
      local c = peek()
      if c == nil or c == 124 or c == 41 then break end
      items[#items + 1] = parseQuantified()
    end
    return { t = "seq", items = items }
  end

  parseAlt = function()
    local branches = { parseSeq() }
    while peek() == 124 do -- '|'
      nextCh()
      branches[#branches + 1] = parseSeq()
    end
    if #branches == 1 then return branches[1] end
    return { t = "alt", branches = branches }
  end

  local ast = parseAlt()
  if pos <= len then fail("存在无法解析的剩余字符") end
  return ast, nGroups
end

-- ---------------- CPS 回溯匹配 ----------------
local function createMatcher(ast, nGroups, subject, caseFold)
  local len = string.len(subject)

  local function cpAt(p)
    return string.byte(subject, p)
  end

  local function cpEq(a, b)
    if a == b then return true end
    if caseFold then
      local fa, fb = a, b
      if a >= 65 and a <= 90 then fa = a + 32 end
      if b >= 65 and b <= 90 then fb = b + 32 end
      return fa == fb
    end
    return false
  end

  local function inRanges(c, ranges)
    for _, r in ipairs(ranges) do
      if c >= r[1] and c <= r[2] then return true end
    end
    return false
  end

  local function isWord(c)
    return (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95
  end

  local caps = {}

  local function m(node, pos, k)
    local t = node.t
    if t == "char" then
      if pos <= len and cpEq(cpAt(pos), node.cp) then return k(pos + 1) end
      return nil
    elseif t == "any" then
      if pos <= len and cpAt(pos) ~= 10 then return k(pos + 1) end
      return nil
    elseif t == "cls" then
      if pos <= len then
        local hit = inRanges(cpAt(pos), node.ranges)
        if node.neg then hit = not hit end
        if hit then return k(pos + 1) end
      end
      return nil
    elseif t == "seq" then
      local items = node.items
      local function step(i, p)
        if i > #items then return k(p) end
        return m(items[i], p, function(q)
          return step(i + 1, q)
        end)
      end
      return step(1, pos)
    elseif t == "alt" then
      for _, br in ipairs(node.branches) do
        local r = m(br, pos, k)
        if r ~= nil then return r end
      end
      return nil
    elseif t == "rep" then
      local function rep(p, count)
        local function tryMore()
          if node.max ~= nil and count >= node.max then return nil end
          return m(node.child, p, function(q)
            if q == p then return nil end -- 零宽保护, 防死循环
            return rep(q, count + 1)
          end)
        end
        if count < node.min then return tryMore() end
        if node.lazy then
          local r = k(p)
          if r ~= nil then return r end
          return tryMore()
        end
        local r = tryMore()
        if r ~= nil then return r end
        return k(p)
      end
      return rep(pos, 0)
    elseif t == "grp" then
      if node.idx == nil then return m(node.child, pos, k) end
      local saved = caps[node.idx]
      caps[node.idx] = { pos, nil }
      local r = m(node.child, pos, function(q)
        caps[node.idx][2] = q
        return k(q)
      end)
      if r == nil then caps[node.idx] = saved end
      return r
    elseif t == "bol" then
      if pos == 1 then return k(pos) end
      return nil
    elseif t == "eol" then
      if pos > len then return k(pos) end
      return nil
    elseif t == "wb" then
      local before = pos > 1 and isWord(cpAt(pos - 1)) or false
      local after = pos <= len and isWord(cpAt(pos)) or false
      if (before ~= after) ~= node.neg then return k(pos) end
      return nil
    end
    return nil
  end

  return {
    -- 从 fromPos 起找第一个匹配: 返回 {s, e, groups={{s,e}...}} 或 nil
    find = function(fromPos)
      for s = fromPos, len + 1 do
        caps = {}
        local r = m(ast, s, function(q)
          return { s = s, e = q - 1 }
        end)
        if r ~= nil then
          local groups = {}
          for i = 1, nGroups do
            local g = caps[i]
            if g ~= nil and g[2] ~= nil then
              groups[#groups + 1] = { s = g[1], e = g[2] - 1 }
            else
              groups[#groups + 1] = nil
            end
          end
          return { s = r.s, e = r.e, groups = groups }
        end
      end
      return nil
    end,
  }
end

-- 高层封装: pcall 包裹解析与查找, 返回结果或 nil+友好错误
local function engineFindAll(pattern, subject, flags)
  if string.len(pattern) > PATTERN_MAX then
    return nil, "模式过长 (上限 " .. PATTERN_MAX .. " 字符)"
  end
  if string.len(subject) > SUBJECT_MAX then
    return nil, "输入过长 (上限 " .. SUBJECT_MAX / 1000 .. "k 字符)"
  end
  local ok, ast, nGroups = pcall(parsePattern, pattern, flags == "i")
  if not ok then
    if type(ast) == "table" then return nil, "模式错误: " .. ast.msg end
    return nil, "模式错误: " .. tostring(ast)
  end
  local matcher = createMatcher(ast, nGroups, subject, flags == "i")
  local matches = {}
  local fromPos = 1
  while #matches < MATCH_MAX do
    local ok2, r = pcall(matcher.find, fromPos)
    if not ok2 then
      return nil, "匹配超时或模式过于复杂 (已触发执行预算保护)"
    end
    if r == nil then break end
    matches[#matches + 1] = r
    -- e 为闭区间: 非空匹配从其后一字符继续, 零宽匹配从匹配点后一字符继续
    if r.e >= r.s then
      fromPos = r.e + 1
    else
      fromPos = r.s + 1
    end
  end
  return matches, nGroups
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _rxFindAll(pattern, subject, flags)
  local matches, info = engineFindAll(pattern, subject, flags)
  if matches == nil then return nil, info end
  local out = {}
  for _, r in ipairs(matches) do
    local groups = {}
    for _, g in ipairs(r.groups) do
      if g ~= nil then
        groups[#groups + 1] = string.sub(subject, g.s, g.e)
      else
        groups[#groups + 1] = nil
      end
    end
    out[#out + 1] = {
      text = string.sub(subject, r.s, r.e),
      s = r.s,
      e = r.e,
      groups = groups,
    }
  end
  return { matches = out, ngroups = info }
end

function _rxReplace(pattern, subject, flags, repl)
  local matches, info = engineFindAll(pattern, subject, flags)
  if matches == nil then return nil, info end
  local out = {}
  local lastPos = 1
  local count = 0
  for _, r in ipairs(matches) do
    out[#out + 1] = string.sub(subject, lastPos, r.s - 1)
    -- 展开 $0-$9 / $$
    local i = 1
    local rl = string.len(repl)
    while i <= rl do
      local c = string.sub(repl, i, i)
      if c == "$" and i < rl then
        local n = string.sub(repl, i + 1, i + 1)
        if n == "$" then
          out[#out + 1] = "$"
          i = i + 2
        elseif n >= "0" and n <= "9" then
          local gi = string.byte(n) - 48
          if gi == 0 then
            out[#out + 1] = string.sub(subject, r.s, r.e)
          else
            local g = r.groups[gi]
            if g ~= nil then
              out[#out + 1] = string.sub(subject, g.s, g.e)
            end
          end
          i = i + 2
        else
          out[#out + 1] = c
          i = i + 1
        end
      else
        out[#out + 1] = c
        i = i + 1
      end
    end
    lastPos = r.e + 1
    count = count + 1
    -- 零宽匹配防 死循环
    if r.e < r.s then lastPos = r.s + 1 end
  end
  out[#out + 1] = string.sub(subject, lastPos)
  return { text = table.concat(out), count = count, ngroups = info }
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

local function engineError(res)
  if type(res) == "table" and res.msg then
    return "解析失败: " .. res.msg
  end
  return "解析失败: " .. tostring(res)
end

function onInit()
  state.set("patternStr", "")
  state.set("subjectStr", "")
  state.set("replaceStr", "")
  state.set("caseOn", false)
  state.set("caseLabel", "忽略大小写: 关")
  state.set("matchResult", "")
  state.set("hasMatch", false)
  state.set("allResult", "")
  state.set("hasAll", false)
  state.set("replaceResult", "")
  state.set("hasReplace", false)
  clearError()
end

function toggleCaseFlag()
  local nextVal = not state.get("caseOn")
  state.set("caseOn", nextVal)
  if nextVal then
    state.set("caseLabel", "忽略大小写: 开")
  else
    state.set("caseLabel", "忽略大小写: 关")
  end
end

function testMatch()
  clearError()
  state.set("hasMatch", false)
  state.set("matchResult", "")
  local pattern = state.get("patternStr") or ""
  local subject = state.get("subjectStr") or ""
  local flags = state.get("caseOn") and "i" or ""
  local ok, res, info = pcall(_rxFindAll, pattern, subject, flags)
  if not ok then
    setError(engineError(res))
    return nil
  end
  if res == nil then
    setError(info)
    return nil
  end
  if #res.matches == 0 then
    state.set("matchResult", "未匹配")
    state.set("hasMatch", true)
    return nil
  end
  local first = res.matches[1]
  local lines = { "匹配: [" .. first.s .. "-" .. first.e .. "] " .. first.text }
  for gi, g in ipairs(first.groups) do
    if g ~= nil then
      lines[#lines + 1] = "捕获组 " .. gi .. ": " .. g
    else
      lines[#lines + 1] = "捕获组 " .. gi .. ": (未参与)"
    end
  end
  state.set("matchResult", table.concat(lines, "\n"))
  state.set("hasMatch", true)
end

function findAll()
  clearError()
  state.set("hasAll", false)
  state.set("allResult", "")
  local pattern = state.get("patternStr") or ""
  local subject = state.get("subjectStr") or ""
  local flags = state.get("caseOn") and "i" or ""
  local ok, res, info = pcall(_rxFindAll, pattern, subject, flags)
  if not ok then
    setError(engineError(res))
    return nil
  end
  if res == nil then
    setError(info)
    return nil
  end
  if #res.matches == 0 then
    state.set("allResult", "未找到任何匹配")
    state.set("hasAll", true)
    return nil
  end
  local lines = { "共 " .. #res.matches .. " 处匹配:" }
  for i, rmatch in ipairs(res.matches) do
    local line = i .. ". [" .. rmatch.s .. "-" .. rmatch.e .. "] " .. rmatch.text
    if #rmatch.groups > 0 then
      local gs = {}
      for gi, g in ipairs(rmatch.groups) do
        if g ~= nil then gs[#gs + 1] = "$" .. gi .. "=" .. g end
      end
      if #gs > 0 then line = line .. "  (" .. table.concat(gs, ", ") .. ")" end
    end
    lines[#lines + 1] = line
  end
  state.set("allResult", table.concat(lines, "\n"))
  state.set("hasAll", true)
end

function replacePreview()
  clearError()
  state.set("hasReplace", false)
  state.set("replaceResult", "")
  local pattern = state.get("patternStr") or ""
  local subject = state.get("subjectStr") or ""
  local repl = state.get("replaceStr") or ""
  local flags = state.get("caseOn") and "i" or ""
  local ok, res, info = pcall(_rxReplace, pattern, subject, flags, repl)
  if not ok then
    setError(engineError(res))
    return nil
  end
  if res == nil then
    setError(info)
    return nil
  end
  state.set("replaceResult", "替换 " .. res.count .. " 处:\n" .. res.text)
  state.set("hasReplace", true)
end

function pastePattern()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("patternStr", val)
      dialog.toast("已粘贴模式")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end

function pasteSubject()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("subjectStr", val)
      dialog.toast("已粘贴输入文本")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
