-- csv_tool — CSV 与 JSON 互转
-- RFC4180 风格解析: 引号字段可含分隔符/换行, "" 为转义引号, 兼容 CRLF;
-- 分隔符可选 逗号/分号/制表符; JSON 列序取键名字典序 (沙箱无序遍历保证)

local DELIMS = { ",", ";", "\t" }
local DELIM_LBLS = { "逗号", "分号", "制表符" }
local delimIdx = 1
local hasHeader = true

local MAX_INPUT = 20000
local MAX_ROWS = 500
local MAX_COLS = 50

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

local function currentDelim()
  return DELIMS[delimIdx]
end

-- 整段文本 -> 行数组 (每行为字段数组); 引号字段可跨行
function _parseCsv(text, delim)
  local rows = {}
  local row = {}
  local field = ""
  local inQuotes = false
  local n = string.len(text)
  local i = 1
  while i <= n do
    local c = string.sub(text, i, i)
    if inQuotes then
      if c == '"' then
        if string.sub(text, i + 1, i + 1) == '"' then
          field = field .. '"'
          i = i + 1
        else
          inQuotes = false
        end
      else
        field = field .. c
      end
    else
      if c == '"' then
        if field == "" then
          inQuotes = true
        else
          field = field .. c
        end
      else
        if c == delim then
          row[#row + 1] = field
          field = ""
        else
          if c == "\r" then
            -- 兼容 CRLF, 单独丢弃
          else
            if c == "\n" then
              row[#row + 1] = field
              field = ""
              rows[#rows + 1] = row
              row = {}
            else
              field = field .. c
            end
          end
        end
      end
    end
    i = i + 1
  end
  if field ~= "" then
    row[#row + 1] = field
  end
  if #row > 0 then
    rows[#rows + 1] = row
  end
  return rows
end

-- CSV 文本 -> JSON 数组串; 非法返回 nil, err
function _csvToJson(text, delim, useHeader)
  local rows = _parseCsv(text, delim)
  if #rows == 0 then
    return nil, "没有可解析的数据行"
  end
  if #rows > MAX_ROWS then
    return nil, "行数超过上限 (" .. #rows .. " > " .. MAX_ROWS .. ")"
  end
  local headers = nil
  local firstIdx = 1
  if useHeader then
    headers = rows[1]
    firstIdx = 2
    if #headers > MAX_COLS then
      return nil, "列数超过上限 (" .. #headers .. " > " .. MAX_COLS .. ")"
    end
  end
  local out = {}
  for r = firstIdx, #rows do
    local row = rows[r]
    local isEmpty = false
    if #row == 1 then
      if row[1] == "" then isEmpty = true end
    end
    if not isEmpty then
      local item = {}
      if useHeader then
        for c = 1, #headers do
          local v = row[c]
          if v == nil then v = "" end
          item[headers[c]] = v
        end
      else
        for c = 1, #row do
          item[c] = row[c]
        end
      end
      out[#out + 1] = item
    end
  end
  local ok, encoded = pcall(json.encode, out)
  if not ok then
    return nil, "JSON 序列化失败"
  end
  return encoded
end

-- 单元格值 -> 文本
local function cellText(v)
  if type(v) == "string" then return v end
  if type(v) == "number" then return tostring(v) end
  if type(v) == "boolean" then
    if v then return "true" end
    return "false"
  end
  return ""
end

-- 字段 -> CSV 转义后的字段
function _csvField(v, delim)
  local needQuote = false
  if string.find(v, delim, 1, true) ~= nil then needQuote = true end
  if string.find(v, '"', 1, true) ~= nil then needQuote = true end
  if string.find(v, "\n", 1, true) ~= nil then needQuote = true end
  if string.find(v, "\r", 1, true) ~= nil then needQuote = true end
  if not needQuote then
    return v
  end
  local chars = {}
  for i = 1, string.len(v) do
    local c = string.sub(v, i, i)
    if c == '"' then
      chars[#chars + 1] = '""'
    else
      chars[#chars + 1] = c
    end
  end
  return '"' .. table.concat(chars) .. '"'
end

local function csvRow(fields, delim)
  local parts = {}
  for i = 1, #fields do
    parts[i] = _csvField(fields[i], delim)
  end
  return table.concat(parts, delim)
end

-- JSON 数组 -> CSV 文本; 非法返回 nil, err
function _jsonToCsv(text, delim, useHeader)
  local ok, data = pcall(json.decode, text)
  if not ok then
    return nil, "JSON 解析失败: " .. tostring(data)
  end
  if type(data) ~= "table" then
    return nil, "顶层必须是 JSON 数组"
  end
  local n = #data
  if n == 0 then
    return nil, "数组为空"
  end
  if n > MAX_ROWS then
    return nil, "行数超过上限 (" .. n .. " > " .. MAX_ROWS .. ")"
  end
  local lines = {}
  if useHeader then
    local first = data[1]
    if type(first) ~= "table" then
      return nil, "开启表头时首行必须是 JSON 对象"
    end
    local headers = {}
    for k, _ in pairs(first) do
      if type(k) == "string" then
        headers[#headers + 1] = k
      end
    end
    table.sort(headers)
    if #headers == 0 then
      return nil, "首行对象没有字段"
    end
    if #headers > MAX_COLS then
      return nil, "列数超过上限 (" .. #headers .. " > " .. MAX_COLS .. ")"
    end
    lines[1] = csvRow(headers, delim)
    for r = 1, n do
      local item = data[r]
      if type(item) ~= "table" then
        return nil, "第 " .. r .. " 行必须是 JSON 对象"
      end
      local row = {}
      for c = 1, #headers do
        row[c] = cellText(item[headers[c]])
      end
      lines[#lines + 1] = csvRow(row, delim)
    end
  else
    for r = 1, n do
      local item = data[r]
      local row = {}
      if type(item) ~= "table" then
        row[1] = cellText(item)
      else
        for c = 1, #item do
          row[c] = cellText(item[c])
        end
      end
      lines[#lines + 1] = csvRow(row, delim)
    end
  end
  return table.concat(lines, "\n")
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("csvInput", "")
  state.set("delimLbl", "分隔符: 逗号")
  state.set("headerLbl", "表头: 开")
  state.set("resultText", "")
  state.set("hasResult", false)
  clearError()
end

function cycleDelim()
  delimIdx = delimIdx % #DELIMS + 1
  state.set("delimLbl", "分隔符: " .. DELIM_LBLS[delimIdx])
end

function toggleHeader()
  hasHeader = not hasHeader
  local lbl = "表头: 开"
  if not hasHeader then
    lbl = "表头: 关"
  end
  state.set("headerLbl", lbl)
end

function csvToJson()
  clearError()
  state.set("hasResult", false)
  local text = state.get("csvInput") or ""
  if text == "" then
    setError("请输入 CSV 文本")
    return nil
  end
  if string.len(text) > MAX_INPUT then
    setError("输入过长 (最多 " .. MAX_INPUT .. " 字符)")
    return nil
  end
  local res, err = _csvToJson(text, currentDelim(), hasHeader)
  if res == nil then
    setError(err)
    return nil
  end
  state.set("resultText", res)
  state.set("hasResult", true)
  dialog.toast("CSV 转 JSON 完成")
end

function jsonToCsv()
  clearError()
  state.set("hasResult", false)
  local text = state.get("csvInput") or ""
  if text == "" then
    setError("请输入 JSON 文本")
    return nil
  end
  if string.len(text) > MAX_INPUT then
    setError("输入过长 (最多 " .. MAX_INPUT .. " 字符)")
    return nil
  end
  local res, err = _jsonToCsv(text, currentDelim(), hasHeader)
  if res == nil then
    setError(err)
    return nil
  end
  state.set("resultText", res)
  state.set("hasResult", true)
  dialog.toast("JSON 转 CSV 完成")
end

function pasteInput()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("csvInput", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
