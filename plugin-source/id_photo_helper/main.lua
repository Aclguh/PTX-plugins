-- id_photo_helper — 证件照尺寸与排版助手
-- 常用规格规范、像素与物理打印尺寸精准换算

local SPECS = {
  {
    name = "标准 1 寸",
    mmW = 25, mmH = 35,
    pxW = 295, pxH = 413,
    bg = "蓝底 / 白底 / 红底",
    usage = "普通证件、学生证、简历、体检表",
    fileSize = "20KB - 80KB"
  },
  {
    name = "标准 2 寸",
    mmW = 35, mmH = 49,
    pxW = 413, pxH = 579,
    bg = "白底 / 蓝底",
    usage = "简历、资格证书、部分国家签证",
    fileSize = "30KB - 120KB"
  },
  {
    name = "小 2 寸 / 中国护照",
    mmW = 33, mmH = 48,
    pxW = 390, pxH = 567,
    bg = "纯白底 (无阴影)",
    usage = "中国护照、港澳通行证、旅行证",
    fileSize = "40KB - 120KB"
  },
  {
    name = "美国签证 (51x51mm)",
    mmW = 51, mmH = 51,
    pxW = 600, pxH = 600,
    bg = "纯白底 (头像居中)",
    usage = "美国/日本/印度签证等方形证件照",
    fileSize = "100KB - 240KB"
  },
  {
    name = "教师资格证 / 考研网报",
    mmW = 25, mmH = 35,
    pxW = 295, pxH = 413,
    bg = "纯白底 / 浅蓝底",
    usage = "中小学教资认定、研招网报名确认",
    fileSize = "严格限制 20KB - 100KB"
  }
}

local specIdx = 1

function _mmToPx(mm, dpi)
  local m = mm or 25
  local d = dpi or 300
  return math.floor(m * d / 25.4 + 0.5)
end

local function applySpec()
  local s = SPECS[specIdx]
  state.set("specName", s.name)
  state.set("mmSize", tostring(s.mmW) .. " mm × " .. tostring(s.mmH) .. " mm")
  state.set("pxSize", tostring(s.pxW) .. " px × " .. tostring(s.pxH) .. " px (300 DPI)")
  state.set("bgColor", s.bg)
  state.set("usageInfo", s.usage)
  state.set("fileSizeLimit", s.fileSize)
end

-- ---------------- UI 事件 ----------------
function onInit()
  specIdx = 1
  state.set("customMmW", "25")
  state.set("customMmH", "35")
  state.set("customDpi", "300")
  state.set("calcResult", "295 px × 413 px")
  state.set("statusMsg", "点击上方预设规格或在下方自定义换算")
  applySpec()
end

function selectSpec1()
  specIdx = 1
  applySpec()
end

function selectSpec2()
  specIdx = 2
  applySpec()
end

function selectSpecPassport()
  specIdx = 3
  applySpec()
end

function selectSpecVisa()
  specIdx = 4
  applySpec()
end

function selectSpecExam()
  specIdx = 5
  applySpec()
end

function calcCustomSize()
  local mw = tonumber(state.get("customMmW") or "25") or 25
  local mh = tonumber(state.get("customMmH") or "35") or 35
  local dpi = tonumber(state.get("customDpi") or "300") or 300

  local pw = _mmToPx(mw, dpi)
  local ph = _mmToPx(mh, dpi)
  local res = tostring(pw) .. " px × " .. tostring(ph) .. " px"
  state.set("calcResult", res)
  dialog.toast("计算成功: " .. res)
end

function copySpecInfo()
  local s = SPECS[specIdx]
  local txt = "【" .. s.name .. " 证件照规范】\n物理尺寸: " .. s.mmW .. "x" .. s.mmH .. " mm\n像素分辨率: " .. s.pxW .. "x" .. s.pxH .. " px (@300DPI)\n背景要求: " .. s.bg .. "\n适用场景: " .. s.usage .. "\n文件大小: " .. s.fileSize
  clipboard.set(txt)
  dialog.toast("已复制证件照规范")
end
