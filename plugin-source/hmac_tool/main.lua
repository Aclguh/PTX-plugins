-- hmac_tool — HMAC 消息认证码计算 (SHA256 / SHA1 / MD5)
-- 纯算法实现，字节级高保真计算，支持 Hex 小写/大写与 Base64 输出

local K256 = {
  1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221,
  3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580,
  3835390401, 4022224774, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986,
  2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711, 113926993, 338241895,
  666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, 2177026350, 2456956037,
  2730485921, 2820302411, 3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344,
  430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779,
  1955562222, 2024104815, 2227730452, 2361852424, 2428436474, 2756734187, 3204031479, 3329325298
}

local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function ror(x, n)
  return ((x >> n) | (x << (32 - n))) & 4294967295
end

local function rol(x, n)
  return ((x << n) | (x >> (32 - n))) & 4294967295
end

local function strBytes(s)
  local bytes = {}
  local len = string.len(s)
  for i = 1, len do
    local c = string.byte(s, i)
    if c <= 127 then
      bytes[#bytes + 1] = c
    elseif c <= 2047 then
      bytes[#bytes + 1] = 192 + math.floor(c / 64)
      bytes[#bytes + 1] = 128 + (c % 64)
    else
      bytes[#bytes + 1] = 224 + math.floor(c / 4096)
      bytes[#bytes + 1] = 128 + (math.floor(c / 64) % 64)
      bytes[#bytes + 1] = 128 + (c % 64)
    end
  end
  return bytes
end

local function sha256_bytes(bytes)
  local total_len = #bytes
  local bit_len = total_len * 8

  local padded = {}
  for i = 1, total_len do padded[i] = bytes[i] end
  padded[#padded + 1] = 128
  while (#padded % 64) ~= 56 do
    padded[#padded + 1] = 0
  end

  local high_bits = (bit_len >> 32) & 4294967295
  local low_bits = bit_len & 4294967295
  for i = 3, 0, -1 do
    padded[#padded + 1] = (high_bits >> (i * 8)) & 255
  end
  for i = 3, 0, -1 do
    padded[#padded + 1] = (low_bits >> (i * 8)) & 255
  end

  local h = {
    1779033703, 3144134277, 1013904242, 2773480762,
    1359893119, 2600822924, 528734635, 1541459225
  }

  local num_blocks = math.floor(#padded / 64)
  for b = 0, num_blocks - 1 do
    local offset = b * 64
    local w = {}
    for i = 0, 15 do
      local idx = offset + i * 4
      w[i] = ((padded[idx + 1] << 24) | (padded[idx + 2] << 16) | (padded[idx + 3] << 8) | padded[idx + 4]) & 4294967295
    end
    for i = 16, 63 do
      local s0 = (ror(w[i - 15], 7) ~ ror(w[i - 15], 18) ~ (w[i - 15] >> 3)) & 4294967295
      local s1 = (ror(w[i - 2], 17) ~ ror(w[i - 2], 19) ~ (w[i - 2] >> 10)) & 4294967295
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 4294967295
    end

    local a, b_val, c, d, e, f, g, h_val = h[1], h[2], h[3], h[4], h[5], h[6], h[7], h[8]

    for i = 0, 63 do
      local S1 = (ror(e, 6) ~ ror(e, 11) ~ ror(e, 25)) & 4294967295
      local ch = ((e & f) ~ ((~e) & g)) & 4294967295
      local temp1 = (h_val + S1 + ch + K256[i + 1] + w[i]) & 4294967295
      local S0 = (ror(a, 2) ~ ror(a, 13) ~ ror(a, 22)) & 4294967295
      local maj = ((a & b_val) ~ (a & c) ~ (b_val & c)) & 4294967295
      local temp2 = (S0 + maj) & 4294967295

      h_val = g
      g = f
      f = e
      e = (d + temp1) & 4294967295
      d = c
      c = b_val
      b_val = a
      a = (temp1 + temp2) & 4294967295
    end

    h[1] = (h[1] + a) & 4294967295
    h[2] = (h[2] + b_val) & 4294967295
    h[3] = (h[3] + c) & 4294967295
    h[4] = (h[4] + d) & 4294967295
    h[5] = (h[5] + e) & 4294967295
    h[6] = (h[6] + f) & 4294967295
    h[7] = (h[7] + g) & 4294967295
    h[8] = (h[8] + h_val) & 4294967295
  end

  local res = {}
  for i = 1, 8 do
    local val = h[i]
    res[#res + 1] = (val >> 24) & 255
    res[#res + 1] = (val >> 16) & 255
    res[#res + 1] = (val >> 8) & 255
    res[#res + 1] = val & 255
  end
  return res
end

local function sha1_bytes(bytes)
  local total_len = #bytes
  local bit_len = total_len * 8

  local padded = {}
  for i = 1, total_len do padded[i] = bytes[i] end
  padded[#padded + 1] = 128
  while (#padded % 64) ~= 56 do
    padded[#padded + 1] = 0
  end

  local high_bits = (bit_len >> 32) & 4294967295
  local low_bits = bit_len & 4294967295
  for i = 3, 0, -1 do
    padded[#padded + 1] = (high_bits >> (i * 8)) & 255
  end
  for i = 3, 0, -1 do
    padded[#padded + 1] = (low_bits >> (i * 8)) & 255
  end

  local h0 = 1732584193
  local h1 = 4023233417
  local h2 = 2562383102
  local h3 = 271733878
  local h4 = 3285377520

  local num_blocks = math.floor(#padded / 64)
  for b = 0, num_blocks - 1 do
    local offset = b * 64
    local w = {}
    for i = 0, 15 do
      local idx = offset + i * 4
      w[i] = ((padded[idx + 1] << 24) | (padded[idx + 2] << 16) | (padded[idx + 3] << 8) | padded[idx + 4]) & 4294967295
    end
    for i = 16, 79 do
      w[i] = rol((w[i - 3] ~ w[i - 8] ~ w[i - 14] ~ w[i - 16]) & 4294967295, 1)
    end

    local a, b_val, c, d, e = h0, h1, h2, h3, h4

    for i = 0, 79 do
      local f = 0
      local k = 0
      if i <= 19 then
        f = ((b_val & c) | ((~b_val) & d)) & 4294967295
        k = 1518500249
      elseif i <= 39 then
        f = (b_val ~ c ~ d) & 4294967295
        k = 1859775393
      elseif i <= 59 then
        f = ((b_val & c) | (b_val & d) | (c & d)) & 4294967295
        k = 2400959708
      else
        f = (b_val ~ c ~ d) & 4294967295
        k = 3395469782
      end

      local temp = (rol(a, 5) + f + e + k + w[i]) & 4294967295
      e = d
      d = c
      c = rol(b_val, 30)
      b_val = a
      a = temp
    end

    h0 = (h0 + a) & 4294967295
    h1 = (h1 + b_val) & 4294967295
    h2 = (h2 + c) & 4294967295
    h3 = (h3 + d) & 4294967295
    h4 = (h4 + e) & 4294967295
  end

  local res = {}
  local words = { h0, h1, h2, h3, h4 }
  for i = 1, 5 do
    local val = words[i]
    res[#res + 1] = (val >> 24) & 255
    res[#res + 1] = (val >> 16) & 255
    res[#res + 1] = (val >> 8) & 255
    res[#res + 1] = val & 255
  end
  return res
end

local function raw_hmac(key_bytes, msg_bytes, hash_fn, block_size)
  if #key_bytes > block_size then
    key_bytes = hash_fn(key_bytes)
  end
  local k_pad = {}
  for i = 1, block_size do
    k_pad[i] = key_bytes[i] or 0
  end
  local k_ipad = {}
  local k_opad = {}
  for i = 1, block_size do
    k_ipad[i] = k_pad[i] ~ 54
    k_opad[i] = k_pad[i] ~ 92
  end
  local inner_in = {}
  for i = 1, block_size do inner_in[#inner_in + 1] = k_ipad[i] end
  for i = 1, #msg_bytes do inner_in[#inner_in + 1] = msg_bytes[i] end
  local inner_hash = hash_fn(inner_in)

  local outer_in = {}
  for i = 1, block_size do outer_in[#outer_in + 1] = k_opad[i] end
  for i = 1, #inner_hash do outer_in[#outer_in + 1] = inner_hash[i] end
  return hash_fn(outer_in)
end

function _bytes_to_hex(bytes, isUpper)
  local hex_chars = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f" }
  if isUpper then
    hex_chars = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F" }
  end
  local out = {}
  for i = 1, #bytes do
    local b = bytes[i]
    local hi = (b >> 4) & 15
    local lo = b & 15
    out[#out + 1] = hex_chars[hi + 1] .. hex_chars[lo + 1]
  end
  return table.concat(out)
end

function _bytes_to_base64(bytes)
  local out = {}
  local n = #bytes
  local i = 1
  while i <= n do
    local b1 = bytes[i]
    local b2 = bytes[i + 1] or 0
    local b3 = bytes[i + 2] or 0

    local n1 = (b1 >> 2) & 63
    local n2 = (((b1 & 3) << 4) | ((b2 >> 4) & 15)) & 63
    local n3 = (((b2 & 15) << 2) | ((b3 >> 6) & 3)) & 63
    local n4 = b3 & 63

    out[#out + 1] = string.sub(B64_CHARS, n1 + 1, n1 + 1)
    out[#out + 1] = string.sub(B64_CHARS, n2 + 1, n2 + 1)
    if i + 1 <= n then
      out[#out + 1] = string.sub(B64_CHARS, n3 + 1, n3 + 1)
    else
      out[#out + 1] = "="
    end
    if i + 2 <= n then
      out[#out + 1] = string.sub(B64_CHARS, n4 + 1, n4 + 1)
    else
      out[#out + 1] = "="
    end
    i = i + 3
  end
  return table.concat(out)
end

function _hmac_sha256(key_str, msg_str)
  local kb = strBytes(key_str)
  local mb = strBytes(msg_str)
  local digest = raw_hmac(kb, mb, sha256_bytes, 64)
  return _bytes_to_hex(digest, false)
end

function _hmac_sha1(key_str, msg_str)
  local kb = strBytes(key_str)
  local mb = strBytes(msg_str)
  local digest = raw_hmac(kb, mb, sha1_bytes, 64)
  return _bytes_to_hex(digest, false)
end

local ALGO_LIST = { "SHA256", "SHA1" }
local FORMAT_LIST = { "Hex (小写)", "Hex (大写)", "Base64" }

function cycleAlgo()
  local cur = state.get("algo") or "SHA256"
  if cur == "SHA256" then
    state.set("algo", "SHA1")
  else
    state.set("algo", "SHA256")
  end
  calculate()
  return nil
end

function cycleFormat()
  local cur = state.get("format") or "Hex (小写)"
  if cur == "Hex (小写)" then
    state.set("format", "Hex (大写)")
  elseif cur == "Hex (大写)" then
    state.set("format", "Base64")
  else
    state.set("format", "Hex (小写)")
  end
  calculate()
  return nil
end

function calculate()
  local key = state.get("key") or ""
  local msg = state.get("message") or ""

  if string.len(key) == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入密钥 (Key)")
    state.set("hasResult", false)
    return nil
  end

  local algo = state.get("algo") or "SHA256"
  local fmt = state.get("format") or "Hex (小写)"

  local kb = strBytes(key)
  local mb = strBytes(msg)

  local digest = nil
  if algo == "SHA1" then
    digest = raw_hmac(kb, mb, sha1_bytes, 64)
  else
    digest = raw_hmac(kb, mb, sha256_bytes, 64)
  end

  local res = ""
  if fmt == "Hex (大写)" then
    res = _bytes_to_hex(digest, true)
  elseif fmt == "Base64" then
    res = _bytes_to_base64(digest)
  else
    res = _bytes_to_hex(digest, false)
  end

  state.set("hasError", false)
  state.set("errorMsg", "")
  state.set("result", res)
  state.set("resultLabel", "HMAC-" .. algo .. " (" .. fmt .. ")")
  state.set("hasResult", true)
  return nil
end

function clearAll()
  state.set("key", "")
  state.set("message", "")
  state.set("result", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function pasteMessage()
  clipboard.get(function(text)
    if text ~= nil then
      state.set("message", text)
      calculate()
    end
    return nil
  end)
  return nil
end

function onInit()
  state.set("key", "")
  state.set("message", "")
  state.set("algo", "SHA256")
  state.set("format", "Hex (小写)")
  state.set("result", "")
  state.set("resultLabel", "HMAC 结果")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end
