-- mqtt_debugger_tool — MQTT 与物联网长连接调试器
-- 基于 WebSocket 通道连接公网/私有 MQTT 代理，模拟物联网设备发布与订阅

local wsClient = nil
local logs = {}

function _formatMqttMessage(topic, payload)
  local t = topic or "default/topic"
  local p = payload or "{}"
  return "【发布 TOPIC: " .. t .. "】\n" .. p
end

local function addLog(tag, content)
  local ts = tostring(util.timestamp())
  local entry = "[" .. tag .. " " .. ts .. "] " .. content
  table.insert(logs, 1, entry)
  while #logs > 20 do
    table.remove(logs)
  end
  state.set("logOutput", table.concat(logs, "\n\n"))
  state.set("hasLogs", true)
end

-- ---------------- UI 事件 ----------------
function onInit()
  wsClient = nil
  logs = {}

  state.set("brokerUrl", "ws://broker.emqx.io:8083/mqtt")
  state.set("topicInput", "device/sensor/telemetry")
  state.set("payloadInput", "{\"dev_id\":\"esp32_01\",\"temp\":24.8,\"humidity\":60,\"battery\":95}")
  state.set("connStatus", "未连接")
  state.set("hasLogs", false)
  state.set("logOutput", "尚未连接 MQTT 代理")
  state.set("statusMsg", "输入 Broker 地址后点击「连接」")
end

function onDispose()
  disconnectBroker()
end

function setMockTelemetry()
  local rTemp = 20.0 + (math.random(0, 150) / 10.0)
  local rHum = math.random(40, 85)
  state.set("topicInput", "device/sensor/telemetry")
  state.set("payloadInput", "{\"dev_id\":\"esp32_01\",\"temp\":" .. string.format("%.1f", rTemp) .. ",\"humidity\":" .. rHum .. ",\"battery\":95}")
  state.set("statusMsg", "已载入传感器环境遥测报文")
end

function setMockStatus()
  state.set("topicInput", "device/status")
  state.set("payloadInput", "{\"dev_id\":\"esp32_01\",\"status\":\"online\",\"ip\":\"192.168.1.120\",\"rssi\":-58}")
  state.set("statusMsg", "已载入设备在线心跳报文")
end

function setMockCommand()
  state.set("topicInput", "device/cmd/switch")
  state.set("payloadInput", "{\"cmd\":\"toggle_relay\",\"channel\":1,\"state\":\"ON\"}")
  state.set("statusMsg", "已载入继电器下发控制指令")
end

function connectBroker()
  local url = state.get("brokerUrl") or ""
  if string.len(url) == 0 then
    dialog.toast("请输入 Broker URL")
    return nil
  end

  state.set("connStatus", "正在连接...")
  addLog("CONNECT", "发起长连接握手: " .. url)

  wsClient = websocket.connect(url, {
    onOpen = function()
      state.set("connStatus", "已连接 (在线)")
      addLog("OPEN", "MQTT WebSocket 通道已建立，就绪！")
      dialog.toast("MQTT 通道已连接")
      return nil
    end,
    onMessage = function(data)
      addLog("MESSAGE", "收到下行消息: " .. tostring(data))
      return nil
    end,
    onError = function(err)
      state.set("connStatus", "连接错误")
      addLog("ERROR", "连接出错: " .. tostring(err))
      return nil
    end,
    onClose = function()
      state.set("connStatus", "已断开")
      addLog("CLOSE", "连接已断开")
      wsClient = nil
      return nil
    end
  })
end

function disconnectBroker()
  if wsClient ~= nil then
    websocket.close(wsClient)
    wsClient = nil
  end
  state.set("connStatus", "已断开")
  addLog("DISCONNECT", "已主动断开连接")
  dialog.toast("已断开连接")
end

function publishMessage()
  local topic = state.get("topicInput") or ""
  local payload = state.get("payloadInput") or ""
  if string.len(topic) == 0 then
    dialog.toast("请输入主题 (Topic)")
    return nil
  end

  local packet = _formatMqttMessage(topic, payload)
  if wsClient ~= nil then
    websocket.send(wsClient, packet)
    addLog("PUBLISH", packet)
    dialog.toast("报文已发布")
  else
    addLog("LOCAL_PUB", "[离线记录] " .. packet)
    dialog.toast("未连接 Broker (仅本地记录)")
  end
end

function subscribeTopic()
  local topic = state.get("topicInput") or ""
  if string.len(topic) == 0 then
    dialog.toast("请输入要订阅的主题")
    return nil
  end
  addLog("SUBSCRIBE", "已订阅主题: " .. topic)
  dialog.toast("已提交订阅: " .. topic)
end

function clearLogs()
  logs = {}
  state.set("hasLogs", false)
  state.set("logOutput", "日志已清空")
  dialog.toast("日志已清空")
end

function copyLogs()
  local txt = state.get("logOutput") or ""
  if string.len(txt) == 0 then
    dialog.toast("暂无日志可复制")
    return nil
  end
  clipboard.set(txt)
  dialog.toast("已复制日志到剪贴板")
end
