-- line_tool — 行文本批处理
-- 排序/去重/去空行/去首尾空白/加行号/倒序, 全部基于纯文本 find+sub 手写实现

local MAX_LINES = 5000

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

-- 按换行拆分为数组 (最后一段含空串)
function _splitLines(s)
  local out = {}
  local start = 1
  while true do
    local pos = string.find(s, "\n", start, true)
    if pos == nil then
      out[#out + 1] = string.sub(s, start)
      return out
    end
    out[#out + 1] = string.sub(s, start, pos - 1)
    start = pos + 1
  end
end

-- 去除首尾空格与制表符
function _trim(s)
  local a = 1
  local b = string.len(s)
  while a <= b and string.sub(s, a, a) == " " do a = a + 1 end
  while b >= a and string.sub(s, b, b) == " " do b = b - 1 end
  while a <= b and string.sub(s, a, a) == "\t" do a = a + 1 end
  while b >= a and string.sub(s, b, b) == "\t" do b = b - 1 end
  if a > b then return "" end
  return string.sub(s, a, b)
end

-- op: sortAsc/sortDesc/dedupe/keepNonEmpty/trim/number/reverse
-- 返回处理后的整块文本; 超限返回 nil, err
function _process(op, text)
  local lines = _splitLines(text)
  if #lines > MAX_LINES then
    return nil, "行数超过上限 (" .. #lines .. " > " .. MAX_LINES .. ")"
  end
  if op == "sortAsc" then
    table.sort(lines)
  elseif op == "sortDesc" then
    table.sort(lines, function(a, b) return a > b end)
  elseif op == "dedupe" then
    local seen = {}
    local uniq = {}
    for _, line in ipairs(lines) do
      if seen[line] == nil then
        seen[line] = true
        uniq[#uniq + 1] = line
      end
    end
    lines = uniq
  elseif op == "keepNonEmpty" then
    local kept = {}
    for _, line in ipairs(lines) do
      if _trim(line) ~= "" then
        kept[#kept + 1] = line
      end
    end
    lines = kept
  elseif op == "trim" then
    local trimmed = {}
    for _, line in ipairs(lines) do
      trimmed[#trimmed + 1] = _trim(line)
    end
    lines = trimmed
  elseif op == "number" then
    local numbered = {}
    for i, line in ipairs(lines) do
      numbered[i] = i .. ". " .. line
    end
    lines = numbered
  elseif op == "reverse" then
    local reversed = {}
    for i = #lines, 1, -1 do
      reversed[#reversed + 1] = lines[i]
    end
    lines = reversed
  else
    return nil, "未知操作: " .. op
  end
  return table.concat(lines, "\n")
end

local function applyOp(op, label)
  clearError()
  state.set("hasResult", false)
  local text = state.get("lineInput") or ""
  if text == "" then
    setError("请输入要处理的文本")
    return nil
  end
  local res, err = _process(op, text)
  if res == nil then
    setError(err)
    return nil
  end
  local inLines = _splitLines(text)
  local outLines = _splitLines(res)
  state.set("lineResult", res)
  state.set("statsText", "输入 " .. #inLines .. " 行 -> 输出 " .. #outLines
      .. " 行 (" .. label .. ")")
  state.set("hasResult", true)
  dialog.toast(label .. " 完成")
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("lineInput", "")
  state.set("lineResult", "")
  state.set("statsText", "")
  state.set("hasResult", false)
  clearError()
end

function opSortAsc() applyOp("sortAsc", "升序排序") end
function opSortDesc() applyOp("sortDesc", "降序排序") end
function opDedupe() applyOp("dedupe", "去重") end
function opKeepNonEmpty() applyOp("keepNonEmpty", "去空行") end
function opTrim() applyOp("trim", "去首尾空白") end
function opNumber() applyOp("number", "加行号") end
function opReverse() applyOp("reverse", "倒序") end

function pasteInput()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("lineInput", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
