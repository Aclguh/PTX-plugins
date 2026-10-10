-- watermark_tool: 证件隐私防盗水印与全屏文字盖印

local currentAngle = -30
local currentColor = "#D32F2F"
local currentPreset = "id_card"

local function buildWatermarkPreview(txt, angle, color)
  local pattern = "/// " .. txt .. " ///\n" ..
    "    " .. txt .. "\n" ..
    "/// " .. txt .. " ///\n" ..
    "    " .. txt .. "\n" ..
    "/// " .. txt .. " ///"

  local svg = "<svg xmlns='http://www.w3.org/2000/svg' width='300' height='200'>\n" ..
    "  <text x='50%' y='50%' fill='" .. color .. "' fill-opacity='0.25' font-size='16' " ..
    "font-family='sans-serif' text-anchor='middle' " ..
    "transform='rotate(" .. tostring(angle) .. " 150 100)'>" .. txt .. "</text>\n" ..
    "</svg>"

  return {
    pattern = pattern,
    svg = svg
  }
end

function generateWatermark()
  local txt = state.get("watermarkText") or ""
  if string.len(txt) == 0 then
    dialog.toast("请输入水印防盗说明文字")
    return nil
  end

  local res = buildWatermarkPreview(txt, currentAngle, currentColor)
  state.set("previewDisplay", res.pattern)
  state.set("svgSnippet", res.svg)
  state.set("hasResult", true)
  state.set("statusMsg", "防盗水印样式生成完成 (倾斜 " .. tostring(currentAngle) .. "°)")
  storage.set("last_watermark_text", txt)
  return nil
end

function loadPreset(typ)
  currentPreset = typ
  if typ == "loan" then
    state.set("watermarkText", "仅供申请银行授信贷款审查 他用一律无效")
  elseif typ == "rent" then
    state.set("watermarkText", "仅供房屋租赁合同备案登记 严禁用于其他业务")
  elseif typ == "job" then
    state.set("watermarkText", "仅供本次入职档案背景调查使用 再次复印无效")
  else
    state.set("watermarkText", "仅供办理身份证核验业务使用 再次复印无效")
  end
  generateWatermark()
  dialog.toast("已载入规范用语")
  return nil
end

function setAngle(a)
  currentAngle = tonumber(a) or -30
  state.set("angleLabel", tostring(currentAngle) .. "°")
  generateWatermark()
  return nil
end

function setColor(c)
  currentColor = c
  state.set("colorLabel", c)
  generateWatermark()
  return nil
end

function copySnippet()
  local svg = state.get("svgSnippet") or ""
  if string.len(svg) == 0 then
    dialog.toast("暂无水印代码可复制")
    return nil
  end
  clipboard.set(svg)
  dialog.toast("已复制 SVG 水印图样代码")
  return nil
end

function copyText()
  local txt = state.get("watermarkText") or ""
  clipboard.set(txt)
  dialog.toast("已复制水印纯文本")
  return nil
end

function onInit()
  currentAngle = -30
  currentColor = "#D32F2F"
  currentPreset = "id_card"

  state.set("angleLabel", "-30°")
  state.set("colorLabel", "#D32F2F")
  state.set("watermarkText", "仅供办理身份证核验业务使用 再次复印无效")
  state.set("previewDisplay", "")
  state.set("svgSnippet", "")
  state.set("hasResult", false)

  generateWatermark()
  return nil
end
