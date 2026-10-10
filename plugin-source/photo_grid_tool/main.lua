-- photo_grid_tool: 朋友圈九宫格切图与长图拼接助手

local currentMode = "grid9"
local imgWidth = 1080
local imgHeight = 1080

local function calculateTiles(mode, w, h)
  local rows = 3
  local cols = 3
  local modeName = "3x3 九宫格"

  if mode == "grid6" then
    rows = 2
    cols = 3
    modeName = "3x2 六宫格"
  elseif mode == "grid4" then
    rows = 2
    cols = 2
    modeName = "2x2 四宫格"
  elseif mode == "grid3" then
    rows = 1
    cols = 3
    modeName = "3x1 横幅三联"
  elseif mode == "stitch" then
    rows = 3
    cols = 1
    modeName = "纵向长图拼贴"
  end

  local tileW = math.floor(w / cols)
  local tileH = math.floor(h / rows)

  local visual = ""
  local r = 0
  while r < rows do
    local line1 = "+"
    local line2 = "|"
    local c = 0
    while c < cols do
      line1 = line1 .. "-------+"
      local num = (r * cols) + c + 1
      line2 = line2 .. "  #" .. tostring(num) .. "  |"
      c = c + 1
    end
    visual = visual .. line1 .. "\n" .. line2 .. "\n"
    r = r + 1
  end
  visual = visual .. "+" .. string.rep("-------+", cols) .. "\n"

  local specList = "【切片参数清单 (" .. modeName .. ")】\n" ..
    "原图尺寸: " .. tostring(w) .. " x " .. tostring(h) .. " px | 单格尺寸: " .. tostring(tileW) .. " x " .. tostring(tileH) .. " px\n" ..
    "----------------------------------------\n"

  local idx = 1
  local rowIdx = 0
  while rowIdx < rows do
    local colIdx = 0
    while colIdx < cols do
      local startX = colIdx * tileW
      local startY = rowIdx * tileH
      specList = specList .. "图 " .. tostring(idx) .. ": [" .. tostring(startX) .. ", " .. tostring(startY) .. ", " .. tostring(tileW) .. ", " .. tostring(tileH) .. "]\n"
      idx = idx + 1
      colIdx = colIdx + 1
    end
    rowIdx = rowIdx + 1
  end

  return {
    rows = rows,
    cols = cols,
    count = rows * cols,
    modeName = modeName,
    tileW = tileW,
    tileH = tileH,
    visual = visual,
    spec = specList
  }
end

function recalculate()
  local w = tonumber(state.get("inputWidth")) or 1080
  local h = tonumber(state.get("inputHeight")) or 1080
  imgWidth = w
  imgHeight = h

  local plan = calculateTiles(currentMode, imgWidth, imgHeight)
  state.set("planDisplay", plan.spec)
  state.set("asciiVisual", plan.visual)
  state.set("tileCountLabel", tostring(plan.count) .. " 格 (" .. plan.modeName .. ")")
  state.set("tileSizeLabel", tostring(plan.tileW) .. " x " .. tostring(plan.tileH) .. " px")
  state.set("statusMsg", "切片方案规划完成，共 " .. tostring(plan.count) .. " 张切片")
  state.set("hasResult", true)
  return nil
end

function setMode(m)
  currentMode = m
  state.set("currentMode", m)
  recalculate()
  return nil
end

function setPresetSize(w, h)
  state.set("inputWidth", tostring(w))
  state.set("inputHeight", tostring(h))
  recalculate()
  dialog.toast("已设置分辨率 " .. tostring(w) .. "x" .. tostring(h))
  return nil
end

function copyPlan()
  local s = state.get("planDisplay") or ""
  if string.len(s) == 0 then
    dialog.toast("暂无切图方案可复制")
    return nil
  end
  clipboard.set(s)
  dialog.toast("已复制九宫格切片坐标")
  return nil
end

function onInit()
  currentMode = "grid9"
  imgWidth = 1080
  imgHeight = 1080

  state.set("currentMode", "grid9")
  state.set("inputWidth", "1080")
  state.set("inputHeight", "1080")
  state.set("planDisplay", "")
  state.set("asciiVisual", "")
  state.set("hasResult", false)

  recalculate()
  return nil
end
