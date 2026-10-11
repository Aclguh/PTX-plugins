-- ble_scanner_tool main.lua
-- BLE 蓝牙设备嗅探器

local devices = {}
local isScanningActive = false

function _formatDeviceEntry(id, name, rssi)
  local devName = name
  if devName == nil or string.len(devName) == 0 then
    devName = "未命名设备 (Unknown)"
  end
  local devId = id or "未知地址"
  local devRssi = rssi or -99
  return string.format("• %s\n  地址: %s | 信号: %d dBm", devName, devId, devRssi)
end

local function rebuildListText()
  local items = {}
  for i = 1, #devices do
    local d = devices[i]
    table.insert(items, _formatDeviceEntry(d.id, d.name, d.rssi))
  end
  return table.concat(items, "\n\n")
end

function onInit()
  devices = {}
  isScanningActive = false

  state.set("isScanning", false)
  state.set("scanStatus", "待扫描")
  state.set("deviceCount", 0)
  state.set("deviceListText", "暂无设备")
  state.set("hasDevices", false)
  state.set("showPlaceholder", true)
  return nil
end

function startScan()
  bluetooth.isAvailable(function(avail)
    if avail ~= true then
      dialog.toast("蓝牙不可用，请确保已打开系统蓝牙并授权")
      return nil
    end

    isScanningActive = true
    state.set("isScanning", true)
    state.set("scanStatus", "正在持续扫描周围广播中...")

    bluetooth.startScan(function(res)
      if res ~= nil and res.ok == true and res.device ~= nil then
        local dev = res.device
        local devId = dev.id or ""

        -- 查重更新或追加
        local found = false
        for i = 1, #devices do
          if devices[i].id == devId then
            devices[i].rssi = dev.rssi
            devices[i].name = dev.name
            found = true
            break
          end
        end

        if not found and string.len(devId) > 0 then
          table.insert(devices, {
            id = devId,
            name = dev.name,
            rssi = dev.rssi or -90
          })
        end

        state.set("deviceCount", #devices)
        state.set("deviceListText", rebuildListText())
        state.set("hasDevices", true)
        state.set("showPlaceholder", false)
      end
      return nil
    end)

    return nil
  end)
  return nil
end

function stopScan()
  isScanningActive = false
  bluetooth.stopScan(function(ok)
    state.set("isScanning", false)
    state.set("scanStatus", "扫描已暂停")
    dialog.toast("已停止蓝牙扫描")
    return nil
  end)
  return nil
end

function clearList()
  devices = {}
  state.set("deviceCount", 0)
  state.set("deviceListText", "暂无设备")
  state.set("hasDevices", false)
  state.set("showPlaceholder", true)
  dialog.toast("列表已清空")
  return nil
end

function copyList()
  local txt = state.get("deviceListText")
  if txt ~= nil and string.len(txt) > 0 then
    clipboard.set(txt)
    dialog.toast("设备列表已复制到剪贴板")
  end
  return nil
end

function onDispose()
  if isScanningActive and bluetooth ~= nil and bluetooth.stopScan ~= nil then
    pcall(function()
      bluetooth.stopScan()
    end)
  end
  isScanningActive = false
  return nil
end
