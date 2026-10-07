-- zero_width_tool — 零宽字符隐写与文本盲水印

local function strLen(s)
  if s == nil then return 0 end
  return string.len(s)
end

local ZW0 = "\u{200B}" -- 零宽空格 (0)
local ZW1 = "\u{200C}" -- 零宽不连字 (1)
local ZWD = "\u{200D}" -- 零宽连字 (边界标识)

local HEX_CHARS = {
  "0", "1", "2", "3", "4", "5", "6", "7",
  "8", "9", "A", "B", "C", "D", "E", "F"
}

local function toHex4(n)
  local d1 = math.floor(n / 4096) % 16
  local d2 = math.floor(n / 256) % 16
  local d3 = math.floor(n / 16) % 16
  local d4 = n % 16
  return HEX_CHARS[d1 + 1] .. HEX_CHARS[d2 + 1] .. HEX_CHARS[d3 + 1] .. HEX_CHARS[d4 + 1]
end

local function charFromCodePoint(cp)
  if cp == nil then return "" end
  if cp >= 32 and cp <= 126 then
    return string.char(cp)
  end
  if cp == 10 then return "\n" end
  if cp == 9 then return "\t" end
  if cp == 13 then return "\r" end

  local ok, res = pcall(function()
    return json.decode('"\\u' .. toHex4(cp) .. '"')
  end)
  if ok and res ~= nil then
    return res
  end
  return "?"
end

function _text_to_zw(secret)
  if secret == nil or secret == "" then return "" end
  local out = { ZWD }
  local len = strLen(secret)
  for i = 1, len do
    local cp = string.byte(secret, i)
    local bits = {}
    local v = cp
    for b = 1, 16 do
      bits[17 - b] = v % 2
      v = math.floor(v / 2)
    end
    for b = 1, 16 do
      if bits[b] == 1 then
        out[#out + 1] = ZW1
      else
        out[#out + 1] = ZW0
      end
    end
  end
  out[#out + 1] = ZWD
  return table.concat(out, "")
end

function _zw_to_text(stego)
  if stego == nil or stego == "" then return "", 0 end
  local bits = {}
  local zwCount = 0
  local len = strLen(stego)

  for i = 1, len do
    local c = string.sub(stego, i, i)
    if c == ZW0 then
      bits[#bits + 1] = 0
      zwCount = zwCount + 1
    elseif c == ZW1 then
      bits[#bits + 1] = 1
      zwCount = zwCount + 1
    elseif c == ZWD then
      zwCount = zwCount + 1
    end
  end

  if #bits < 16 then
    return "", zwCount
  end

  local chars = {}
  local blockCount = math.floor(#bits / 16)
  for b = 0, blockCount - 1 do
    local cp = 0
    local base = b * 16
    for bitIdx = 1, 16 do
      cp = cp * 2 + bits[base + bitIdx]
    end
    chars[#chars + 1] = charFromCodePoint(cp)
  end

  return table.concat(chars, ""), zwCount
end

function _strip_zw(stego)
  if stego == nil or stego == "" then return "", 0 end
  local out = {}
  local stripped = 0
  local len = strLen(stego)
  for i = 1, len do
    local c = string.sub(stego, i, i)
    if c == ZW0 or c == ZW1 or c == ZWD then
      stripped = stripped + 1
    else
      out[#out + 1] = c
    end
  end
  return table.concat(out, ""), stripped
end

function encodeStego()
  local cover = state.get("coverText") or ""
  local secret = state.get("secretText") or ""

  if strLen(secret) == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入待隐藏的秘密信息")
    state.set("hasResult", false)
    return nil
  end

  local zwData = _text_to_zw(secret)
  local result = ""
  if strLen(cover) == 0 then
    result = zwData
  elseif strLen(cover) >= 1 then
    result = string.sub(cover, 1, 1) .. zwData .. string.sub(cover, 2)
  else
    result = cover .. zwData
  end

  state.set("resultText", result)
  state.set("infoText", "隐写成功！嵌入隐藏字符: " .. tostring(strLen(secret) * 16 + 2) .. " 个")
  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function decodeStego()
  local stego = state.get("coverText") or ""
  if strLen(stego) == 0 then
    stego = state.get("resultText") or ""
  end

  if strLen(stego) == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "请在上方载体文本框中粘贴含隐写水印的文本")
    state.set("hasResult", false)
    return nil
  end

  local decoded, zwCount = _zw_to_text(stego)
  if zwCount == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "未检测到任何零宽隐写字符")
    state.set("hasResult", false)
    return nil
  end

  if strLen(decoded) == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "检测到零宽字符 (" .. tostring(zwCount) .. " 个)，但不足有效信息块")
    state.set("hasResult", false)
    return nil
  end

  state.set("resultText", decoded)
  state.set("infoText", "提取成功！还原秘密文本 (解析了 " .. tostring(zwCount) .. " 个零宽字符)")
  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function stripStego()
  local stego = state.get("coverText") or ""
  if strLen(stego) == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入待清理的文本")
    state.set("hasResult", false)
    return nil
  end

  local clean, count = _strip_zw(stego)
  state.set("resultText", clean)
  state.set("infoText", "清理完成！已剔除 " .. tostring(count) .. " 个不可见零宽字符")
  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function copyResult()
  local res = state.get("resultText") or ""
  if res ~= "" and clipboard and clipboard.set then
    clipboard.set(res)
  end
  if dialog and dialog.toast then
    dialog.toast("已复制结果")
  end
  return nil
end

function onInit()
  state.set("coverText", "这是一篇关于开源社区协作规范的公开公告。")
  state.set("secretText", "SECRET:2026-KEY-9946")
  state.set("resultText", "")
  state.set("infoText", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  encodeStego()
  return nil
end
