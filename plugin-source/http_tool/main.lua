-- http_tool — HTTP 请求调试
-- 走宿主 network.get / network.post 异步回调契约; 响应体展示截断,
-- 完整内容经复制按钮进入剪贴板

local MAX_SHOW = 4000

local startTime = 0

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

local function trim(s)
  local a = 1
  local b = string.len(s)
  while a <= b and string.sub(s, a, a) == " " do a = a + 1 end
  while b >= a and string.sub(s, b, b) == " " do b = b - 1 end
  if a > b then return "" end
  return string.sub(s, a, b)
end

local function friendlyStatus(code)
  if code >= 200 then
    if code < 300 then return "成功" end
  end
  if code >= 300 then
    if code < 400 then return "重定向" end
  end
  if code >= 400 then
    if code < 500 then return "客户端错误" end
  end
  if code >= 500 then return "服务器错误" end
  return ""
end

-- 展示截断: 超长响应体保留前 MAX_SHOW 字符
function _truncate(s)
  if string.len(s) > MAX_SHOW then
    return string.sub(s, 1, MAX_SHOW) .. "\n... (已截断, 共 "
        .. string.len(s) .. " 字符, 复制按钮获取完整内容)"
  end
  return s
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("reqUrl", "")
  state.set("reqBody", "")
  state.set("reqCtype", "application/json")
  state.set("isPost", false)
  state.set("methodLbl", "当前方法: GET (点击切换)")
  state.set("respStatus", "")
  state.set("respShow", "")
  state.set("respFull", "")
  state.set("respMeta", "")
  state.set("hasResp", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
end

function toggleMethod()
  local cur = state.get("isPost")
  if cur then
    state.set("isPost", false)
    state.set("methodLbl", "当前方法: GET (点击切换)")
  else
    state.set("isPost", true)
    state.set("methodLbl", "当前方法: POST (点击切换)")
  end
end

function sendRequest()
  clearError()
  state.set("hasResp", false)
  local url = trim(state.get("reqUrl") or "")
  if url == "" then
    setError("请输入请求 URL")
    return nil
  end
  local prefixOk = string.sub(url, 1, 8) == "https://"
  if not prefixOk then
    prefixOk = string.sub(url, 1, 7) == "http://"
  end
  if not prefixOk then
    setError("URL 需以 http:// 或 https:// 开头")
    return nil
  end
  startTime = util.timestampMs()
  if state.get("isPost") then
    network.post(url, state.get("reqBody") or "",
        state.get("reqCtype") or "application/json")
  else
    network.get(url)
  end
end

function onNetworkResponse(status, body)
  local cost = util.timestampMs() - startTime
  local text = body or ""
  state.set("respStatus", status .. " " .. friendlyStatus(status))
  state.set("respShow", _truncate(text))
  state.set("respFull", text)
  state.set("respMeta", "耗时 " .. cost .. " ms · 响应 " .. string.len(text) .. " 字符")
  state.set("hasResp", true)
  clearError()
end

function onNetworkError(msg)
  setError("请求失败: " .. (msg or "未知错误"))
end
