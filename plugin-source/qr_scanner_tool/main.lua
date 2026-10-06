-- qr_scanner_tool — 扫码识别
-- 支持摄像头扫描、相册条码识别、类型分析与历史记录管理

local HISTORY_KEY = "qr_scanner_history"
local HISTORY_MAX = 10

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

-- 格式类型检测辅助函数
function _detectType(s)
  if s == nil or s == "" then
    return "未知"
  end
  local lower = string.lower(s)
  if string.find(lower, "http://", 1, true) == 1 or string.find(lower, "https://", 1, true) == 1 then
    return "网址链接"
  end
  if string.find(lower, "mailto:", 1, true) == 1 then
    return "电子邮件"
  end
  if string.find(lower, "tel:", 1, true) == 1 then
    return "电话号码"
  end
  if string.find(lower, "wifi:", 1, true) == 1 or string.find(s, "WIFI:", 1, true) == 1 then
    return "WiFi 配置"
  end
  -- 检测是否为全数字 (商品条形码如 EAN-13, UPC)
  local isAllDigits = true
  for i = 1, string.len(s) do
    local b = string.byte(s, i)
    if b < 48 or b > 57 then
      isAllDigits = false
      break
    end
  end
  if isAllDigits and string.len(s) >= 8 and string.len(s) <= 18 then
    return "数字条形码"
  end
  return "纯文本"
end

local function decodeHistory(raw)
  local items = {}
  if raw == nil or raw == "" then
    return items
  end
  local start = 1
  local len = string.len(raw)
  while start <= len do
    local nl = string.find(raw, "\n", start, true)
    local line
    if nl then
      line = string.sub(raw, start, nl - 1)
      start = nl + 1
    else
      line = string.sub(raw, start)
      start = len + 1
    end
    if line ~= "" then
      items[#items + 1] = codec.urlDecode(line)
    end
  end
  return items
end

local function refreshHistoryView(items)
  if #items == 0 then
    state.set("hasHistory", false)
    state.set("historyText", "")
    return nil
  end
  local lines = {}
  for i = 1, #items do
    local t = items[i]
    local preview = t
    if string.len(preview) > 50 then
      preview = string.sub(preview, 1, 47) .. "..."
    end
    lines[#lines + 1] = tostring(i) .. ". [" .. _detectType(t) .. "] " .. preview
  end
  state.set("historyText", table.concat(lines, "\n"))
  state.set("hasHistory", true)
end

local function addHistory(text)
  storage.get(HISTORY_KEY, function(raw)
    local items = decodeHistory(raw)
    for i = 1, #items do
      if items[i] == text then
        table.remove(items, i)
        break
      end
    end
    table.insert(items, 1, text)
    while #items > HISTORY_MAX do
      table.remove(items)
    end
    local encoded = {}
    for _, item in ipairs(items) do
      encoded[#encoded + 1] = codec.urlEncode(item)
    end
    storage.set(HISTORY_KEY, table.concat(encoded, "\n"))
    refreshHistoryView(items)
  end)
end

local function onBarcodeDetected(code)
  if code == nil or code == "" then
    setError("未识别到有效的条码或二维码")
    return nil
  end
  clearError()
  state.set("resultText", code)
  state.set("resultType", _detectType(code))
  state.set("hasResult", true)
  addHistory(code)
  dialog.toast("识别成功")
end

-- ---------------- 插件生命周期与 UI 事件 ----------------

function onInit()
  state.set("hasResult", false)
  state.set("resultText", "")
  state.set("resultType", "")
  clearError()
  storage.get(HISTORY_KEY, function(raw)
    local items = decodeHistory(raw)
    refreshHistoryView(items)
  end)
end

function startScan()
  clearError()
  camera.scan(function(code)
    if code and code ~= "" then
      onBarcodeDetected(code)
    else
      setError("扫码已取消或未检测到条码")
    end
  end)
end

function pickAndDecode()
  clearError()
  media.pickImage(function(path)
    if path and path ~= "" then
      camera.decodeImage(path, function(code)
        if code and code ~= "" then
          onBarcodeDetected(code)
        else
          setError("选取的图片中未识别到清晰条码")
        end
      end)
    else
      setError("未选择图片")
    end
  end)
end

function copyResult()
  local text = state.get("resultText") or ""
  if text == "" then
    dialog.toast("当前无识别内容")
    return nil
  end
  clipboard.set(text)
  dialog.toast("已复制到剪贴板")
end

function clearResult()
  state.set("hasResult", false)
  state.set("resultText", "")
  state.set("resultType", "")
  clearError()
end

function clearHistory()
  dialog.confirm("清空确认", "确定清空所有扫码历史记录吗？", function(ok)
    if ok then
      storage.set(HISTORY_KEY, "")
      state.set("hasHistory", false)
      state.set("historyText", "")
      dialog.toast("历史记录已清空")
    end
  end)
end
