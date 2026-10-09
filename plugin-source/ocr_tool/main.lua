-- ocr_tool main.lua
-- 离线 OCR 文字识别插件

local function splitLines(text)
  local lines = {}
  if text == nil then return lines end
  local len = string.len(text)
  if len == 0 then return lines end

  local start = 1
  while start <= len do
    local pos = string.find(text, "\n", start, true)
    if pos == nil then
      table.insert(lines, string.sub(text, start, len))
      break
    else
      table.insert(lines, string.sub(text, start, pos - 1))
      start = pos + 1
    end
  end
  return lines
end

function _parseLines(text)
  return splitLines(text)
end

function onInit()
  state.set("recognizedText", "")
  state.set("lineCount", 0)
  state.set("hasResult", false)
  state.set("showPlaceholder", true)
  state.set("statusText", "请点击上方按钮选取图片进行识别")
  return nil
end

function pickAndRecognize()
  state.set("statusText", "正在选取图片...")
  media.pickImage(function(relPath)
    if relPath == nil then
      state.set("statusText", "已取消选取图片")
      return nil
    end

    state.set("statusText", "正在识别文字中，请稍候...")
    vision.recognizeText(relPath, function(res)
      if res == nil then
        state.set("statusText", "识别失败: 未获取到返回数据")
        return nil
      end

      local ok = res.ok
      if ok == true then
        local text = res.text
        if text == nil then text = "" end
        local lines = splitLines(text)
        state.set("recognizedText", text)
        state.set("lineCount", #lines)
        state.set("hasResult", true)
        state.set("showPlaceholder", false)
        state.set("statusText", "识别完成")
      else
        local err = res.error
        if err == nil then err = "未能在图片中检测到文字" end
        state.set("statusText", "识别错误: " .. tostring(err))
      end
      return nil
    end)
    return nil
  end)
  return nil
end

function copyResult()
  local txt = state.get("recognizedText")
  if txt ~= nil then
    if string.len(txt) > 0 then
      clipboard.set(txt)
      dialog.toast("已复制到剪贴板")
    end
  end
  return nil
end

function clearResult()
  state.set("recognizedText", "")
  state.set("lineCount", 0)
  state.set("hasResult", false)
  state.set("showPlaceholder", true)
  state.set("statusText", "已清空，请点击上方按钮选取新图片")
  return nil
end
