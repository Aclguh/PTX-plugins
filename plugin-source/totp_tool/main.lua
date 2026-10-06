-- totp_tool — 2FA / TOTP 动态验证码生成器 (RFC 6238)
-- 纯 Lua 字节级 HMAC-SHA1 + 动态截断 + Base32 解码 + 本地账号槽位存储

local B32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
local STORAGE_KEY = "totp_accounts_v1"

local function rol(x, n)
  return ((x << n) | (x >> (32 - n))) & 4294967295
end

function _base32_decode(str)
  local clean = {}
  local len = string.len(str)
  for i = 1, len do
    local c = string.byte(str, i)
    if c >= 97 and c <= 122 then c = c - 32 end -- 小写转大写
    if (c >= 65 and c <= 90) or (c >= 50 and c <= 55) then
      clean[#clean + 1] = c
    end
  end

  local val_map = {}
  for i = 1, 32 do
    val_map[string.byte(B32_ALPHABET, i)] = i - 1
  end

  local bits = 0
  local bit_count = 0
  local bytes = {}

  for _, c in ipairs(clean) do
    local val = val_map[c]
    if val ~= nil then
      bits = ((bits << 5) | val) & 4294967295
      bit_count = bit_count + 5
      while bit_count >= 8 do
        bit_count = bit_count - 8
        bytes[#bytes + 1] = (bits >> bit_count) & 255
      end
    end
  end

  return bytes
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

local function raw_hmac_sha1(key_bytes, msg_bytes)
  local block_size = 64
  if #key_bytes > block_size then
    key_bytes = sha1_bytes(key_bytes)
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
  local inner_hash = sha1_bytes(inner_in)

  local outer_in = {}
  for i = 1, block_size do outer_in[#outer_in + 1] = k_opad[i] end
  for i = 1, #inner_hash do outer_in[#outer_in + 1] = inner_hash[i] end
  return sha1_bytes(outer_in)
end

function _totp_code(secret_b32, timestamp_sec)
  local key_bytes = _base32_decode(secret_b32)
  if #key_bytes == 0 then return "" end

  local counter = math.floor(timestamp_sec / 30)
  local msg = {
    0, 0, 0, 0,
    (counter >> 24) & 255,
    (counter >> 16) & 255,
    (counter >> 8) & 255,
    counter & 255
  }

  local hash = raw_hmac_sha1(key_bytes, msg)
  local offset = (hash[20] & 15) + 1
  local bin_code = (((hash[offset] & 127) << 24) |
                    ((hash[offset + 1] & 255) << 16) |
                    ((hash[offset + 2] & 255) << 8) |
                    (hash[offset + 3] & 255)) & 2147483647
  local otp = bin_code % 1000000
  return string.format("%06d", otp)
end

local accounts = {}

local function refreshAccountsUi()
  local lines = {}
  for i, acc in ipairs(accounts) do
    lines[#lines + 1] = string.format("[%d] %s (密钥: %s)", i, acc.name or "未命名", acc.secret or "")
  end
  state.set("accountsList", table.concat(lines, "\n"))
  state.set("hasAccounts", #accounts > 0)
end

local function saveAccountsToStorage()
  local str = json.encode(accounts)
  storage.set(STORAGE_KEY, str)
  refreshAccountsUi()
end

function generate()
  local secret = state.get("secret") or ""
  if string.len(secret) == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入 Base32 密钥 (如 JBSWY3DPEHPK3PXP)")
    state.set("hasResult", false)
    return nil
  end

  local kb = _base32_decode(secret)
  if #kb == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "无效的 Base32 密钥格式")
    state.set("hasResult", false)
    return nil
  end

  local now = util.timestamp()
  local code = _totp_code(secret, now)
  local remain = 30 - (now % 30)

  state.set("hasError", false)
  state.set("errorMsg", "")
  state.set("otpCode", code)
  state.set("remainingSec", string.format("本周期剩余 %d 秒", remain))
  state.set("hasResult", true)
  return nil
end

function saveAccount()
  local secret = state.get("secret") or ""
  local name = state.get("accountName") or ""
  if string.len(secret) == 0 then
    dialog.toast("请先输入密钥")
    return nil
  end
  if string.len(name) == 0 then
    name = "账号 " .. (#accounts + 1)
  end

  accounts[#accounts + 1] = { name = name, secret = secret }
  saveAccountsToStorage()
  dialog.toast("账号已保存")
  return nil
end

function clearAccounts()
  accounts = {}
  saveAccountsToStorage()
  dialog.toast("已清空已存账号")
  return nil
end

function clearAll()
  state.set("secret", "")
  state.set("accountName", "")
  state.set("otpCode", "")
  state.set("remainingSec", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function pasteSecret()
  clipboard.get(function(text)
    if text ~= nil then
      state.set("secret", text)
      generate()
    end
    return nil
  end)
  return nil
end

function onInit()
  state.set("secret", "JBSWY3DPEHPK3PXP")
  state.set("accountName", "GitHub Demo")
  state.set("otpCode", "")
  state.set("remainingSec", "")
  state.set("accountsList", "")
  state.set("hasAccounts", false)
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")

  storage.get(STORAGE_KEY, function(val)
    if val ~= nil and string.len(val) > 0 then
      local ok, res = pcall(json.decode, val)
      if ok and type(res) == "table" then
        accounts = res
        refreshAccountsUi()
      end
    end
    return nil
  end)

  generate()
  return nil
end
