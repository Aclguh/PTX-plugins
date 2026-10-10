-- protobuf_decoder_tool: Protobuf 二进制逆向解析器

local function hexCharToVal(b)
  if b >= 48 and b <= 57 then
    return b - 48
  end
  if b >= 65 and b <= 70 then
    return b - 55
  end
  if b >= 97 and b <= 102 then
    return b - 87
  end
  return nil
end

local function cleanHex(raw)
  local bytes = {}
  local len = string.len(raw)
  local hexChars = {}
  local i = 1
  while i <= len do
    local b = string.byte(raw, i)
    local v = hexCharToVal(b)
    if v ~= nil then
      hexChars[#hexChars + 1] = v
    end
    i = i + 1
  end

  local total = #hexChars
  local j = 1
  while j + 1 <= total do
    local high = hexChars[j]
    local low = hexChars[j + 1]
    bytes[#bytes + 1] = (high * 16) + low
    j = j + 2
  end
  return bytes
end

local function bytesToHex(bytes, startIdx, count)
  local hexStr = ""
  local k = 0
  while k < count do
    local idx = startIdx + k
    if idx <= #bytes then
      local b = bytes[idx]
      local h1 = math.floor(b / 16)
      local h2 = b % 16
      local function toH(n)
        if n < 10 then return string.char(n + 48) end
        return string.char(n + 87)
      end
      hexStr = hexStr .. toH(h1) .. toH(h2)
    end
    k = k + 1
  end
  return hexStr
end

local function bytesToAscii(bytes, startIdx, count)
  local isPrintable = true
  local str = ""
  local k = 0
  while k < count do
    local idx = startIdx + k
    if idx <= #bytes then
      local b = bytes[idx]
      if b >= 32 and b <= 126 then
        str = str .. string.char(b)
      else
        isPrintable = false
        break
      end
    end
    k = k + 1
  end
  if isPrintable and string.len(str) > 0 then
    return str
  end
  return nil
end

local function parseVarint(bytes, pos)
  local val = 0
  local shift = 1
  local i = pos
  local bytesRead = 0
  while i <= #bytes and bytesRead < 10 do
    local b = bytes[i]
    bytesRead = bytesRead + 1
    local part = b % 128
    val = val + (part * shift)
    shift = shift * 128
    i = i + 1
    if b < 128 then
      return val, i
    end
  end
  return nil, pos
end

local function parseProtoMessage(bytes, startPos, endPos, depth)
  if depth > 4 then
    return nil
  end
  local fields = {}
  local pos = startPos
  while pos <= endPos do
    local key, nextPos = parseVarint(bytes, pos)
    if key == nil then
      return nil
    end
    pos = nextPos
    local fieldNum = math.floor(key / 8)
    local wireType = key % 8
    if fieldNum == 0 then
      return nil
    end

    if wireType == 0 then
      -- Varint
      local val, vPos = parseVarint(bytes, pos)
      if val == nil then return nil end
      pos = vPos
      fields[#fields + 1] = {
        num = fieldNum,
        wire = "0 (Varint)",
        val = tostring(val),
        repr = tostring(val)
      }
    elseif wireType == 1 then
      -- 64-bit
      if pos + 8 - 1 > endPos then return nil end
      local hex = bytesToHex(bytes, pos, 8)
      pos = pos + 8
      fields[#fields + 1] = {
        num = fieldNum,
        wire = "1 (64-bit)",
        val = hex,
        repr = "0x" .. hex
      }
    elseif wireType == 2 then
      -- Length-delimited
      local len, lPos = parseVarint(bytes, pos)
      if len == nil or (lPos + len - 1) > endPos then return nil end
      local payloadStart = lPos
      local payloadEnd = lPos + len - 1
      pos = lPos + len

      local ascii = bytesToAscii(bytes, payloadStart, len)
      local subFields = parseProtoMessage(bytes, payloadStart, payloadEnd, depth + 1)
      local reprStr = ""
      if subFields ~= nil and #subFields > 0 then
        reprStr = "Message { " .. tostring(#subFields) .. " fields }"
      elseif ascii ~= nil then
        reprStr = '"' .. ascii .. '"'
      else
        reprStr = "bytes[" .. tostring(len) .. "] 0x" .. bytesToHex(bytes, payloadStart, len)
      end

      fields[#fields + 1] = {
        num = fieldNum,
        wire = "2 (Length-delimited, " .. tostring(len) .. " B)",
        val = bytesToHex(bytes, payloadStart, len),
        repr = reprStr,
        sub = subFields
      }
    elseif wireType == 5 then
      -- 32-bit
      if pos + 4 - 1 > endPos then return nil end
      local hex = bytesToHex(bytes, pos, 4)
      pos = pos + 4
      fields[#fields + 1] = {
        num = fieldNum,
        wire = "5 (32-bit)",
        val = hex,
        repr = "0x" .. hex
      }
    else
      -- 未知 wire type
      return nil
    end
  end
  return fields
end

local function formatFieldsOutput(fields, indent)
  local out = ""
  local i = 1
  while i <= #fields do
    local f = fields[i]
    out = out .. indent .. "Field #" .. tostring(f.num) .. " [" .. f.wire .. "]: " .. f.repr .. "\n"
    if f.sub ~= nil and #f.sub > 0 then
      out = out .. formatFieldsOutput(f.sub, indent .. "  ")
    end
    i = i + 1
  end
  return out
end

function decode()
  local raw = state.get("hexInput")
  if raw == nil or string.len(raw) == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入十六进制字节流 (如 089601120774657374696e67)")
    state.set("hasResult", false)
    return nil
  end

  local bytes = cleanHex(raw)
  if #bytes == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "未提取到有效的十六进制字节")
    state.set("hasResult", false)
    return nil
  end

  local fields = parseProtoMessage(bytes, 1, #bytes, 0)
  if fields == nil or #fields == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "无法解析为有效 Protobuf 载荷 (检查是否缺少字节或截断)")
    state.set("hasResult", false)
    return nil
  end

  state.set("hasError", false)
  state.set("errorMsg", "")
  state.set("hasResult", true)

  local formatted = formatFieldsOutput(fields, "")
  state.set("outputDisplay", formatted)
  state.set("fieldCount", #fields)
  state.set("totalBytes", #bytes)
  return nil
end

function onInit()
  -- 样例: Field 1 (Varint 150), Field 2 (String "testing")
  state.set("hexInput", "089601120774657374696e67")
  state.set("outputDisplay", "")
  state.set("fieldCount", 0)
  state.set("totalBytes", 0)
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  decode()
  return nil
end

function setSample(name)
  if name == "nested" then
    -- Field 1: string "Alice", Field 2: embedded Message { Field 1: varint 28, Field 2: string "Engineer" }
    state.set("hexInput", "0a05416c696365120c081c1208456e67696e656572")
  elseif name == "coords" then
    -- Field 1: fixed32, Field 2: fixed32
    state.set("hexInput", "0d0000803f1500000040")
  else
    -- 基础用户: Field 1: 150, Field 2: "testing"
    state.set("hexInput", "089601120774657374696e67")
  end
  decode()
  return nil
end

function copyResult()
  local res = state.get("outputDisplay")
  if res ~= nil then
    clipboard.set(res)
    dialog.toast("已复制 Protobuf 解析结构")
  end
  return nil
end

function clearAll()
  state.set("hexInput", "")
  state.set("hasResult", false)
  state.set("outputDisplay", "")
  state.set("fieldCount", 0)
  return nil
end
