-- color_contrast_tool: 色彩对比度与无障碍检测 (WCAG 2.1)

local function hexCharToNum(b)
  if b >= 48 then
    if b <= 57 then
      return b - 48
    end
  end
  if b >= 65 then
    if b <= 70 then
      return b - 55
    end
  end
  if b >= 97 then
    if b <= 102 then
      return b - 87
    end
  end
  return nil
end

local function parseHexColor(hexStr)
  if hexStr == nil then
    return nil
  end
  local s = hexStr
  if string.sub(s, 1, 1) == "#" then
    s = string.sub(s, 2)
  end
  local len = string.len(s)
  if len == 3 then
    local r1 = hexCharToNum(string.byte(s, 1))
    local g1 = hexCharToNum(string.byte(s, 2))
    local b1 = hexCharToNum(string.byte(s, 3))
    if r1 ~= nil and g1 ~= nil and b1 ~= nil then
      return { r = r1 * 17, g = g1 * 17, b = b1 * 17 }
    end
    return nil
  end
  if len == 6 then
    local r1 = hexCharToNum(string.byte(s, 1))
    local r2 = hexCharToNum(string.byte(s, 2))
    local g1 = hexCharToNum(string.byte(s, 3))
    local g2 = hexCharToNum(string.byte(s, 4))
    local b1 = hexCharToNum(string.byte(s, 5))
    local b2 = hexCharToNum(string.byte(s, 6))
    if r1 ~= nil and r2 ~= nil and g1 ~= nil and g2 ~= nil and b1 ~= nil and b2 ~= nil then
      return {
        r = (r1 * 16) + r2,
        g = (g1 * 16) + g2,
        b = (b1 * 16) + b2
      }
    end
    return nil
  end
  return nil
end

local function channelLuminance(val)
  local c = val / 255.0
  if c <= 0.04045 then
    return c / 12.92
  else
    return ((c + 0.055) / 1.055) ^ 2.4
  end
end

local function calcRelativeLuminance(rgb)
  local r = channelLuminance(rgb.r)
  local g = channelLuminance(rgb.g)
  local b = channelLuminance(rgb.b)
  return (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
end

function onInit()
  state.set("fgColor", "#111827")
  state.set("bgColor", "#F9FAFB")
  state.set("contrastRatio", "17.43 : 1")
  state.set("ratioNumber", 17.43)
  state.set("normalAa", "通过 (AA)")
  state.set("normalAaa", "通过 (AAA)")
  state.set("largeAa", "通过 (AA)")
  state.set("largeAaa", "通过 (AAA)")
  state.set("uiComponents", "通过 (>= 3:1)")
  state.set("fgLuminance", "0.012")
  state.set("bgLuminance", "0.963")
  state.set("hasError", false)
  state.set("errorMsg", "")
  state.set("previewText", "The quick brown fox jumps over the lazy dog. 敏捷的棕色狐狸跃过懒狗。")
  analyze()
  return nil
end

function analyze()
  local fgStr = state.get("fgColor")
  local bgStr = state.get("bgColor")
  local fgRgb = parseHexColor(fgStr)
  local bgRgb = parseHexColor(bgStr)

  if fgRgb == nil then
    state.set("hasError", true)
    state.set("errorMsg", "前景色 HEX 格式无效 (如 #111827 或 #000)")
    return nil
  end
  if bgRgb == nil then
    state.set("hasError", true)
    state.set("errorMsg", "背景色 HEX 格式无效 (如 #FFFFFF 或 #FFF)")
    return nil
  end

  state.set("hasError", false)
  state.set("errorMsg", "")

  local l1 = calcRelativeLuminance(fgRgb)
  local l2 = calcRelativeLuminance(bgRgb)

  local lighter = l1
  local darker = l2
  if l2 > l1 then
    lighter = l2
    darker = l1
  end

  local ratio = (lighter + 0.05) / (darker + 0.05)
  local ratioRound = math.floor((ratio * 100.0) + 0.5) / 100.0

  state.set("contrastRatio", string.format("%.2f : 1", ratioRound))
  state.set("ratioNumber", ratioRound)
  state.set("fgLuminance", string.format("%.4f", l1))
  state.set("bgLuminance", string.format("%.4f", l2))

  if ratio >= 4.5 then
    state.set("normalAa", "通过 (>= 4.5:1)")
  else
    state.set("normalAa", "未达标 (< 4.5:1)")
  end

  if ratio >= 7.0 then
    state.set("normalAaa", "通过 (>= 7.0:1)")
  else
    state.set("normalAaa", "未达标 (< 7.0:1)")
  end

  if ratio >= 3.0 then
    state.set("largeAa", "通过 (>= 3.0:1)")
    state.set("uiComponents", "通过 (>= 3.0:1)")
  else
    state.set("largeAa", "未达标 (< 3.0:1)")
    state.set("uiComponents", "未达标 (< 3.0:1)")
  end

  if ratio >= 4.5 then
    state.set("largeAaa", "通过 (>= 4.5:1)")
  else
    state.set("largeAaa", "未达标 (< 4.5:1)")
  end

  return nil
end

function swapColors()
  local fg = state.get("fgColor")
  local bg = state.get("bgColor")
  state.set("fgColor", bg)
  state.set("bgColor", fg)
  analyze()
  return nil
end

function setPreset(name)
  if name == "dark" then
    state.set("fgColor", "#F3F4F6")
    state.set("bgColor", "#111827")
  elseif name == "blue" then
    state.set("fgColor", "#1D4ED8")
    state.set("bgColor", "#EFF6FF")
  elseif name == "amber" then
    state.set("fgColor", "#78350F")
    state.set("bgColor", "#FEF3C7")
  else
    state.set("fgColor", "#000000")
    state.set("bgColor", "#FFFFFF")
  end
  analyze()
  return nil
end

function copyReport()
  local ratio = state.get("contrastRatio")
  local fg = state.get("fgColor")
  local bg = state.get("bgColor")
  local naa = state.get("normalAa")
  local naaa = state.get("normalAaa")
  local laa = state.get("largeAa")
  local laaa = state.get("largeAaa")

  local report = "【WCAG 2.1 对比度评级报告】\n" ..
    "前景色: " .. tostring(fg) .. " | 背景色: " .. tostring(bg) .. "\n" ..
    "对比度比率: " .. tostring(ratio) .. "\n" ..
    "正文常规文字 AA (>=4.5:1): " .. tostring(naa) .. "\n" ..
    "正文常规文字 AAA (>=7.0:1): " .. tostring(naaa) .. "\n" ..
    "大号文字/标题 AA (>=3.0:1): " .. tostring(laa) .. "\n" ..
    "大号文字/标题 AAA (>=4.5:1): " .. tostring(laaa)

  clipboard.set(report)
  dialog.toast("已复制对比度无障碍报告")
  return nil
end
