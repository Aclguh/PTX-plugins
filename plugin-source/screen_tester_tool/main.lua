-- screen_tester_tool — 屏幕坏点与漏光检测器
-- 全屏纯色光谱切换，常亮与高亮控制，排查屏幕坏点、暗点与边缘漏光

local COLORS = {
  { name = "纯白 (暗点/阴阳屏排查)", hex = "#FFFFFF", tip = "纯白模式: 检查屏幕是否有暗点、灰尘杂质或边缘泛黄" },
  { name = "纯黑 (漏光/亮点排查)", hex = "#000000", tip = "纯黑模式: 关灯环境检查四角漏光与常亮常亮坏点" },
  { name = "纯红 (R子像素检测)", hex = "#FF0000", tip = "纯红模式: 检查红色子像素是否缺失或异常" },
  { name = "纯绿 (G子像素检测)", hex = "#00FF00", tip = "纯绿模式: 检查绿色子像素（最敏感色）是否异常" },
  { name = "纯蓝 (B子像素检测)", hex = "#0000FF", tip = "纯蓝模式: 检查蓝色子像素是否异常" },
  { name = "50% 中性灰 (灰阶均匀度)", hex = "#808080", tip = "中灰模式: 检查面板灰阶均匀度与纵向横向条纹(Banding)" },
  { name = "纯黄 (色彩饱满度)", hex = "#FFFF00", tip = "纯黄模式: 检查红绿复合发光质量" }
}

local colorIdx = 1
local isMaxBrightness = false

function _getColorHex(idx)
  if idx < 1 or idx > #COLORS then return "#FFFFFF" end
  return COLORS[idx].hex
end

local function applyColor()
  local item = COLORS[colorIdx]
  state.set("screenColor", item.hex)
  state.set("currentColorName", "当前色块: " .. item.name)
  state.set("inspectionTip", item.tip)
end

-- ---------------- UI 事件 ----------------
function onInit()
  colorIdx = 1
  isMaxBrightness = false

  screen.setKeepScreenOn(true)
  state.set("screenColor", "#FFFFFF")
  state.set("currentColorName", "当前色块: 纯白 (暗点/阴阳屏排查)")
  state.set("inspectionTip", "纯白模式: 检查屏幕是否有暗点、灰尘杂质或边缘泛黄")
  state.set("brightnessLabel", "屏幕亮度: 标准")
  state.set("statusMsg", "屏幕保持常亮中，请仔细查看下方色块区域")
end

function onDispose()
  screen.setKeepScreenOn(false)
  if isMaxBrightness then
    screen.setBrightness(0.5)
  end
end

function nextColor()
  colorIdx = (colorIdx % #COLORS) + 1
  applyColor()
end

function prevColor()
  colorIdx = colorIdx - 1
  if colorIdx < 1 then colorIdx = #COLORS end
  applyColor()
end

function setColorWhite()
  colorIdx = 1
  applyColor()
end

function setColorBlack()
  colorIdx = 2
  applyColor()
end

function setColorRed()
  colorIdx = 3
  applyColor()
end

function setColorGreen()
  colorIdx = 4
  applyColor()
end

function setColorBlue()
  colorIdx = 5
  applyColor()
end

function setColorGray()
  colorIdx = 6
  applyColor()
end

function toggleMaxBrightness()
  isMaxBrightness = not isMaxBrightness
  if isMaxBrightness then
    screen.setBrightness(1.0)
    state.set("brightnessLabel", "屏幕亮度: 100% 极高亮度")
    dialog.toast("已调至最高亮度，便于观察微小亮点")
  else
    screen.setBrightness(0.6)
    state.set("brightnessLabel", "屏幕亮度: 恢复适中")
    dialog.toast("已恢复适中亮度")
  end
end
