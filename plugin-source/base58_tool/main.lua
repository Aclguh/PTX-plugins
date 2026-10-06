local B58_CHARS = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
local B58_MAP = {}
for i = 1, 58 do
  local ch = string.sub(B58_CHARS, i, i)
  B58_MAP[ch] = i - 1
end

local B32_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
local B32_MAP = {}
for i = 1, 32 do
  local ch = string.sub(B32_CHARS, i, i)
  B32_MAP[ch] = i - 1
end

local HEX_CHARS = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f" }

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

local function str_to_utf8_bytes(s)
  local bytes = {}
  local len = string.len(s)
  local i = 1
  while i <= len do
    local c = string.byte(s, i)
    local cp = c
    if c >= 55296 and c <= 56319 and i + 1 <= len then
      local d = string.byte(s, i + 1)
      if d >= 56320 and d <= 57343 then
        cp = 65536 + (c - 55296) * 1024 + (d - 56320)
        i = i + 1
      end
    end
    i = i + 1

    if cp < 128 then
      bytes[#bytes + 1] = cp
    elseif cp < 2048 then
      bytes[#bytes + 1] = 192 | (cp >> 6)
      bytes[#bytes + 1] = 128 | (cp & 63)
    elseif cp < 65536 then
      bytes[#bytes + 1] = 224 | (cp >> 12)
      bytes[#bytes + 1] = 128 | ((cp >> 6) & 63)
      bytes[#bytes + 1] = 128 | (cp & 63)
    else
      bytes[#bytes + 1] = 240 | (cp >> 18)
      bytes[#bytes + 1] = 128 | ((cp >> 12) & 63)
      bytes[#bytes + 1] = 128 | ((cp >> 6) & 63)
      bytes[#bytes + 1] = 128 | (cp & 63)
    end
  end
  return bytes
end

local function utf8_bytes_to_str(bytes)
  local out = {}
  local len = #bytes
  local i = 1
  while i <= len do
    local b1 = bytes[i]
    if b1 < 128 then
      out[#out + 1] = string.char(b1)
      i = i + 1
    elseif b1 >= 192 and b1 <= 223 and i + 1 <= len then
      local b2 = bytes[i + 1]
      local cp = ((b1 & 31) << 6) | (b2 & 63)
      out[#out + 1] = codepoint_to_char(cp)
      i = i + 2
    elseif b1 >= 224 and b1 <= 239 and i + 2 <= len then
      local b2 = bytes[i + 1]
      local b3 = bytes[i + 2]
      local cp = ((b1 & 15) << 12) | ((b2 & 63) << 6) | (b3 & 63)
      out[#out + 1] = codepoint_to_char(cp)
      i = i + 3
    elseif b1 >= 240 and b1 <= 247 and i + 3 <= len then
      local b2 = bytes[i + 1]
      local b3 = bytes[i + 2]
      local b4 = bytes[i + 3]
      local cp = ((b1 & 7) << 18) | ((b2 & 63) << 12) | ((b3 & 63) << 6) | (b4 & 63)
      out[#out + 1] = codepoint_to_char(cp)
      i = i + 4
    else
      out[#out + 1] = "?"
      i = i + 1
    end
  end
  return table.concat(out, "")
end

local function bytes_to_hex(bytes)
  local out = {}
  for i = 1, #bytes do
    local b = bytes[i]
    out[#out + 1] = HEX_CHARS[(b >> 4) + 1]
    out[#out + 1] = HEX_CHARS[(b & 15) + 1]
  end
  return table.concat(out, "")
end

function _b58_encode(bytes)
  local n = #bytes
  if n == 0 then
    return ""
  end

  local zeroes = 0
  while zeroes < n and bytes[zeroes + 1] == 0 do
    zeroes = zeroes + 1
  end

  local digits = { 0 }
  for i = zeroes + 1, n do
    local carry = bytes[i]
    for j = 1, #digits do
      carry = carry + (digits[j] << 8)
      digits[j] = carry % 58
      carry = math.floor(carry / 58)
    end
    while carry > 0 do
      digits[#digits + 1] = carry % 58
      carry = math.floor(carry / 58)
    end
  end

  local res = {}
  for i = 1, zeroes do
    res[#res + 1] = "1"
  end
  for i = #digits, 1, -1 do
    local val = digits[i]
    res[#res + 1] = string.sub(B58_CHARS, val + 1, val + 1)
  end
  return table.concat(res, "")
end

function _b58_decode(s)
  local len = string.len(s)
  if len == 0 then
    return {}
  end

  local zeroes = 0
  while zeroes < len and string.sub(s, zeroes + 1, zeroes + 1) == "1" do
    zeroes = zeroes + 1
  end

  local decoded = { 0 }
  for i = zeroes + 1, len do
    local ch = string.sub(s, i, i)
    local val = B58_MAP[ch]
    if val == nil then
      return nil, "非法 Base58 字符: " .. ch
    end
    local carry = val
    for j = 1, #decoded do
      carry = carry + decoded[j] * 58
      decoded[j] = carry & 255
      carry = carry >> 8
    end
    while carry > 0 do
      decoded[#decoded + 1] = carry & 255
      carry = carry >> 8
    end
  end

  local res_bytes = {}
  for i = 1, zeroes do
    res_bytes[#res_bytes + 1] = 0
  end
  for i = #decoded, 1, -1 do
    res_bytes[#res_bytes + 1] = decoded[i]
  end
  return res_bytes, nil
end

function _b32_encode(bytes)
  local n = #bytes
  if n == 0 then
    return ""
  end
  local res = {}
  local buffer = 0
  local bitsLeft = 0

  for i = 1, n do
    buffer = (buffer << 8) | bytes[i]
    bitsLeft = bitsLeft + 8
    while bitsLeft >= 5 do
      bitsLeft = bitsLeft - 5
      local idx = (buffer >> bitsLeft) & 31
      res[#res + 1] = string.sub(B32_CHARS, idx + 1, idx + 1)
    end
  end

  if bitsLeft > 0 then
    local idx = (buffer << (5 - bitsLeft)) & 31
    res[#res + 1] = string.sub(B32_CHARS, idx + 1, idx + 1)
  end

  while (#res % 8) ~= 0 do
    res[#res + 1] = "="
  end

  return table.concat(res, "")
end

function _b32_decode(s)
  local len = string.len(s)
  if len == 0 then
    return {}
  end
  local res = {}
  local buffer = 0
  local bitsLeft = 0

  for i = 1, len do
    local ch = string.sub(s, i, i)
    if ch ~= "=" and ch ~= " " and ch ~= "\n" and ch ~= "\r" then
      local upperCh = string.upper(ch)
      local val = B32_MAP[upperCh]
      if val == nil then
        return nil, "非法 Base32 字符: " .. ch
      end
      buffer = (buffer << 5) | val
      bitsLeft = bitsLeft + 5
      if bitsLeft >= 8 then
        bitsLeft = bitsLeft - 8
        res[#res + 1] = (buffer >> bitsLeft) & 255
      end
    end
  end

  return res, nil
end

local function update_result(out_str, hex_str, mode_name, byte_count)
  state.set("output", out_str)
  state.set("hexOutput", hex_str)
  state.set("hasResult", true)
  state.set("modeDesc", "模式: " .. mode_name .. " | 字节数: " .. tostring(byte_count))
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function encodeBase58()
  local input = state.get("input") or ""
  if input == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入需要编码的文本")
    return nil
  end
  local bytes = str_to_utf8_bytes(input)
  local b58 = _b58_encode(bytes)
  local hex = bytes_to_hex(bytes)
  update_result(b58, hex, "Base58 (Bitcoin)", #bytes)
  return nil
end

function decodeBase58()
  local input = state.get("input") or ""
  if input == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入 Base58 字符串")
    return nil
  end
  local bytes, err = _b58_decode(input)
  if err ~= nil then
    state.set("hasError", true)
    state.set("errorMsg", err)
    return nil
  end
  local text = utf8_bytes_to_str(bytes)
  local hex = bytes_to_hex(bytes)
  update_result(text, hex, "Base58 解码", #bytes)
  return nil
end

function encodeBase32()
  local input = state.get("input") or ""
  if input == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入需要编码的文本")
    return nil
  end
  local bytes = str_to_utf8_bytes(input)
  local b32 = _b32_encode(bytes)
  local hex = bytes_to_hex(bytes)
  update_result(b32, hex, "Base32 (RFC 4648)", #bytes)
  return nil
end

function decodeBase32()
  local input = state.get("input") or ""
  if input == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入 Base32 字符串")
    return nil
  end
  local bytes, err = _b32_decode(input)
  if err ~= nil then
    state.set("hasError", true)
    state.set("errorMsg", err)
    return nil
  end
  local text = utf8_bytes_to_str(bytes)
  local hex = bytes_to_hex(bytes)
  update_result(text, hex, "Base32 解码", #bytes)
  return nil
end

function copyResult()
  local out = state.get("output") or ""
  if out ~= "" then
    clipboard.set(out)
    dialog.toast("已复制结果")
  end
  return nil
end

function copyHex()
  local hex = state.get("hexOutput") or ""
  if hex ~= "" then
    clipboard.set(hex)
    dialog.toast("已复制 Hex")
  end
  return nil
end

function pasteInput()
  clipboard.get(function(text)
    if text ~= nil and text ~= "" then
      state.set("input", text)
      encodeBase58()
      dialog.toast("已粘贴并执行 Base58 编码")
    end
    return nil
  end)
  return nil
end

function clearAll()
  state.set("input", "")
  state.set("output", "")
  state.set("hexOutput", "")
  state.set("hasResult", false)
  state.set("modeDesc", "")
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function onInit()
  state.set("input", "Hello World")
  state.set("output", "")
  state.set("hexOutput", "")
  state.set("hasResult", false)
  state.set("modeDesc", "")
  state.set("hasError", false)
  state.set("errorMsg", "")
  encodeBase58()
  return nil
end
