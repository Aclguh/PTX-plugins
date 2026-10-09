-- exif_cleaner_tool main.lua
-- 照片 EXIF 隐私检测与擦除

local currentImageRel = nil
local cleanedImageRel = nil

function _checkGpsLeak(info)
  if info == nil then return false end
  if info.latitude ~= nil and info.longitude ~= nil then
    return true
  end
  return false
end

function onInit()
  currentImageRel = nil
  cleanedImageRel = nil

  state.set("hasSelected", false)
  state.set("showPlaceholder", true)
  state.set("isCleaned", false)
  state.set("statusText", "请点击上方按钮选取照片检测隐私")
  state.set("imageResolution", "--")
  state.set("photoSize", "--")
  state.set("cameraInfo", "无设备元数据")
  state.set("gpsLocation", "未检测到地理位置")
  state.set("privacyWarning", "安全")
  return nil
end

function pickAndInspect()
  state.set("statusText", "正在打开相册...")
  media.pickImage(function(relPath)
    if relPath == nil then
      state.set("statusText", "已取消选取图片")
      return nil
    end

    currentImageRel = relPath
    cleanedImageRel = nil

    image.info(relPath, function(info)
      if info == nil then
        state.set("statusText", "无法读取图片元数据")
        return nil
      end

      local w = info.width or 0
      local h = info.height or 0
      local size = info.size or 0
      local sizeKb = math.floor((size / 1024) * 10 + 0.5) / 10.0

      state.set("hasSelected", true)
      state.set("showPlaceholder", false)
      state.set("isCleaned", false)
      state.set("imageResolution", string.format("%d x %d (%s)", w, h, tostring(info.format or "未知")))
      state.set("photoSize", string.format("%.1f KB", sizeKb))

      local make = info.make
      local model = info.model
      if make ~= nil or model ~= nil then
        state.set("cameraInfo", string.format("%s %s", tostring(make or ""), tostring(model or "")))
      else
        state.set("cameraInfo", "未记录拍摄机型")
      end

      local hasGps = _checkGpsLeak(info)
      if hasGps == true then
        state.set("gpsLocation", string.format("纬度 %.4f, 经度 %.4f", info.latitude, info.longitude))
        state.set("privacyWarning", "高危: 含有精确 GPS 定位坐标，极易泄露家庭或拍摄地隐私！")
      else
        state.set("gpsLocation", "无 GPS 坐标 (安全)")
        state.set("privacyWarning", "低风险: 未包含 GPS 经纬度定位")
      end

      return nil
    end)

    return nil
  end)
  return nil
end

function cleanExif()
  if currentImageRel == nil then
    dialog.toast("请先选取一张照片")
    return nil
  end

  state.set("statusText", "正在抹除 EXIF 数据...")
  image.stripExif(currentImageRel, function(res)
    if res ~= nil and res.ok == true then
      cleanedImageRel = res.path or currentImageRel
      state.set("isCleaned", true)
      state.set("gpsLocation", "已彻底清除")
      state.set("cameraInfo", "已彻底清除")
      state.set("privacyWarning", "极安全: 已擦除全部 EXIF、GPS 定位与拍摄参数副本")
      dialog.toast("EXIF 抹除完成，可安全分享")
    else
      dialog.toast("擦除操作未完成")
    end
    return nil
  end)

  return nil
end

function copyFilePath()
  if cleanedImageRel ~= nil then
    clipboard.set(cleanedImageRel)
    dialog.toast("已复制文件路径到剪贴板")
  end
  return nil
end
