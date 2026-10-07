-- md_table_tool — Markdown 表格格式化与对齐

local function strLen(s)
  if s == nil then return 0 end
  return string.len(s)
end

local function max(a, b)
  if a > b then return a else return b end
end

local function trim(s)
  if s == nil then return "" end
  local len = strLen(s)
  local i = 1
  while i <= len do
    local c = string.sub(s, i, i)
    if c ~= " " and c ~= "\t" and c ~= "\r" and c ~= "\n" then
      break
    end
    i = i + 1
  end
  local j = len
  while j >= i do
    local c = string.sub(s, j, j)
    if c ~= " " and c ~= "\t" and c ~= "\r" and c ~= "\n" then
      break
    end
    j = j - 1
  end
  if i > j then return "" end
  return string.sub(s, i, j)
end

local function splitLines(s)
  local lines = {}
  if s == nil or s == "" then return lines end
  local start = 1
  local len = strLen(s)
  while start <= len do
    local nl = string.find(s, "\n", start, true)
    if not nl then
      local line = string.sub(s, start)
      if strLen(line) > 0 and string.sub(line, strLen(line), strLen(line)) == "\r" then
        line = string.sub(line, 1, strLen(line) - 1)
      end
      lines[#lines + 1] = line
      break
    end
    local line = string.sub(s, start, nl - 1)
    if strLen(line) > 0 and string.sub(line, strLen(line), strLen(line)) == "\r" then
      line = string.sub(line, 1, strLen(line) - 1)
    end
    lines[#lines + 1] = line
    start = nl + 1
  end
  return lines
end

function _char_width(cp)
  if cp == nil then return 1 end
  if cp <= 127 then return 1 end
  -- CJK Symbols and Punctuation (12288..12351)
  if cp >= 12288 and cp <= 12351 then return 2 end
  -- Hiragana, Katakana, Bopomofo, CJK Unified Ideographs (11904..40959)
  if cp >= 11904 and cp <= 40959 then return 2 end
  -- Hangul Syllables (44032..55215)
  if cp >= 44032 and cp <= 55215 then return 2 end
  -- CJK Compatibility Ideographs (63744..64255)
  if cp >= 63744 and cp <= 64255 then return 2 end
  -- Fullwidth Forms (65281..65376)
  if cp >= 65281 and cp <= 65376 then return 2 end
  return 1
end

function _display_width(s)
  if s == nil or s == "" then return 0 end
  local w = 0
  local len = strLen(s)
  for i = 1, len do
    local cp = string.byte(s, i)
    w = w + _char_width(cp)
  end
  return w
end

local function splitCells(line, sep)
  local cells = {}
  local start = 1
  local len = strLen(line)
  while start <= len do
    local pos = string.find(line, sep, start, true)
    if not pos then
      cells[#cells + 1] = string.sub(line, start)
      break
    end
    cells[#cells + 1] = string.sub(line, start, pos - 1)
    start = pos + strLen(sep)
  end
  return cells
end

local function parseMarkdownRow(line)
  local trimmed = trim(line)
  if trimmed == "" then return nil end
  if string.sub(trimmed, 1, 1) == "|" then
    trimmed = string.sub(trimmed, 2)
  end
  if strLen(trimmed) > 0 and string.sub(trimmed, strLen(trimmed), strLen(trimmed)) == "|" then
    trimmed = string.sub(trimmed, 1, strLen(trimmed) - 1)
  end

  local rawCells = splitCells(trimmed, "|")
  local cells = {}
  for i = 1, #rawCells do
    cells[i] = trim(rawCells[i])
  end
  return cells
end

function _is_delimiter_cell(cell)
  local t = trim(cell)
  if strLen(t) < 3 then return false end
  for i = 1, strLen(t) do
    local c = string.sub(t, i, i)
    if c ~= "-" and c ~= ":" then
      return false
    end
  end
  return true
end

function _cell_alignment(cell)
  local t = trim(cell)
  local hasLeft = (string.sub(t, 1, 1) == ":")
  local hasRight = (strLen(t) > 1 and string.sub(t, strLen(t), strLen(t)) == ":")
  if hasLeft and hasRight then
    return "center"
  elseif hasRight then
    return "right"
  else
    return "left"
  end
end

local function makeSpaces(n)
  if n <= 0 then return "" end
  local t = {}
  for i = 1, n do
    t[i] = " "
  end
  return table.concat(t, "")
end

local function padCell(text, targetWidth, align)
  local w = _display_width(text)
  local diff = targetWidth - w
  if diff <= 0 then return text end

  if align == "right" then
    return makeSpaces(diff) .. text
  elseif align == "center" then
    local leftPad = math.floor(diff / 2)
    local rightPad = diff - leftPad
    return makeSpaces(leftPad) .. text .. makeSpaces(rightPad)
  else
    return text .. makeSpaces(diff)
  end
end

function _format_markdown_table(inputStr)
  local lines = splitLines(inputStr)
  if #lines == 0 then
    return nil, "请输入 Markdown 表格文本"
  end

  local rows = {}
  local delimRowIdx = nil
  for i = 1, #lines do
    local l = lines[i]
    local parsed = parseMarkdownRow(l)
    if parsed ~= nil and #parsed > 0 then
      rows[#rows + 1] = parsed
      local isDelim = true
      for c = 1, #parsed do
        if not _is_delimiter_cell(parsed[c]) then
          isDelim = false
          break
        end
      end
      if isDelim and delimRowIdx == nil then
        delimRowIdx = #rows
      end
    end
  end

  if #rows == 0 then
    return nil, "未识别到有效的表格行"
  end

  local colCount = 0
  for i = 1, #rows do
    colCount = max(colCount, #rows[i])
  end

  local colWidths = {}
  local colAlign = {}
  for c = 1, colCount do
    colWidths[c] = 3
    colAlign[c] = "left"
  end

  if delimRowIdx ~= nil then
    local dRow = rows[delimRowIdx]
    for c = 1, colCount do
      if dRow[c] ~= nil and _is_delimiter_cell(dRow[c]) then
        colAlign[c] = _cell_alignment(dRow[c])
      end
    end
  end

  for r = 1, #rows do
    if r ~= delimRowIdx then
      local row = rows[r]
      for c = 1, colCount do
        local cellText = row[c] or ""
        local w = _display_width(cellText)
        colWidths[c] = max(colWidths[c], w)
      end
    end
  end

  local outLines = {}
  for r = 1, #rows do
    if r == delimRowIdx then
      local dCells = {}
      for c = 1, colCount do
        local w = colWidths[c]
        local align = colAlign[c]
        if align == "center" then
          local dashes = w - 2
          if dashes < 1 then dashes = 1 end
          local dStr = {}
          for di = 1, dashes do dStr[di] = "-" end
          dCells[c] = ":" .. table.concat(dStr, "") .. ":"
        elseif align == "right" then
          local dashes = w - 1
          if dashes < 1 then dashes = 1 end
          local dStr = {}
          for di = 1, dashes do dStr[di] = "-" end
          dCells[c] = table.concat(dStr, "") .. ":"
        else
          local dStr = {}
          for di = 1, w do dStr[di] = "-" end
          dCells[c] = table.concat(dStr, "")
        end
      end
      outLines[#outLines + 1] = "| " .. table.concat(dCells, " | ") .. " |"
    else
      local row = rows[r]
      local padded = {}
      for c = 1, colCount do
        local cellText = row[c] or ""
        local align = colAlign[c]
        padded[c] = padCell(cellText, colWidths[c], align)
      end
      outLines[#outLines + 1] = "| " .. table.concat(padded, " | ") .. " |"

      if delimRowIdx == nil and r == 1 then
        local dCells = {}
        for c = 1, colCount do
          local dStr = {}
          for di = 1, colWidths[c] do dStr[di] = "-" end
          dCells[c] = table.concat(dStr, "")
        end
        outLines[#outLines + 1] = "| " .. table.concat(dCells, " | ") .. " |"
      end
    end
  end

  return table.concat(outLines, "\n"), nil
end

function _tsv_to_table(inputStr)
  local lines = splitLines(inputStr)
  if #lines == 0 then
    return nil, "请输入制表符分隔内容"
  end

  local mdLines = {}
  for i = 1, #lines do
    local l = lines[i]
    if trim(l) ~= "" then
      local cells = splitCells(l, "\t")
      local clean = {}
      for ci = 1, #cells do
        clean[ci] = trim(cells[ci])
      end
      mdLines[#mdLines + 1] = "| " .. table.concat(clean, " | ") .. " |"
      if i == 1 then
        local delim = {}
        for ci = 1, #cells do
          delim[ci] = "---"
        end
        mdLines[#mdLines + 1] = "| " .. table.concat(delim, " | ") .. " |"
      end
    end
  end

  if #mdLines == 0 then
    return nil, "未识别到内容"
  end
  return _format_markdown_table(table.concat(mdLines, "\n"))
end

function formatTable()
  local src = state.get("inputText") or ""
  if trim(src) == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入待排版的 Markdown 表格")
    state.set("hasResult", false)
    return nil
  end

  local res, err = _format_markdown_table(src)
  if res == nil then
    state.set("hasError", true)
    state.set("errorMsg", err or "格式化失败")
    state.set("hasResult", false)
    return nil
  end

  state.set("resultText", res)
  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function convertTsv()
  local src = state.get("inputText") or ""
  if trim(src) == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入 TSV / Excel 制表符文本")
    state.set("hasResult", false)
    return nil
  end

  local res, err = _tsv_to_table(src)
  if res == nil then
    state.set("hasError", true)
    state.set("errorMsg", err or "转换失败")
    state.set("hasResult", false)
    return nil
  end

  state.set("resultText", res)
  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function loadSample()
  local sample = "| 插件名 | 分类 | 权限 |\n|---|---|---|\n| base64_tool | encoding | clipboard |\n| cidr_tool | network | clipboard |\n| md_table_tool | text | clipboard |"
  state.set("inputText", sample)
  formatTable()
  return nil
end

function copyResult()
  local res = state.get("resultText") or ""
  if res ~= "" and clipboard and clipboard.set then
    clipboard.set(res)
  end
  if dialog and dialog.toast then
    dialog.toast("已复制对齐的表格")
  end
  return nil
end

function onInit()
  state.set("inputText", "| 姓名 | 城市 | 职务 |\n|---|---|---|\n| 张三 | 北京 | 架构师 |\n| Alice | New York | Tech Lead |")
  state.set("resultText", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  formatTable()
  return nil
end
