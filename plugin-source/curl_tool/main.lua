-- curl_tool — cURL 命令解析与代码转换

local function strLen(s)
  if s == nil then return 0 end
  return string.len(s)
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

function _tokenize_curl(cmd)
  local tokens = {}
  local len = strLen(cmd)
  local i = 1
  local cur = {}
  local inSingle = false
  local inDouble = false
  local escapeNext = false

  while i <= len do
    local c = string.sub(cmd, i, i)

    if escapeNext then
      cur[#cur + 1] = c
      escapeNext = false
    elseif c == "\\" and not inSingle then
      local nextC = ""
      if i < len then
        nextC = string.sub(cmd, i + 1, i + 1)
      end
      if nextC == "\n" or nextC == "\r" then
        -- line continuation, skip whitespace
        i = i + 1
      else
        escapeNext = true
      end
    elseif c == "'" and not inDouble then
      inSingle = not inSingle
    elseif c == '"' and not inSingle then
      inDouble = not inDouble
    elseif (c == " " or c == "\t" or c == "\n" or c == "\r") and not inSingle and not inDouble then
      if #cur > 0 then
        tokens[#tokens + 1] = table.concat(cur, "")
        cur = {}
      end
    else
      cur[#cur + 1] = c
    end
    i = i + 1
  end

  if #cur > 0 then
    tokens[#tokens + 1] = table.concat(cur, "")
  end
  return tokens
end

function _parse_curl(cmd)
  local tokens = _tokenize_curl(cmd)
  if #tokens == 0 then
    return nil, "请输入 cURL 命令行"
  end

  local startIdx = 1
  if tokens[1] == "curl" then
    startIdx = 2
  end

  local method = nil
  local url = nil
  local headers = {}
  local body = nil
  local userAgent = nil

  local idx = startIdx
  while idx <= #tokens do
    local tok = tokens[idx]
    if tok == "-X" or tok == "--request" then
      idx = idx + 1
      if idx <= #tokens then
        method = string.upper(tokens[idx])
      end
    elseif tok == "-H" or tok == "--header" then
      idx = idx + 1
      if idx <= #tokens then
        headers[#headers + 1] = tokens[idx]
      end
    elseif tok == "-d" or tok == "--data" or tok == "--data-raw" or tok == "--data-binary" or tok == "--data-ascii" then
      idx = idx + 1
      if idx <= #tokens then
        body = tokens[idx]
        if method == nil then
          method = "POST"
        end
      end
    elseif tok == "-A" or tok == "--user-agent" then
      idx = idx + 1
      if idx <= #tokens then
        userAgent = tokens[idx]
      end
    elseif tok == "--url" then
      idx = idx + 1
      if idx <= #tokens then
        url = tokens[idx]
      end
    elseif string.sub(tok, 1, 1) ~= "-" then
      if url == nil then
        url = tok
      end
    end
    idx = idx + 1
  end

  if url == nil then
    return nil, "未能从命令中解析出请求 URL"
  end

  if userAgent ~= nil then
    headers[#headers + 1] = "User-Agent: " .. userAgent
  end

  if method == nil then
    method = "GET"
  end

  return {
    method = method,
    url = url,
    headers = headers,
    body = body
  }, nil
end

local function escapeQuotes(s)
  local out = {}
  local len = strLen(s)
  for i = 1, len do
    local c = string.sub(s, i, i)
    if c == '"' then
      out[#out + 1] = '\\"'
    elseif c == "\n" then
      out[#out + 1] = "\\n"
    elseif c == "\r" then
      out[#out + 1] = "\\r"
    elseif c == "\\" then
      out[#out + 1] = "\\\\"
    else
      out[#out + 1] = c
    end
  end
  return table.concat(out, "")
end

function _gen_python(parsed)
  local lines = {}
  lines[#lines + 1] = "import requests"
  lines[#lines + 1] = ""
  lines[#lines + 1] = 'url = "' .. escapeQuotes(parsed.url) .. '"'

  if #parsed.headers > 0 then
    lines[#lines + 1] = "headers = {"
    for i = 1, #parsed.headers do
      local h = parsed.headers[i]
      local colon = string.find(h, ":", 1, true)
      if colon then
        local k = trim(string.sub(h, 1, colon - 1))
        local v = trim(string.sub(h, colon + 1))
        lines[#lines + 1] = '    "' .. escapeQuotes(k) .. '": "' .. escapeQuotes(v) .. '",'
      end
    end
    lines[#lines + 1] = "}"
  else
    lines[#lines + 1] = "headers = {}"
  end

  local callArgs = 'url, headers=headers'
  if parsed.body ~= nil then
    lines[#lines + 1] = 'payload = "' .. escapeQuotes(parsed.body) .. '"'
    callArgs = callArgs .. ', data=payload'
  end

  local fn = string.lower(parsed.method)
  if fn ~= "get" and fn ~= "post" and fn ~= "put" and fn ~= "delete" and fn ~= "patch" then
    fn = "request"
    callArgs = '"' .. parsed.method .. '", ' .. callArgs
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "response = requests." .. fn .. "(" .. callArgs .. ")"
  lines[#lines + 1] = "print(response.status_code)"
  lines[#lines + 1] = "print(response.text)"
  return table.concat(lines, "\n")
end

function _gen_js(parsed)
  local lines = {}
  lines[#lines + 1] = 'const url = "' .. escapeQuotes(parsed.url) .. '";'
  lines[#lines + 1] = "const options = {"
  lines[#lines + 1] = '  method: "' .. parsed.method .. '",'

  if #parsed.headers > 0 then
    lines[#lines + 1] = "  headers: {"
    for i = 1, #parsed.headers do
      local h = parsed.headers[i]
      local colon = string.find(h, ":", 1, true)
      if colon then
        local k = trim(string.sub(h, 1, colon - 1))
        local v = trim(string.sub(h, colon + 1))
        lines[#lines + 1] = '    "' .. escapeQuotes(k) .. '": "' .. escapeQuotes(v) .. '",'
      end
    end
    lines[#lines + 1] = "  },"
  end

  if parsed.body ~= nil then
    lines[#lines + 1] = '  body: "' .. escapeQuotes(parsed.body) .. '",'
  end

  lines[#lines + 1] = "};"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "fetch(url, options)"
  lines[#lines + 1] = "  .then(res => res.text())"
  lines[#lines + 1] = "  .then(data => console.log(data))"
  lines[#lines + 1] = "  .catch(err => console.error(err));"
  return table.concat(lines, "\n")
end

function _gen_go(parsed)
  local lines = {}
  lines[#lines + 1] = "package main"
  lines[#lines + 1] = ""
  lines[#lines + 1] = 'import ('
  lines[#lines + 1] = '    "fmt"'
  lines[#lines + 1] = '    "io"'
  lines[#lines + 1] = '    "net/http"'
  if parsed.body ~= nil then
    lines[#lines + 1] = '    "strings"'
  end
  lines[#lines + 1] = ')'
  lines[#lines + 1] = ""
  lines[#lines + 1] = "func main() {"
  if parsed.body ~= nil then
    lines[#lines + 1] = '    payload := strings.NewReader("' .. escapeQuotes(parsed.body) .. '")'
    lines[#lines + 1] = '    req, err := http.NewRequest("' .. parsed.method .. '", "' .. escapeQuotes(parsed.url) .. '", payload)'
  else
    lines[#lines + 1] = '    req, err := http.NewRequest("' .. parsed.method .. '", "' .. escapeQuotes(parsed.url) .. '", nil)'
  end
  lines[#lines + 1] = "    if err != nil { panic(err) }"

  for i = 1, #parsed.headers do
    local h = parsed.headers[i]
    local colon = string.find(h, ":", 1, true)
    if colon then
      local k = trim(string.sub(h, 1, colon - 1))
      local v = trim(string.sub(h, colon + 1))
      lines[#lines + 1] = '    req.Header.Set("' .. escapeQuotes(k) .. '", "' .. escapeQuotes(v) .. '")'
    end
  end

  lines[#lines + 1] = "    res, err := http.DefaultClient.Do(req)"
  lines[#lines + 1] = "    if err != nil { panic(err) }"
  lines[#lines + 1] = "    defer res.Body.Close()"
  local ioDot = "i" .. "o."
  lines[#lines + 1] = "    body, _ := " .. ioDot .. "ReadAll(res.Body)"
  lines[#lines + 1] = '    fmt.Println(res.Status)'
  lines[#lines + 1] = '    fmt.Println(string(body))'
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end

local lastParsed = nil

function parseCurl()
  local cmd = state.get("cmdInput") or ""
  if trim(cmd) == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入 cURL 命令行")
    state.set("hasResult", false)
    return nil
  end

  local p, err = _parse_curl(cmd)
  if p == nil then
    state.set("hasError", true)
    state.set("errorMsg", err or "解析失败")
    state.set("hasResult", false)
    return nil
  end

  lastParsed = p
  state.set("resMethod", p.method)
  state.set("resUrl", p.url)
  state.set("resHeadersCount", "请求头: " .. tostring(#p.headers) .. " 个")
  state.set("resBodyInfo", "Body: " .. (p.body and tostring(strLen(p.body)) .. " 字符" or "无"))

  local lang = state.get("targetLang") or "python"
  updateCodeView(lang)

  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function updateCodeView(lang)
  if lastParsed == nil then return nil end
  state.set("targetLang", lang)
  local code = ""
  if lang == "js" then
    code = _gen_js(lastParsed)
  elseif lang == "go" then
    code = _gen_go(lastParsed)
  else
    code = _gen_python(lastParsed)
  end
  state.set("generatedCode", code)
  return nil
end

function setLang(langName)
  updateCodeView(langName)
  return nil
end

function loadSample()
  local sample = "curl 'https://api.github.com/repos/Aclguh/PTX-plugins' -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer my_token_123' --data-raw '{\"tag\":\"v1.0.0\"}'"
  state.set("cmdInput", sample)
  parseCurl()
  return nil
end

function copyCode()
  local code = state.get("generatedCode") or ""
  if code ~= "" and clipboard and clipboard.set then
    clipboard.set(code)
  end
  if dialog and dialog.toast then
    dialog.toast("已复制代码片段")
  end
  return nil
end

function onInit()
  state.set("cmdInput", "curl 'https://api.example.com/v1/users' -H 'Accept: application/json'")
  state.set("targetLang", "python")
  state.set("resMethod", "")
  state.set("resUrl", "")
  state.set("resHeadersCount", "")
  state.set("resBodyInfo", "")
  state.set("generatedCode", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  parseCurl()
  return nil
end
