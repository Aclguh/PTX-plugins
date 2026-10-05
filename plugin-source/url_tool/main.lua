-- url_tool — URL 解析器
-- 纯文本 find+sub 手写拆解 (沙箱无模式匹配);
-- 支持无协议输入与 IPv6 字面量主机 ([::1]:8080), 查询参数值经 urlDecode 还原

local MAX_LEN = 4000
local MAX_PARAMS = 40

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

-- 拆解查询串 -> "键 = 值" 行数组 (最多展示 MAX_PARAMS 条)
function _splitQuery(q)
  local rows = {}
  if q == "" then return rows end
  local start = 1
  while true do
    local pos = string.find(q, "&", start, true)
    local piece
    if pos == nil then
      piece = string.sub(q, start)
    else
      piece = string.sub(q, start, pos - 1)
    end
    if piece ~= "" then
      local eq = string.find(piece, "=", 1, true)
      local k = piece
      local v = ""
      if eq ~= nil then
        k = string.sub(piece, 1, eq - 1)
        v = string.sub(piece, eq + 1)
      end
      local okK, dk = pcall(codec.urlDecode, k)
      local okV, dv = pcall(codec.urlDecode, v)
      if not okK then dk = k end
      if not okV then dv = v end
      rows[#rows + 1] = dk .. " = " .. dv
      if #rows >= MAX_PARAMS then
        rows[#rows + 1] = "...（其余参数省略）"
        return rows
      end
    end
    if pos == nil then return rows end
    start = pos + 1
  end
end

-- URL -> {scheme, host, port, path, query, frag}
function _parseUrl(url)
  local rest = url
  local scheme = ""
  local p = string.find(rest, "://", 1, true)
  if p ~= nil then
    scheme = string.sub(rest, 1, p - 1)
    rest = string.sub(rest, p + 3)
  end
  local frag = ""
  p = string.find(rest, "#", 1, true)
  if p ~= nil then
    frag = string.sub(rest, p + 1)
    rest = string.sub(rest, 1, p - 1)
  end
  local query = ""
  p = string.find(rest, "?", 1, true)
  if p ~= nil then
    query = string.sub(rest, p + 1)
    rest = string.sub(rest, 1, p - 1)
  end
  local path = ""
  p = string.find(rest, "/", 1, true)
  if p ~= nil then
    path = string.sub(rest, p)
    rest = string.sub(rest, 1, p - 1)
  end
  local host = rest
  local port = ""
  if string.sub(rest, 1, 1) == "[" then
    local close = string.find(rest, "]", 1, true)
    if close ~= nil then
      host = string.sub(rest, 1, close)
      if string.sub(rest, close + 1, close + 1) == ":" then
        port = string.sub(rest, close + 2)
      end
    end
  else
    p = string.find(rest, ":", 1, true)
    if p ~= nil then
      host = string.sub(rest, 1, p - 1)
      port = string.sub(rest, p + 1)
    end
  end
  return {
    scheme = scheme,
    host = host,
    port = port,
    path = path,
    query = query,
    frag = frag
  }
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("urlInput", "")
  state.set("schemeVal", "")
  state.set("hostVal", "")
  state.set("portVal", "")
  state.set("pathVal", "")
  state.set("queryVal", "")
  state.set("fragVal", "")
  state.set("paramText", "")
  state.set("hasParsed", false)
  clearError()
end

function parseUrl()
  clearError()
  state.set("hasParsed", false)
  local input = state.get("urlInput") or ""
  if input == "" then
    setError("请输入要解析的 URL")
    return nil
  end
  if string.len(input) > MAX_LEN then
    setError("URL 过长 (最多 " .. MAX_LEN .. " 字符)")
    return nil
  end
  local parts = _parseUrl(input)
  local showScheme = parts.scheme
  if showScheme == "" then showScheme = "(未声明)" end
  local showPort = parts.port
  if showPort == "" then showPort = "(默认)" end
  local showFrag = parts.frag
  if showFrag == "" then showFrag = "(无)" end
  local showQuery = parts.query
  if showQuery == "" then showQuery = "(无)" end
  local showPath = parts.path
  if showPath == "" then showPath = "(无)" end
  state.set("schemeVal", showScheme)
  state.set("hostVal", parts.host)
  state.set("portVal", showPort)
  state.set("pathVal", showPath)
  state.set("queryVal", showQuery)
  state.set("fragVal", showFrag)
  local rows = _splitQuery(parts.query)
  local paramText = table.concat(rows, "\n")
  if paramText == "" then paramText = "(无查询参数)" end
  state.set("paramText", paramText)
  state.set("hasParsed", true)
end

function pasteInput()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("urlInput", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
