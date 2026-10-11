-- ws_debugger_tool main.lua
-- WebSocket 实时调试终端

local currentWsId = nil
local logEntries = {}

function _formatWsPacket(dir, payload)
  local d = dir or "INFO"
  local p = payload or ""
  return string.format("[%s] %s", d, p)
end

local function appendLog(dir, msg)
  local entry = _formatWsPacket(dir, msg)
  table.insert(logEntries, entry)
  if #logEntries > 30 then
    table.remove(logEntries, 1)
  end
  state.set("logText", table.concat(logEntries, "\n\n"))
end

function onInit()
  currentWsId = nil
  logEntries = {}

  state.set("wsUrl", "wss://echo.websocket.events")
  state.set("msgToSend", "{\"event\":\"ping\",\"timestamp\":1727654400}")
  state.set("connStatus", "未连接")
  state.set("logText", "尚未建立 WebSocket 连接")
  return nil
end

function connectWs()
  local url = state.get("wsUrl")
  if url == nil or string.len(url) == 0 then
    dialog.toast("请输入有效的 WebSocket 网址")
    return nil
  end

  state.set("connStatus", "正在连接握手中...")
  appendLog("CONNECT", "正在发起握手: " .. url)

  local options = {
    onOpen = function()
      state.set("connStatus", "已连接 (OPEN)")
      appendLog("OPEN", "WebSocket 握手成功已建立连接！")
      dialog.toast("连接成功")
      return nil
    end,
    onMessage = function(data)
      appendLog("RECV", tostring(data))
      return nil
    end,
    onError = function(err)
      state.set("connStatus", "连接发生错误")
      appendLog("ERROR", tostring(err))
      return nil
    end,
    onClose = function()
      currentWsId = nil
      state.set("connStatus", "已断开连接 (CLOSED)")
      appendLog("CLOSE", "连接已关闭")
      return nil
    end
  }

  currentWsId = websocket.connect(url, options)
  return nil
end

function sendMessage()
  if currentWsId == nil then
    dialog.toast("请先建立 WebSocket 连接")
    return nil
  end

  local msg = state.get("msgToSend")
  if msg == nil or string.len(msg) == 0 then
    dialog.toast("待发送内容不能为空")
    return nil
  end

  local ok = websocket.send(currentWsId, msg)
  if ok == true then
    appendLog("SEND", msg)
  else
    appendLog("FAIL", "发送数据帧失败")
  end
  return nil
end

function disconnectWs()
  if currentWsId ~= nil then
    websocket.close(currentWsId)
    currentWsId = nil
    state.set("connStatus", "已主动断开")
    appendLog("INFO", "用户主动断开连接")
    dialog.toast("连接已断开")
  end
  return nil
end

function clearLogs()
  logEntries = {}
  state.set("logText", "日志已清空")
  dialog.toast("日志已清空")
  return nil
end

function copyLogs()
  local txt = state.get("logText")
  if txt ~= nil and string.len(txt) > 0 then
    clipboard.set(txt)
    dialog.toast("日志记录已复制到剪贴板")
  end
  return nil
end

function onDispose()
  if currentWsId ~= nil and websocket ~= nil and websocket.close ~= nil then
    pcall(function()
      websocket.close(currentWsId)
    end)
    currentWsId = nil
  end
  return nil
end
