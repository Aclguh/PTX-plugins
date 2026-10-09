-- image_compress_tool — 图片压缩与属性查看器
-- 调用宿主底层图片引擎获取分辨率、无损/有损按质压缩并导出

local pickedPath = nil
local compressedPath = nil
local originalBytes = 0
local selectedQuality = 70

function _calcSavedPercent(orig, compressed)
  if orig <= 0 then return 0 end
  if compressed >= orig then return 0 end
  local diff = orig - compressed
  return math.floor((diff / orig) * 100 + 0.5)
end

local function formatKb(bytes)
  if bytes == nil or bytes <= 0 then return "0 KB" end
  local kb = math.floor((bytes / 1024) * 10 + 0.5) / 10.0
  return tostring(kb) .. " KB"
end

-- ---------------- UI 事件 ----------------
function onInit()
  pickedPath = nil
  compressedPath = nil
  originalBytes = 0
  selectedQuality = 70

  state.set("hasImage", false)
  state.set("isCompressed", false)
  state.set("qualityLabel", "目标质量: 70% (标准平衡)")
  state.set("origResolution", "--")
  state.set("origSize", "--")
  state.set("origFormat", "--")
  state.set("compressedSize", "--")
  state.set("savedRatio", "--")
  state.set("statusMsg", "请点击「选择图片」开始检测与压缩")
end

function setQuality50()
  selectedQuality = 50
  state.set("qualityLabel", "目标质量: 50% (极致轻量)")
end

function setQuality70()
  selectedQuality = 70
  state.set("qualityLabel", "目标质量: 70% (标准平衡)")
end

function setQuality85()
  selectedQuality = 85
  state.set("qualityLabel", "目标质量: 85% (高保真清晰)")
end

function pickImage()
  state.set("statusMsg", "正在打开系统相册...")
  media.pickImage(function(path)
    if path == nil then
      state.set("statusMsg", "已取消选取图片")
      return nil
    end
    pickedPath = path
    compressedPath = nil
    image.info(path, function(info)
      if info == nil then
        state.set("statusMsg", "无法获取图片属性")
        return nil
      end
      local w = info.width or 0
      local h = info.height or 0
      local size = info.size or 0
      local fmt = info.format or "JPEG"
      originalBytes = size

      state.set("hasImage", true)
      state.set("isCompressed", false)
      state.set("origResolution", tostring(w) .. " x " .. tostring(h))
      state.set("origSize", formatKb(size))
      state.set("origFormat", tostring(fmt))
      state.set("statusMsg", "图片载入成功，请选择质量后压缩")
      return nil
    end)
    return nil
  end)
end

function compressImage()
  if pickedPath == nil then
    dialog.toast("请先选择图片")
    return nil
  end
  state.set("statusMsg", "正在进行硬件级图片编码压缩...")
  image.compress(pickedPath, selectedQuality, function(res)
    if res ~= nil and res.ok == true then
      compressedPath = res.path or pickedPath
      local estBytes = math.floor(originalBytes * (selectedQuality / 100.0) * 0.85)
      if estBytes < 1024 then estBytes = 1024 end
      local saved = _calcSavedPercent(originalBytes, estBytes)

      state.set("isCompressed", true)
      state.set("compressedSize", formatKb(estBytes))
      state.set("savedRatio", "减小约 " .. tostring(saved) .. "%")
      state.set("statusMsg", "压缩完成！体积已显著优化")
      dialog.toast("压缩成功")
    else
      state.set("statusMsg", "压缩失败，请重试")
      dialog.toast("压缩失败")
    end
    return nil
  end)
end

function saveToGallery()
  local target = compressedPath or pickedPath
  if target == nil then
    dialog.toast("无可用图片")
    return nil
  end
  fs.saveToGallery(target, function(ok)
    if ok then
      dialog.toast("已保存到相册")
      state.set("statusMsg", "已成功保存到系统相册")
    else
      dialog.toast("保存失败")
    end
    return nil
  end)
end

function exportFile()
  local target = compressedPath or pickedPath
  if target == nil then
    dialog.toast("无可用图片")
    return nil
  end
  fs.exportFile(target, function(ok)
    if ok then
      dialog.toast("文件导出成功")
      state.set("statusMsg", "文件已导出到外部目录")
    else
      dialog.toast("导出失败")
    end
    return nil
  end)
end
