-- flashlight_tool main.lua
-- 多功能手电与补光灯

local isTorchActive = false
local isScreenActive = false

function _evalTorchLabel(on)
  if on == true then
    return "已开启 (照明中)"
  end
  return "已关闭"
end

function onInit()
  isTorchActive = false
  isScreenActive = false

  state.set("torchStatus", "已关闭")
  state.set("screenLightStatus", "未启用")
  state.set("currentColorHex", "#FFFFFF")
  state.set("colorName", "自然白光 (6500K)")
  return nil
end

function toggleTorch()
  torch.toggle(function(ok)
    isTorchActive = not isTorchActive
    state.set("torchStatus", _evalTorchLabel(isTorchActive))
    return nil
  end)
  return nil
end

function toggleScreenLight()
  isScreenActive = not isScreenActive
  if isScreenActive == true then
    screen.setKeepScreenOn(true, function(ok) end)
    screen.setBrightness(1.0, function(ok) end)
    state.set("screenLightStatus", "高亮常亮中 (100% 亮度)")
    dialog.toast("已开启屏幕补光与常亮")
  else
    screen.setKeepScreenOn(false, function(ok) end)
    screen.setBrightness(0.5, function(ok) end)
    state.set("screenLightStatus", "已关闭 (恢复正常亮度)")
    dialog.toast("已关闭屏幕补光")
  end
  return nil
end

function setColorWhite()
  state.set("currentColorHex", "#FFFFFF")
  state.set("colorName", "自然白光 (6500K)")
  return nil
end

function setColorWarm()
  state.set("currentColorHex", "#FFF2D6")
  state.set("colorName", "暖黄柔光 (3200K 护眼)")
  return nil
end

function setColorRed()
  state.set("currentColorHex", "#FF3B30")
  state.set("colorName", "警示红光 (应急信号)")
  return nil
end

function onDispose()
  if isTorchActive and torch ~= nil and torch.off ~= nil then
    pcall(function()
      torch.off()
    end)
    isTorchActive = false
  end
  if isScreenActive and screen ~= nil then
    pcall(function()
      if screen.setKeepScreenOn ~= nil then screen.setKeepScreenOn(false) end
      if screen.setBrightness ~= nil then screen.setBrightness(0.5) end
    end)
    isScreenActive = false
  end
  return nil
end
