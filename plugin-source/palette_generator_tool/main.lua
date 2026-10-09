-- palette_generator_tool — 调色板与配色方案生成器
-- 基于 HSL 色彩空间与色彩和谐算法生成互补、类似、三色与同色系方案

local currentHarmony = "complementary"
local seedHue = 210 -- 默认科技蓝 210°
local seedSat = 0.75
local seedLum = 0.50

local paletteColors = {}

local function padHex(val)
  local v = math.floor(val + 0.5)
  if v < 0 then v = 0 end
  if v > 255 then v = 255 end
  local s = string.format("%02X", v)
  return s
end

-- HSL -> HEX
function _hslToHex(h, s, l)
  local hh = h % 360
  if hh < 0 then hh = hh + 360 end
  local ss = s
  if ss < 0 then ss = 0 end
  if ss > 1 then ss = 1 end
  local ll = l
  if ll < 0 then ll = 0 end
  if ll > 1 then ll = 1 end

  local c = (1.0 - math.abs(2.0 * ll - 1.0)) * ss
  local xVal = (hh / 60.0) % 2.0
  local x = c * (1.0 - math.abs(xVal - 1.0))
  local m = ll - c / 2.0

  local r1, g1, b1 = 0, 0, 0
  if hh < 60 then
    r1, g1, b1 = c, x, 0
  elseif hh < 120 then
    r1, g1, b1 = x, c, 0
  elseif hh < 180 then
    r1, g1, b1 = 0, c, x
  elseif hh < 240 then
    r1, g1, b1 = 0, x, c
  elseif hh < 300 then
    r1, g1, b1 = x, 0, c
  else
    r1, g1, b1 = c, 0, x
  end

  local r = (r1 + m) * 255.0
  local g = (g1 + m) * 255.0
  local b = (b1 + m) * 255.0

  return "#" .. padHex(r) .. padHex(g) .. padHex(b)
end

local function generatePalette()
  local colors = {}
  if currentHarmony == "complementary" then
    colors[1] = _hslToHex(seedHue, seedSat, 0.40)
    colors[2] = _hslToHex(seedHue, seedSat, seedLum)
    colors[3] = _hslToHex(seedHue, seedSat * 0.5, 0.75)
    colors[4] = _hslToHex(seedHue + 180, seedSat, seedLum)
    colors[5] = _hslToHex(seedHue + 180, seedSat, 0.35)
  elseif currentHarmony == "analogous" then
    colors[1] = _hslToHex(seedHue - 40, seedSat, seedLum)
    colors[2] = _hslToHex(seedHue - 20, seedSat, seedLum)
    colors[3] = _hslToHex(seedHue, seedSat, seedLum)
    colors[4] = _hslToHex(seedHue + 20, seedSat, seedLum)
    colors[5] = _hslToHex(seedHue + 40, seedSat, seedLum)
  elseif currentHarmony == "triadic" then
    colors[1] = _hslToHex(seedHue, seedSat, seedLum)
    colors[2] = _hslToHex(seedHue + 120, seedSat, seedLum)
    colors[3] = _hslToHex(seedHue + 240, seedSat, seedLum)
    colors[4] = _hslToHex(seedHue + 120, seedSat * 0.6, 0.70)
    colors[5] = _hslToHex(seedHue + 240, seedSat * 0.6, 0.35)
  else -- monochromatic
    colors[1] = _hslToHex(seedHue, seedSat, 0.20)
    colors[2] = _hslToHex(seedHue, seedSat, 0.38)
    colors[3] = _hslToHex(seedHue, seedSat, seedLum)
    colors[4] = _hslToHex(seedHue, seedSat, 0.68)
    colors[5] = _hslToHex(seedHue, seedSat * 0.5, 0.85)
  end

  paletteColors = colors
  state.set("col1", colors[1])
  state.set("col2", colors[2])
  state.set("col3", colors[3])
  state.set("col4", colors[4])
  state.set("col5", colors[5])

  local summary = table.concat(colors, "  ")
  state.set("paletteSummary", summary)
  state.set("exportText", summary)
end

-- ---------------- UI 事件 ----------------
function onInit()
  math.randomseed(util.timestampMs() % 2147483647)
  currentHarmony = "complementary"
  seedHue = 210
  seedSat = 0.75
  seedLum = 0.50

  state.set("harmonyName", "配色模式: 互补色 (Complementary)")
  state.set("seedInfo", "基准色调: 210° (科技蓝)")
  state.set("statusMsg", "已生成 5 色和谐色盘")
  state.set("exportFormat", "CSS 变量")
  generatePalette()
end

function setModeComplementary()
  currentHarmony = "complementary"
  state.set("harmonyName", "配色模式: 互补色 (Complementary)")
  generatePalette()
end

function setModeAnalogous()
  currentHarmony = "analogous"
  state.set("harmonyName", "配色模式: 相邻色 (Analogous)")
  generatePalette()
end

function setModeTriadic()
  currentHarmony = "triadic"
  state.set("harmonyName", "配色模式: 三色相 (Triadic)")
  generatePalette()
end

function setModeMonochromatic()
  currentHarmony = "monochromatic"
  state.set("harmonyName", "配色模式: 单色阶 (Monochromatic)")
  generatePalette()
end

function randomizeSeed()
  seedHue = math.random(0, 359)
  state.set("seedInfo", "基准色调: " .. seedHue .. "° (随机)")
  generatePalette()
  dialog.toast("已随机基准主色")
end

function exportCss()
  local lines = {}
  lines[#lines + 1] = ":root {"
  for i = 1, #paletteColors do
    lines[#lines + 1] = "  --color-" .. i .. ": " .. paletteColors[i] .. ";"
  end
  lines[#lines + 1] = "}"
  local txt = table.concat(lines, "\n")
  state.set("exportText", txt)
  state.set("exportFormat", "CSS 变量")
  clipboard.set(txt)
  dialog.toast("已复制 CSS 变量格式")
end

function exportFlutter()
  local lines = {}
  for i = 1, #paletteColors do
    local hex = string.sub(paletteColors[i], 2)
    lines[#lines + 1] = "static const Color color" .. i .. " = Color(0xFF" .. hex .. ");"
  end
  local txt = table.concat(lines, "\n")
  state.set("exportText", txt)
  state.set("exportFormat", "Flutter 代码")
  clipboard.set(txt)
  dialog.toast("已复制 Flutter 代码")
end

function exportJson()
  local txt = json.encode(paletteColors)
  state.set("exportText", txt)
  state.set("exportFormat", "JSON 数组")
  clipboard.set(txt)
  dialog.toast("已复制 JSON 格式")
end
