-- color_picker_tool — 颜色拾取器
-- HEX/RGB/HSL/HSV 换算, WCAG 亮度与对比度, 宿主 Container color 渲染色块

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- 宿主 VM 的取小函数行为等同于取大 (同为 max 的复制实现), 最小值必须手写
local function min3(a, b, c)
  local m = a
  if b < m then m = b end
  if c < m then m = c end
  return m
end

-- 解析 #RGB / #RRGGBB / #AARRGGBB (可省略 #)
-- 返回 {r=, g=, b=, a=} 或 nil; 不用多返回值赋值, 规避宿主 VM 的误编译问题
local function parseHex(raw)
  if raw == nil then return { ok = false } end
  local s = raw
  if string.sub(s, 1, 1) == "#" then s = string.sub(s, 2) end
  local len = string.len(s)
  if len == 3 then
    -- #RGB -> #FFRRGGBB 展开
    local parts = {}
    for i = 1, 3 do
      local c = string.sub(s, i, i)
      parts[#parts + 1] = c .. c
    end
    s = "FF" .. table.concat(parts)
    len = 8
  end
  if len == 6 then s = "FF" .. s end
  if string.len(s) ~= 8 then return { ok = false } end
  local digits = "0123456789abcdefABCDEF"
  local vals = {}
  for i = 1, 8 do
    local c = string.sub(s, i, i)
    local found = -1
    for j = 1, string.len(digits) do
      if string.sub(digits, j, j) == c then
        found = j - 1
        break
      end
    end
    if found < 0 then return { ok = false } end
    if found > 15 then found = found - 6 end
    vals[i] = found
  end
  local function byte(i)
    return vals[i] * 16 + vals[i + 1]
  end
  return { ok = true, r = byte(3), g = byte(5), b = byte(7), a = byte(1) }
end

local function toHex2(v)
  local digits = "0123456789ABCDEF"
  v = clamp(math.floor(v + 0.5), 0, 255)
  return string.sub(digits, math.floor(v / 16) + 1, math.floor(v / 16) + 1)
      .. string.sub(digits, v % 16 + 1, v % 16 + 1)
end

-- RGB (0-255) -> HSL: 返回 h (0-360), s (0-100), l (0-100)
local function rgbToHsl(r, g, b)
  local rf, gf, bf = r / 255, g / 255, b / 255
  local mx = math.max(rf, gf, bf)
  local mn = min3(rf, gf, bf)
  local h, s, l = 0, 0, (mx + mn) / 2
  if mx ~= mn then
    local dlt = mx - mn
    if l > 0.5 then s = dlt / (2 - mx - mn) else s = dlt / (mx + mn) end
    if mx == rf then
      h = (gf - bf) / dlt + (gf < bf and 6 or 0)
    elseif mx == gf then
      h = (bf - rf) / dlt + 2
    else
      h = (rf - gf) / dlt + 4
    end
    h = h * 60
  end
  return math.floor(h * 10 + 0.5) / 10, math.floor(s * 1000 + 0.5) / 10, math.floor(l * 1000 + 0.5) / 10
end

-- RGB -> HSV: 返回 h (0-360), s (0-100), v (0-100)
local function rgbToHsv(r, g, b)
  local rf, gf, bf = r / 255, g / 255, b / 255
  local mx = math.max(rf, gf, bf)
  local mn = min3(rf, gf, bf)
  local dlt = mx - mn
  local h = 0
  if mx ~= mn then
    if mx == rf then
      h = (gf - bf) / dlt + (gf < bf and 6 or 0)
    elseif mx == gf then
      h = (bf - rf) / dlt + 2
    else
      h = (rf - gf) / dlt + 4
    end
    h = h * 60
  end
  local s = 0
  if mx > 0 then s = dlt / mx end
  return math.floor(h * 10 + 0.5) / 10, math.floor(s * 1000 + 0.5) / 10, math.floor(mx * 1000 + 0.5) / 10
end

-- WCAG 相对亮度 (0-1)
local function relativeLuminance(r, g, b)
  local function channel(v)
    local c = v / 255
    if c <= 0.03928 then return c / 12.92 end
    return ((c + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
end

local function contrastRatio(l1, l2)
  local lighter = l1
  local darker = l2
  if l1 < l2 then
    lighter = l2
    darker = l1
  end
  return (lighter + 0.05) / (darker + 0.05)
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _parseHex(raw) return parseHex(raw) end
function _rgbToHsl(r, g, b) return rgbToHsl(r, g, b) end
function _luminance(r, g, b) return relativeLuminance(r, g, b) end
function _contrast(a, b) return contrastRatio(a, b) end

-- ---------------- 插件状态与交互 ----------------
local PRESETS = {
  { name = "品牌藏蓝", hex = "#26366A" },
  { name = "深蓝内槽", hex = "#1B2445" },
  { name = "冰蓝字体", hex = "#B4C9FF" },
  { name = "靛青主色", hex = "#788CFF" },
  { name = "薄荷青",   hex = "#31D9D0" },
  { name = "珊瑚粉",   hex = "#FF9D72" },
  { name = "纸白",     hex = "#FFFFFF" },
  { name = "墨黑",     hex = "#111111" },
}

function onInit()
  state.set("hexInput", "#26366A")
  state.set("swatchHex", "")
  state.set("rgbText", "")
  state.set("hslText", "")
  state.set("hsvText", "")
  state.set("lumText", "")
  state.set("adviceText", "")
  state.set("hasError", false)
  state.set("errorMsg", "")
  state.set("hasSwatch", false)
  applyHex()
end

local function applyRgb(r, g, b)
  local h, s, l = rgbToHsl(r, g, b)
  local hv, sv, vv = rgbToHsv(r, g, b)
  local lum = relativeLuminance(r, g, b)
  local cw = contrastRatio(lum, 1.0)
  local cb = contrastRatio(lum, 0.0)
  state.set("swatchHex", "#" .. toHex2(r) .. toHex2(g) .. toHex2(b))
  state.set("hasSwatch", true)
  state.set("rgbText", string.format("RGB: %d, %d, %d", r, g, b))
  state.set("hslText", string.format("HSL: %.1f, %.1f%%, %.1f%%", h, s, l))
  state.set("hsvText", string.format("HSV: %.1f, %.1f%%, %.1f%%", hv, sv, vv))
  state.set("lumText", string.format("相对亮度: %.4f", lum))
  local better = "白"
  if cb > cw then better = "黑" end
  state.set("adviceText", string.format("白字对比度 %.2f:1 · 黑字对比度 %.2f:1 · 建议 %s 色",
      cw, cb, better))
end

function applyHex()
  state.set("hasError", false)
  state.set("errorMsg", "")
  local parsed = parseHex(state.get("hexInput") or "")
  -- 注意: 宿主 VM 对"守卫分支 return 后再顶层调用表字段实参"的函数体会误编译
  -- (实测复现), 故这里用 if/else 无早退结构; parseHex 一律返回表而非 nil
  if parsed.ok then
    applyRgb(parsed.r, parsed.g, parsed.b)
  else
    state.set("hasSwatch", false)
    state.set("hasError", true)
    state.set("errorMsg", "无法解析颜色: 支持 #RGB / #RRGGBB / #AARRGGBB 格式")
  end
end

function applyPreset(idx)
  local p = PRESETS[math.floor(tonumber(idx) or 1)]
  if p == nil then return nil end
  state.set("hexInput", p.hex)
  applyHex()
end

function randomColor()
  local r = math.random(0, 255)
  local g = math.random(0, 255)
  local b = math.random(0, 255)
  state.set("hexInput", "#" .. toHex2(r) .. toHex2(g) .. toHex2(b))
  applyHex()
  dialog.toast("随机颜色已生成")
end

function pasteHex()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("hexInput", val)
      applyHex()
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
