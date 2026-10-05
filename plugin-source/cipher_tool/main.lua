-- cipher_tool — 文本加密
-- 凯撒/维吉尼亚仅作用于英文字母 (其余字符原样保留, 大小写不变);
-- XOR 基于 UTF-8 字节流, 输出小写十六进制, 密钥为任意非空文本;
-- 非字节字符经 JSON \u 转义构造 (string.char 仅接受 0..255)

local CAESAR_SHIFTS = { 1, 3, 13, 25 }
local shiftIdx = 2 -- 默认 3
local MAX_LEN = 2000

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

-- ---------------- 凯撒 ----------------
-- dir: 1 加密 / -1 解密
function _caesar(text, shift, dir)
  local s = shift % 26
  local out = {}
  for i = 1, string.len(text) do
    local cp = string.byte(text, i)
    local c = cp
    if cp >= 65 and cp <= 90 then
      c = ((cp - 65 + dir * s) % 26) + 65
    else
      if cp >= 97 and cp <= 122 then
        c = ((cp - 97 + dir * s) % 26) + 97
      end
    end
    out[i] = string.char(c)
  end
  return table.concat(out)
end

-- ---------------- 维吉尼亚 ----------------
-- 密钥过滤出英文字母 -> 0..25 偏移数组; 空数组表示密钥非法
function _keyLetters(key)
  local letters = {}
  for i = 1, string.len(key) do
    local cp = string.byte(key, i)
    if cp >= 65 and cp <= 90 then
      letters[#letters + 1] = cp - 65
    else
      if cp >= 97 and cp <= 122 then
        letters[#letters + 1] = cp - 97
      end
    end
  end
  return letters
end

function _vigenere(text, key, dir)
  local letters = _keyLetters(key)
  if #letters == 0 then
    return nil, "密钥必须包含至少一个英文字母"
  end
  local klen = #letters
  local kidx = 0
  local out = {}
  for i = 1, string.len(text) do
    local cp = string.byte(text, i)
    local c = cp
    if cp >= 65 and cp <= 90 then
      kidx = kidx % klen + 1
      c = ((cp - 65 + dir * letters[kidx]) % 26) + 65
    else
      if cp >= 97 and cp <= 122 then
        kidx = kidx % klen + 1
        c = ((cp - 97 + dir * letters[kidx]) % 26) + 97
      end
    end
    out[i] = string.char(c)
  end
  return table.concat(out)
end

-- ---------------- XOR (UTF-8 字节级) ----------------
-- 字符串 -> UTF-8 字节数组; string.byte 返回码点 (emoji 为代理码元, 需重组)
function _utf8Bytes(s)
  local bytes = {}
  local n = string.len(s)
  local i = 1
  while i <= n do
    local cp = string.byte(s, i)
    if cp >= 55296 and cp <= 56319 then
      local lo = string.byte(s, i + 1)
      if lo ~= nil then
        if lo >= 56320 and lo <= 57343 then
          cp = 65536 + (cp - 55296) * 1024 + (lo - 56320)
          i = i + 1
        end
      end
    end
    if cp < 128 then
      bytes[#bytes + 1] = cp
    else
      if cp < 2048 then
        bytes[#bytes + 1] = 192 + math.floor(cp / 64)
        bytes[#bytes + 1] = 128 + (cp % 64)
      else
        if cp < 65536 then
          bytes[#bytes + 1] = 224 + math.floor(cp / 4096)
          bytes[#bytes + 1] = 128 + math.floor(cp / 64) % 64
          bytes[#bytes + 1] = 128 + (cp % 64)
        else
          bytes[#bytes + 1] = 240 + math.floor(cp / 262144)
          bytes[#bytes + 1] = 128 + math.floor(cp / 4096) % 64
          bytes[#bytes + 1] = 128 + math.floor(cp / 64) % 64
          bytes[#bytes + 1] = 128 + (cp % 64)
        end
      end
    end
    i = i + 1
  end
  return bytes
end

-- UTF-8 字节数组 -> 字符串 (非 ASCII 码点经 JSON \u 转义构造)
function _stringFromUtf8Bytes(bytes)
  local parts = {}
  local n = #bytes
  local i = 1
  while i <= n do
    local b = bytes[i]
    local cp = nil
    local adv = 1
    if b < 128 then
      cp = b
    else
      if b >= 192 and b < 224 then
        local c1 = bytes[i + 1]
        if c1 ~= nil then
          if c1 >= 128 and c1 < 192 then
            cp = (b - 192) * 64 + (c1 - 128)
            adv = 2
          end
        end
      else
        if b >= 224 and b < 240 then
          local c1 = bytes[i + 1]
          local c2 = bytes[i + 2]
          if c1 ~= nil and c2 ~= nil then
            if c1 >= 128 and c1 < 192 and c2 >= 128 and c2 < 192 then
              cp = (b - 224) * 4096 + (c1 - 128) * 64 + (c2 - 128)
              adv = 3
            end
          end
        else
          if b >= 240 and b < 248 then
            local c1 = bytes[i + 1]
            local c2 = bytes[i + 2]
            local c3 = bytes[i + 3]
            if c1 ~= nil and c2 ~= nil and c3 ~= nil then
              if c1 >= 128 and c1 < 192 and c2 >= 128 and c2 < 192 and c3 >= 128 and c3 < 192 then
                cp = (b - 240) * 262144 + (c1 - 128) * 4096 + (c2 - 128) * 64 + (c3 - 128)
                adv = 4
              end
            end
          end
        end
      end
    end
    if cp == nil then
      -- 非法序列: 以 '?' 占位并前进一个字节
      parts[#parts + 1] = "?"
      cp = 63
      adv = 1
    end
    if cp < 128 then
      parts[#parts + 1] = string.char(cp)
    else
      local esc
      if cp < 65536 then
        esc = string.format("\\u%04X", cp)
      else
        local v = cp - 65536
        local hi = 55296 + math.floor(v / 1024)
        local lo = 56320 + (v % 1024)
        esc = string.format("\\u%04X\\u%04X", hi, lo)
      end
      local ok, ch = pcall(json.decode, '"' .. esc .. '"')
      if ok then
        parts[#parts + 1] = ch
      else
        parts[#parts + 1] = "?"
      end
    end
    i = i + adv
  end
  return table.concat(parts)
end

local function xorBytes(bytes, keyBytes)
  local klen = #keyBytes
  local out = {}
  for i = 1, #bytes do
    -- 沙箱无位运算库: XOR 拆 8 位逐位计算
    local a = bytes[i] % 256
    local b = keyBytes[(i - 1) % klen + 1] % 256
    local v = 0
    local bit = 1
    for _ = 1, 8 do
      local ab = a % 2
      local bb = b % 2
      if ab ~= bb then
        v = v + bit
      end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      bit = bit * 2
    end
    out[i] = v
  end
  return out
end

function _bytesToHex(bytes)
  local digits = "0123456789abcdef"
  local out = {}
  for i = 1, #bytes do
    local b = bytes[i] % 256
    local hi = math.floor(b / 16)
    local lo = b % 16
    out[i] = string.sub(digits, hi + 1, hi + 1) .. string.sub(digits, lo + 1, lo + 1)
  end
  return table.concat(out)
end

-- 十六进制串 -> 字节数组; 非法返回 nil
function _hexToBytes(h)
  local n = string.len(h)
  if n % 2 ~= 0 then return nil end
  local out = {}
  for i = 1, n, 2 do
    local hi = tonumber(string.sub(h, i, i), 16)
    local lo = tonumber(string.sub(h, i + 1, i + 1), 16)
    if hi == nil then return nil end
    if lo == nil then return nil end
    out[#out + 1] = hi * 16 + lo
  end
  return out
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _xorHex(text, key, dir)
  if dir == 1 then
    local bytes = _utf8Bytes(text)
    local keyBytes = _utf8Bytes(key)
    return _bytesToHex(xorBytes(bytes, keyBytes))
  end
  local bytes = _hexToBytes(text)
  if bytes == nil then return nil end
  local keyBytes = _utf8Bytes(key)
  return _stringFromUtf8Bytes(xorBytes(bytes, keyBytes))
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("cipherInput", "")
  state.set("cipherKey", "")
  state.set("caesarLbl", "凯撒平移: 3")
  state.set("resultText", "")
  state.set("hasResult", false)
  clearError()
end

function cycleCaesar()
  shiftIdx = shiftIdx % #CAESAR_SHIFTS + 1
  state.set("caesarLbl", "凯撒平移: " .. CAESAR_SHIFTS[shiftIdx])
end

local function currentShift()
  return CAESAR_SHIFTS[shiftIdx]
end

local function runEnc(label, fn)
  clearError()
  state.set("hasResult", false)
  local text = state.get("cipherInput") or ""
  local key = state.get("cipherKey") or ""
  if text == "" then
    setError("请输入要处理的文本")
    return nil
  end
  if string.len(text) > MAX_LEN then
    setError("文本过长 (最多 " .. MAX_LEN .. " 字符)")
    return nil
  end
  local res, err = fn(text, key)
  if res == nil then
    setError(err)
    return nil
  end
  state.set("resultText", res)
  state.set("hasResult", true)
  dialog.toast(label .. " 完成")
end

function caesarEnc()
  runEnc("凯撒加密", function(text, _key)
    return _caesar(text, currentShift(), 1)
  end)
end

function caesarDec()
  runEnc("凯撒解密", function(text, _key)
    return _caesar(text, currentShift(), -1)
  end)
end

function vigEnc()
  runEnc("维吉尼亚加密", function(text, key)
    return _vigenere(text, key, 1)
  end)
end

function vigDec()
  runEnc("维吉尼亚解密", function(text, key)
    return _vigenere(text, key, -1)
  end)
end

function xorEnc()
  runEnc("XOR 加密", function(text, key)
    if key == "" then
      return nil, "XOR 需要密钥"
    end
    return _xorHex(text, key, 1)
  end)
end

function xorDec()
  runEnc("XOR 解密", function(text, key)
    if key == "" then
      return nil, "XOR 需要密钥"
    end
    local res = _xorHex(text, key, -1)
    if res == nil then
      return nil, "十六进制格式不合法 (需偶数长度的 0-9a-f)"
    end
    return res
  end)
end

function pasteInput()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("cipherInput", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
