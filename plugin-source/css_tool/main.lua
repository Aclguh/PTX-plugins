-- css_tool — CSS 盒阴影与渐变背景生成器

local function strLen(s)
  if s == nil then return 0 end
  return string.len(s)
end

local function trim(s)
  if s == nil then return "" end
  local len = strLen(s)
  local i = 1
  while i <= len do
    local c = string.sub(s, i, i)
    if c ~= " " and c ~= "\t" and c ~= "\r" and c ~= "\n" then
      break
    end
    i = i + 1
  end
  local j = len
  while j >= i do
    local c = string.sub(s, j, j)
    if c ~= " " and c ~= "\t" and c ~= "\r" and c ~= "\n" then
      break
    end
    j = j - 1
  end
  if i > j then return "" end
  return string.sub(s, i, j)
end

function _gen_box_shadow(ox, oy, blur, spread, color, opacity, isInset)
  local x = tonumber(ox) or 0
  local y = tonumber(oy) or 0
  local b = tonumber(blur) or 0
  local sp = tonumber(spread) or 0
  local op = tonumber(opacity) or 0.2
  if op < 0 then op = 0 end
  if op > 1 then op = 1 end

  local insetPrefix = isInset and "inset " or ""
  local shadowVal = string.format("%s%dpx %dpx %dpx %dpx rgba(%s, %.2f)", insetPrefix, x, y, b, sp, color, op)

  local lines = {}
  lines[#lines + 1] = "-webkit-box-shadow: " .. shadowVal .. ";"
  lines[#lines + 1] = "-moz-box-shadow: " .. shadowVal .. ";"
  lines[#lines + 1] = "box-shadow: " .. shadowVal .. ";"
  return table.concat(lines, "\n")
end

function _gen_gradient(angle, c1, c2, c3)
  local ang = tostring(angle or "135") .. "deg"
  local lines = {}
  if c3 ~= nil and trim(c3) ~= "" then
    local stops = c1 .. " 0%, " .. c2 .. " 50%, " .. c3 .. " 100%"
    lines[#lines + 1] = "background: " .. c1 .. ";"
    lines[#lines + 1] = "background: -webkit-linear-gradient(" .. ang .. ", " .. stops .. ");"
    lines[#lines + 1] = "background: linear-gradient(" .. ang .. ", " .. stops .. ");"
  else
    local stops = c1 .. " 0%, " .. c2 .. " 100%"
    lines[#lines + 1] = "background: " .. c1 .. ";"
    lines[#lines + 1] = "background: -webkit-linear-gradient(" .. ang .. ", " .. stops .. ");"
    lines[#lines + 1] = "background: linear-gradient(" .. ang .. ", " .. stops .. ");"
  end
  return table.concat(lines, "\n")
end

function generateShadow()
  local ox = state.get("shadowOx") or "0"
  local oy = state.get("shadowOy") or "8"
  local blur = state.get("shadowBlur") or "16"
  local spread = state.get("shadowSpread") or "0"
  local rgb = state.get("shadowRgb") or "0, 0, 0"
  local op = state.get("shadowOp") or "0.20"

  local code = _gen_box_shadow(ox, oy, blur, spread, rgb, op, false)
  state.set("generatedCss", code)
  state.set("previewTitle", "盒阴影效果 (Box Shadow)")
  state.set("previewColor", "#1E2A4A")
  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function generateGradient()
  local angle = state.get("gradAngle") or "135"
  local c1 = state.get("gradC1") or "#4FACFE"
  local c2 = state.get("gradC2") or "#00F2FE"

  local code = _gen_gradient(angle, c1, c2, nil)
  state.set("generatedCss", code)
  state.set("previewTitle", "渐变背景效果 (" .. c1 .. " -> " .. c2 .. ")")
  state.set("previewColor", c1)
  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function applyShadowPreset(name)
  if name == "soft" then
    state.set("shadowOx", "0")
    state.set("shadowOy", "4")
    state.set("shadowBlur", "12")
    state.set("shadowSpread", "0")
    state.set("shadowRgb", "0, 0, 0")
    state.set("shadowOp", "0.08")
  elseif name == "card" then
    state.set("shadowOx", "0")
    state.set("shadowOy", "12")
    state.set("shadowBlur", "28")
    state.set("shadowSpread", "-4")
    state.set("shadowRgb", "0, 0, 0")
    state.set("shadowOp", "0.25")
  elseif name == "glow" then
    state.set("shadowOx", "0")
    state.set("shadowOy", "0")
    state.set("shadowBlur", "20")
    state.set("shadowSpread", "4")
    state.set("shadowRgb", "79, 172, 254")
    state.set("shadowOp", "0.45")
  end
  generateShadow()
  return nil
end

function applyGradientPreset(name)
  if name == "aurora" then
    state.set("gradAngle", "135")
    state.set("gradC1", "#4FACFE")
    state.set("gradC2", "#00F2FE")
  elseif name == "sunset" then
    state.set("gradAngle", "135")
    state.set("gradC1", "#FA709A")
    state.set("gradC2", "#FEE140")
  elseif name == "fresh" then
    state.set("gradAngle", "120")
    state.set("gradC1", "#43E97B")
    state.set("gradC2", "#38F9D7")
  elseif name == "purple" then
    state.set("gradAngle", "135")
    state.set("gradC1", "#667EEA")
    state.set("gradC2", "#764BA2")
  end
  generateGradient()
  return nil
end

function copyCss()
  local code = state.get("generatedCss") or ""
  if code ~= "" and clipboard and clipboard.set then
    clipboard.set(code)
  end
  if dialog and dialog.toast then
    dialog.toast("已复制 CSS 代码")
  end
  return nil
end

function onInit()
  state.set("shadowOx", "0")
  state.set("shadowOy", "8")
  state.set("shadowBlur", "20")
  state.set("shadowSpread", "0")
  state.set("shadowRgb", "0, 0, 0")
  state.set("shadowOp", "0.20")
  state.set("gradAngle", "135")
  state.set("gradC1", "#4FACFE")
  state.set("gradC2", "#00F2FE")
  state.set("previewTitle", "")
  state.set("previewColor", "#1E2A4A")
  state.set("generatedCss", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  generateShadow()
  return nil
end
