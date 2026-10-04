-- base64_tool — Base64 与 URL 编解码 (v1.1.0 增强版)
-- 在 sample_plugins 基础版之上新增 URL 编解码与剪贴板粘贴

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _doEncode(text)
  return codec.base64Encode(text)
end

function _doDecode(text)
  local ok, res = pcall(codec.base64Decode, text)
  if ok then return res end
  return nil
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("inputText", "")
  state.set("resultText", "")
  clearError()
end

local function requireInput(failMsg)
  local input = state.get("inputText") or ""
  if input == "" then
    clearError()
    state.set("resultText", "")
    setError(failMsg)
    return nil
  end
  return input
end

function encode()
  local input = requireInput("请输入要编码的文本内容")
  if input == nil then return nil end
  state.set("resultText", codec.base64Encode(input))
  clearError()
  dialog.toast("Base64 编码完成")
end

function decode()
  local input = requireInput("请输入要解码的 Base64 字符串")
  if input == nil then return nil end
  local ok, res = pcall(codec.base64Decode, input)
  if ok then
    state.set("resultText", res)
    clearError()
    dialog.toast("Base64 解码完成")
  else
    setError("解码失败: 输入的不是合法的 Base64 格式")
  end
end

function urlEncode()
  local input = requireInput("请输入要编码的文本内容")
  if input == nil then return nil end
  state.set("resultText", codec.urlEncode(input))
  clearError()
  dialog.toast("URL 编码完成")
end

function urlDecode()
  local input = requireInput("请输入要解码的 URL 字符串")
  if input == nil then return nil end
  local ok, res = pcall(codec.urlDecode, input)
  if ok then
    state.set("resultText", res)
    clearError()
    dialog.toast("URL 解码完成")
  else
    setError("URL 解码失败: 含非法转义序列")
  end
end

function swapText()
  state.set("inputText", state.get("resultText") or "")
  state.set("resultText", state.get("inputText") or "")
end

function pasteInput()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("inputText", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
