local HEX_CHARS = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f" }

local NAMED_TO_CHAR = {
  ["&amp;"] = "&",
  ["&lt;"] = "<",
  ["&gt;"] = ">",
  ["&quot;"] = "\"",
  ["&apos;"] = "'",
  ["&nbsp;"] = " ",
  ["&copy;"] = "©",
  ["&reg;"] = "®",
  ["&trade;"] = "™",
  ["&times;"] = "×",
  ["&divide;"] = "÷",
  ["&plusmn;"] = "±",
  ["&deg;"] = "°",
  ["&micro;"] = "µ",
  ["&cent;"] = "¢",
  ["&pound;"] = "£",
  ["&yen;"] = "¥",
  ["&euro;"] = "€",
  ["&sect;"] = "§",
  ["&laquo;"] = "«",
  ["&raquo;"] = "»",
  ["&hellip;"] = "…",
  ["&ndash;"] = "–",
  ["&mdash;"] = "—",
  ["&lsquo;"] = "‘",
  ["&rsquo;"] = "’",
  ["&ldquo;"] = "“",
  ["&rdquo;"] = "”",
  ["&bull;"] = "•"
}

local CHAR_TO_NAMED = {
  ["&"] = "&amp;",
  ["<"] = "&lt;",
  [">"] = "&gt;",
  ["\""] = "&quot;",
  ["'"] = "&apos;",
  ["©"] = "&copy;",
  ["®"] = "&reg;",
  ["™"] = "&trade;",
  ["×"] = "&times;",
  ["÷"] = "&divide;",
  ["±"] = "&plusmn;",
  ["°"] = "&deg;",
  ["µ"] = "&micro;",
  ["¢"] = "&cent;",
  ["£"] = "&pound;",
  ["¥"] = "&yen;",
  ["€"] = "&euro;",
  ["§"] = "&sect;",
  ["«"] = "&laquo;",
  ["»"] = "&raquo;",
  ["…"] = "&hellip;",
  ["–"] = "&ndash;",
  ["—"] = "&mdash;",
  ["‘"] = "&lsquo;",
  ["’"] = "&rsquo;",
  ["“"] = "&ldquo;",
  ["”"] = "&rdquo;",
  ["•"] = "&bull;"
}

local function to_hex_lower(n)
  if n == 0 then
    return "0"
  end
  local out = {}
  while n > 0 do
    local rem = n & 15
    out[#out + 1] = HEX_CHARS[rem + 1]
    n = n >> 4
  end
  local len = #out
  local half = len >> 1
  for i = 1, half do
    local tmp = out[i]
    out[i] = out[len - i + 1]
    out[len - i + 1] = tmp
  end
  return table.concat(out, "")
end

local function parse_hex_int(s)
  local val = 0
  local len = string.len(s)
  if len == 0 then
    return nil
  end
  for i = 1, len do
    local b = string.byte(s, i)
    local digit = 0
    if b >= 48 and b <= 57 then
      digit = b - 48
    elseif b >= 97 and b <= 102 then
      digit = b - 87
    elseif b >= 65 and b <= 70 then
      digit = b - 55
    else
      return nil
    end
    val = val * 16 + digit
  end
  return val
end

local function codepoint_to_char(cp)
  if cp < 0 or cp > 1114111 then
    return "?"
  end
  if cp >= 55296 and cp <= 57343 then
    return "?"
  end
  if cp < 128 then
    return string.char(cp)
  elseif cp < 65536 then
    return json.decode('"\\u' .. string.format("%04x", cp) .. '"')
  else
    local v = cp - 65536
    local hi = 55296 + math.floor(v / 1024)
    local lo = 56320 + (v % 1024)
    return json.decode('"\\u' .. string.format("%04x", hi) .. '\\u' .. string.format("%04x", lo) .. '"')
  end
end

local function parse_tokens(s)
  local tokens = {}
  local len = string.len(s)
  local i = 1
  while i <= len do
    local c = string.byte(s, i)
    if c >= 55296 and c <= 56319 and i + 1 <= len then
      local d = string.byte(s, i + 1)
      if d >= 56320 and d <= 57343 then
        local full_cp = 65536 + (c - 55296) * 1024 + (d - 56320)
        tokens[#tokens + 1] = { char = string.sub(s, i, i + 1), cp = full_cp }
        i = i + 2
      else
        tokens[#tokens + 1] = { char = string.sub(s, i, i), cp = c }
        i = i + 1
      end
    else
      tokens[#tokens + 1] = { char = string.sub(s, i, i), cp = c }
      i = i + 1
    end
  end
  return tokens
end

function _encode_standard(text)
  local tokens = parse_tokens(text)
  local res = {}
  for i = 1, #tokens do
    local ch = tokens[i].char
    if ch == "&" then
      res[#res + 1] = "&amp;"
    elseif ch == "<" then
      res[#res + 1] = "&lt;"
    elseif ch == ">" then
      res[#res + 1] = "&gt;"
    elseif ch == "\"" then
      res[#res + 1] = "&quot;"
    elseif ch == "'" then
      res[#res + 1] = "&#39;"
    else
      res[#res + 1] = ch
    end
  end
  return table.concat(res, "")
end

function _encode_named(text)
  local tokens = parse_tokens(text)
  local res = {}
  for i = 1, #tokens do
    local ch = tokens[i].char
    local ent = CHAR_TO_NAMED[ch]
    if ent ~= nil then
      res[#res + 1] = ent
    else
      res[#res + 1] = ch
    end
  end
  return table.concat(res, "")
end

function _encode_decimal(text)
  local tokens = parse_tokens(text)
  local res = {}
  for i = 1, #tokens do
    local tok = tokens[i]
    if tok.cp > 127 or tok.char == "&" or tok.char == "<" or tok.char == ">" or tok.char == "\"" or tok.char == "'" then
      res[#res + 1] = "&#" .. tostring(tok.cp) .. ";"
    else
      res[#res + 1] = tok.char
    end
  end
  return table.concat(res, "")
end

function _encode_hex(text)
  local tokens = parse_tokens(text)
  local res = {}
  for i = 1, #tokens do
    local tok = tokens[i]
    if tok.cp > 127 or tok.char == "&" or tok.char == "<" or tok.char == ">" or tok.char == "\"" or tok.char == "'" then
      res[#res + 1] = "&#x" .. to_hex_lower(tok.cp) .. ";"
    else
      res[#res + 1] = tok.char
    end
  end
  return table.concat(res, "")
end

function _decode_entities(text)
  local len = string.len(text)
  local res = {}
  local i = 1

  while i <= len do
    local b = string.byte(text, i)
    if b == 38 then
      local semi = string.find(text, ";", i + 1, true)
      local matched = false

      if semi ~= nil and (semi - i) <= 12 then
        local ent = string.sub(text, i, semi)

        local namedChar = NAMED_TO_CHAR[ent]
        if namedChar ~= nil then
          res[#res + 1] = namedChar
          matched = true
          i = semi + 1
        elseif string.sub(ent, 1, 3) == "&#x" or string.sub(ent, 1, 3) == "&#X" then
          local hexStr = string.sub(ent, 4, string.len(ent) - 1)
          local cp = parse_hex_int(hexStr)
          if cp ~= nil then
            res[#res + 1] = codepoint_to_char(cp)
            matched = true
            i = semi + 1
          end
        elseif string.sub(ent, 1, 2) == "&#" then
          local decStr = string.sub(ent, 3, string.len(ent) - 1)
          local cp = tonumber(decStr)
          if cp ~= nil then
            res[#res + 1] = codepoint_to_char(cp)
            matched = true
            i = semi + 1
          end
        end
      end

      if not matched then
        res[#res + 1] = "&"
        i = i + 1
      end
    else
      res[#res + 1] = string.sub(text, i, i)
      i = i + 1
    end
  end

  return table.concat(res, "")
end

local function update_result(out_str, mode_name)
  state.set("output", out_str)
  state.set("hasResult", string.len(out_str) > 0)
  state.set("modeDesc", "当前模式: " .. mode_name .. " (长度: " .. tostring(string.len(out_str)) .. " 字节)")
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function encodeStandard()
  local input = state.get("input") or ""
  if input == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入需要编码的文本")
    return nil
  end
  local res = _encode_standard(input)
  update_result(res, "基础安全转义 (< > & \" ')")
  return nil
end

function encodeNamed()
  local input = state.get("input") or ""
  if input == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入需要编码的文本")
    return nil
  end
  local res = _encode_named(input)
  update_result(res, "HTML 命名实体 (&copy; &trade; 等)")
  return nil
end

function encodeDecimal()
  local input = state.get("input") or ""
  if input == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入需要编码的文本")
    return nil
  end
  local res = _encode_decimal(input)
  update_result(res, "十进制数码实体 (&#NNN;)")
  return nil
end

function encodeHex()
  local input = state.get("input") or ""
  if input == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入需要编码的文本")
    return nil
  end
  local res = _encode_hex(input)
  update_result(res, "十六进制数码实体 (&#xHEX;)")
  return nil
end

function decodeAll()
  local input = state.get("input") or ""
  if input == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入需要解码的 HTML 实体字符串")
    return nil
  end
  local res = _decode_entities(input)
  update_result(res, "全能解码 (还原至纯文本)")
  return nil
end

function copyResult()
  local out = state.get("output") or ""
  if out ~= "" then
    clipboard.set(out)
    dialog.toast("已复制到剪贴板")
  end
  return nil
end

function pasteInput()
  clipboard.get(function(text)
    if text ~= nil and text ~= "" then
      state.set("input", text)
      decodeAll()
      dialog.toast("已粘贴并自动解码")
    end
    return nil
  end)
  return nil
end

function clearAll()
  state.set("input", "")
  state.set("output", "")
  state.set("hasResult", false)
  state.set("modeDesc", "")
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function onInit()
  state.set("input", "<div class=\"hero\">&copy; 2026 PTX &#x4e2d;&#x6587; &trade;</div>")
  state.set("output", "")
  state.set("hasResult", false)
  state.set("modeDesc", "")
  state.set("hasError", false)
  state.set("errorMsg", "")
  decodeAll()
  return nil
end
