-- crc32_tool — CRC32 校验 (IEEE 802.3, 反射多项式 EDB88320)
-- 沙箱无位运算, 逐位以纯算术模拟 xor/shift; 输入按 UTF-8 字节序列计算,
-- 沙箱字符串为字符语义, 故显式做码点 -> UTF-8 编码 (与 qr_tool 同源)

local MAX_INPUT = 65536
local POLY = 3988292384 -- 0xEDB88320

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

local function bitxor(a, b)
  local r, bitv = 0, 1
  while a > 0 or b > 0 do
    local ab, bb = a % 2, b % 2
    if ab ~= bb then r = r + bitv end
    a = (a - ab) / 2
    b = (b - bb) / 2
    bitv = bitv * 2
  end
  return r
end

-- 码点 -> UTF-8 字节数组 (含代理对重组与孤立代理替换)
local function strBytes(s)
  local out = {}
  local n = string.len(s)
  local i = 1
  while i <= n do
    local c = string.byte(s, i)
    if c >= 55296 and c <= 56319 and i + 1 <= n then
      local d = string.byte(s, i + 1)
      if d >= 56320 and d <= 57343 then
        local cp = 65536 + (c - 55296) * 1024 + (d - 56320)
        out[#out + 1] = 240 + math.floor(cp / 262144)
        out[#out + 1] = 128 + math.floor(cp / 4096) % 64
        out[#out + 1] = 128 + math.floor(cp / 64) % 64
        out[#out + 1] = 128 + cp % 64
        i = i + 2
      else
        out[#out + 1] = 239
        out[#out + 1] = 191
        out[#out + 1] = 189
        i = i + 1
      end
    elseif c >= 55296 then
      if c <= 57343 then
        out[#out + 1] = 239
        out[#out + 1] = 191
        out[#out + 1] = 189
        i = i + 1
      else
        out[#out + 1] = c
        i = i + 1
      end
    elseif c < 128 then
      out[#out + 1] = c
      i = i + 1
    elseif c < 2048 then
      out[#out + 1] = 192 + math.floor(c / 64)
      out[#out + 1] = 128 + c % 64
      i = i + 1
    else
      out[#out + 1] = 224 + math.floor(c / 4096)
      out[#out + 1] = 128 + math.floor(c / 64) % 64
      out[#out + 1] = 128 + c % 64
      i = i + 1
    end
  end
  return out
end

-- 查表法: T[i] = 字节 i-1 独立的 8 轮反射中间值 (加载期构建, 约 6.5 万次算术)
local T = {}
for i = 0, 255 do
  local c = i
  for _ = 1, 8 do
    if c % 2 == 1 then
      c = bitxor(math.floor(c / 2), POLY)
    else
      c = math.floor(c / 2)
    end
  end
  T[i + 1] = c
end

-- UTF-8 字节序列的 CRC32 (输出已含末次取反, 与 zlib/标准 CRC32 一致)
function _crc32(text)
  local bytes = strBytes(text)
  local crc = 4294967295 -- 0xFFFFFFFF
  for _, b in ipairs(bytes) do
    local idx = bitxor(crc % 256, b) + 1
    crc = bitxor(math.floor(crc / 256), T[idx])
  end
  return bitxor(crc, 4294967295)
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _byteCount(text)
  return #strBytes(text)
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("crcInput", "")
  state.set("crcHex", "")
  state.set("crcDec", "")
  state.set("crcMeta", "")
  state.set("hasResult", false)
  clearError()
end

function computeCrc()
  clearError()
  state.set("hasResult", false)
  local text = state.get("crcInput") or ""
  if text == "" then
    setError("请输入要计算校验值的文本")
    return nil
  end
  if string.len(text) > MAX_INPUT then
    setError("输入过长: 一次最多计算 " .. MAX_INPUT .. " 个字符")
    return nil
  end
  local crc = _crc32(text)
  state.set("crcHex", string.format("%08X", crc))
  state.set("crcDec", string.format("%d", crc))
  state.set("crcMeta", "输入 " .. _byteCount(text) .. " 字节 (UTF-8) · IEEE CRC32")
  state.set("hasResult", true)
end

function pasteInput()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("crcInput", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
