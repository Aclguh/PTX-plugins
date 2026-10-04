-- diff_tool — 文本差异对比
-- 基于 LCS (最长公共子序列) 的行级 diff, 每侧限 400 行防指令预算超限

local LINE_LIMIT = 400

-- 用纯文本 find 实现的行切分 (兼容 \r\n 与 \r 换行); 空文本视为零行
local function splitLinesFast(s)
  if s == "" then return {} end
  local lines = {}
  local start = 1
  local len = string.len(s)
  while start <= len do
    local p = string.find(s, "\n", start, true)
    local lineEnd
    if p == nil then
      lineEnd = len
    else
      lineEnd = p - 1
    end
    local line = string.sub(s, start, lineEnd)
    -- 去除行尾 \r (兼容 Windows 换行)
    if string.sub(line, -1) == "\r" then
      line = string.sub(line, 1, string.len(line) - 1)
    end
    lines[#lines + 1] = line
    if p == nil then break end
    start = p + 1
  end
  return lines
end

-- LCS 动态规划, 返回差异操作列表 { op='='|'-'|'+', line= }
local function diffLinesInternal(a, b)
  local n, m = #a, #b
  -- dp[i][j] = a[i..] 与 b[j..] 的 LCS 长度 (自底向上)
  local dp = {}
  for i = 0, n do
    dp[i] = {}
    for j = 0, m do
      dp[i][j] = 0
    end
  end
  for i = n - 1, 0, -1 do
    for j = m - 1, 0, -1 do
      if a[i + 1] == b[j + 1] then
        dp[i][j] = dp[i + 1][j + 1] + 1
      else
        local x, y = dp[i + 1][j], dp[i][j + 1]
        if x >= y then dp[i][j] = x else dp[i][j] = y end
      end
    end
  end
  -- 回溯生成编辑脚本
  local ops = {}
  local i, j = 0, 0
  while i < n and j < m do
    if a[i + 1] == b[j + 1] then
      ops[#ops + 1] = { op = "=", line = a[i + 1] }
      i, j = i + 1, j + 1
    elseif dp[i + 1][j] >= dp[i][j + 1] then
      ops[#ops + 1] = { op = "-", line = a[i + 1] }
      i = i + 1
    else
      ops[#ops + 1] = { op = "+", line = b[j + 1] }
      j = j + 1
    end
  end
  while i < n do
    ops[#ops + 1] = { op = "-", line = a[i + 1] }
    i = i + 1
  end
  while j < m do
    ops[#ops + 1] = { op = "+", line = b[j + 1] }
    j = j + 1
  end
  return ops
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _diffLines(aText, bText)
  local a = splitLinesFast(aText)
  local b = splitLinesFast(bText)
  if #a > LINE_LIMIT or #b > LINE_LIMIT then
    return nil, "文本过长 (每侧上限 " .. LINE_LIMIT .. " 行)"
  end
  local ops = diffLinesInternal(a, b)
  local added, removed, same = 0, 0, 0
  for _, o in ipairs(ops) do
    if o.op == "+" then added = added + 1
    elseif o.op == "-" then removed = removed + 1
    else same = same + 1 end
  end
  return { ops = ops, added = added, removed = removed, same = same }
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("textA", "")
  state.set("textB", "")
  state.set("statsText", "")
  state.set("diffText", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
end

function doDiff()
  state.set("hasError", false)
  state.set("errorMsg", "")
  local a = splitLinesFast(state.get("textA") or "")
  local b = splitLinesFast(state.get("textB") or "")
  if #a > LINE_LIMIT or #b > LINE_LIMIT then
    state.set("hasResult", false)
    state.set("statsText", "")
    state.set("diffText", "")
    state.set("hasError", true)
    state.set("errorMsg", "文本过长 (每侧上限 " .. LINE_LIMIT .. " 行)")
    return nil
  end
  local ops = diffLinesInternal(a, b)
  local added, removed, same = 0, 0, 0
  for _, o in ipairs(ops) do
    if o.op == "+" then added = added + 1
    elseif o.op == "-" then removed = removed + 1
    else same = same + 1 end
  end
  state.set("statsText", "新增 " .. added .. " 行 · 删除 " .. removed
      .. " 行 · 不变 " .. same .. " 行")
  local out = {}
  local count = 0
  local truncated = false
  for _, o in ipairs(ops) do
    count = count + 1
    if count > 400 then
      truncated = true
      break
    end
    if o.op == "=" then
      out[#out + 1] = "  " .. o.line
    elseif o.op == "-" then
      out[#out + 1] = "- " .. o.line
    else
      out[#out + 1] = "+ " .. o.line
    end
  end
  if truncated then
    out[#out + 1] = "... (差异超过 400 行, 已截断)"
  end
  state.set("diffText", table.concat(out, "\n"))
  state.set("hasResult", true)
  dialog.toast("对比完成")
end

function swapTexts()
  state.set("textA", state.get("textB") or "")
  state.set("textB", state.get("textA") or "")
end
