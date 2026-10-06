-- signature_tool — 手写签名板
-- 支持手势书写、笔刷颜色/粗细调整、清空与图片保存/Base64导出

function onInit()
  state.set("brushColor", "#000000")
  state.set("brushWidth", 3.0)
  state.set("clearTick", 0)
  state.set("signatureBase64", "")
  state.set("statusText", "请在上方白板区域手写签名或涂鸦")
end

function setColorBlack()
  state.set("brushColor", "#000000")
  state.set("statusText", "笔刷颜色已切换为: 黑色")
end

function setColorBlue()
  state.set("brushColor", "#1E88E5")
  state.set("statusText", "笔刷颜色已切换为: 蓝色")
end

function setColorRed()
  state.set("brushColor", "#E53935")
  state.set("statusText", "笔刷颜色已切换为: 红色")
end

function setWidthThin()
  state.set("brushWidth", 2.0)
  state.set("statusText", "笔刷粗细已切换为: 细 (2px)")
end

function setWidthMedium()
  state.set("brushWidth", 4.0)
  state.set("statusText", "笔刷粗细已切换为: 中 (4px)")
end

function setWidthThick()
  state.set("brushWidth", 7.0)
  state.set("statusText", "笔刷粗细已切换为: 粗 (7px)")
end

function clearPad()
  local tick = (state.get("clearTick") or 0) + 1
  state.set("clearTick", tick)
  state.set("signatureBase64", "")
  state.set("statusText", "画板已清空，可重新书写")
  dialog.toast("已清空签名板")
end

function saveImage()
  local b64 = state.get("signatureBase64")
  if b64 == nil or b64 == "" then
    b64 = state.get("signPad_base64")
  end
  if b64 == nil or b64 == "" then
    dialog.toast("画板暂无内容，请先签名或涂鸦")
    state.set("statusText", "未检测到笔画内容")
    return nil
  end

  local ok, err = fs.writeBase64("signature.png", b64)
  if not ok then
    dialog.toast("保存图片失败: " .. (err or "沙箱写入错误"))
    return nil
  end

  fs.saveToGallery("signature.png", function(saved)
    if saved then
      state.set("statusText", "签名已成功保存至系统相册 (signature.png)")
      dialog.toast("已保存到相册")
    else
      state.set("statusText", "保存至系统相册失败")
      dialog.toast("保存相册失败")
    end
  end)
end

function copyBase64()
  local b64 = state.get("signatureBase64")
  if b64 == nil or b64 == "" then
    b64 = state.get("signPad_base64")
  end
  if b64 == nil or b64 == "" then
    dialog.toast("画板暂无内容")
    return nil
  end
  clipboard.set("data:image/png;base64," .. b64)
  state.set("statusText", "已复制 PNG Base64 数据 URL")
  dialog.toast("已复制 Base64 到剪贴板")
end
