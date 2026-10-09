-- ai_writer_tool main.lua
-- AI 随身助手与润色工具

local currentMode = "周报润色"

function _buildPrompt(mode, input)
  local m = mode or "周报润色"
  local txt = input or ""

  local systemDesc = "你是一位精通职场写作与工程技术的高级专家助手。"
  if m == "周报润色" then
    systemDesc = "请将用户的口语化工作备忘整理为结构严谨、条理清晰的职场周报总结，包含本周重点进展、交付成果与下周规划。"
  elseif m == "中英互译" then
    systemDesc = "请对用户的输入进行高水准专业中英文双向互译，译文需地道自然、信达雅。"
  elseif m == "代码解释" then
    systemDesc = "请分析用户的代码片段，解释其核心设计逻辑、潜在边界问题与时间空间复杂度。"
  elseif m == "要点提炼" then
    systemDesc = "请快速提炼用户长文的核心事实与关键结论，以数字标号列出 3~5 条要点。"
  end

  return {
    system = systemDesc,
    user = txt
  }
end

function onInit()
  currentMode = "周报润色"

  state.set("promptMode", "周报润色")
  state.set("inputText", "")
  state.set("outputText", "")
  state.set("hasResult", false)
  state.set("statusText", "请在上方输入待处理的内容")
  return nil
end

function setModeWeekly()
  currentMode = "周报润色"
  state.set("promptMode", "周报润色")
  dialog.toast("已切换为周报润色模式")
  return nil
end

function setModeTranslate()
  currentMode = "中英互译"
  state.set("promptMode", "中英互译")
  dialog.toast("已切换为中英互译模式")
  return nil
end

function setModeCode()
  currentMode = "代码解释"
  state.set("promptMode", "代码解释")
  dialog.toast("已切换为代码解释模式")
  return nil
end

function setModeSummary()
  currentMode = "要点提炼"
  state.set("promptMode", "要点提炼")
  dialog.toast("已切换为要点提炼模式")
  return nil
end

function generateAi()
  local txt = state.get("inputText")
  if txt == nil or string.len(txt) == 0 then
    dialog.toast("请先输入待处理的内容")
    return nil
  end

  ai.isAvailable(function(avail)
    if avail ~= true then
      dialog.toast("宿主 AI 网关未启用或当前无可用大语言模型配额")
      state.set("statusText", "宿主 AI 模型网关暂不可用")
      return nil
    end

    state.set("statusText", "AI 模型正在深度思考生成中，请稍候...")
    local bundle = _buildPrompt(currentMode, txt)

    local req = {
      messages = {
        {
          role = "system",
          content = bundle.system
        },
        {
          role = "user",
          content = bundle.user
        }
      },
      temperature = 0.7
    }

    ai.chat(req, function(res)
      if res ~= nil and res.ok == true then
        local reply = res.content or "无生成文本"
        state.set("outputText", reply)
        state.set("hasResult", true)
        state.set("statusText", "生成完成！")
        dialog.toast("AI 处理完成")
      else
        local err = (res and res.error) or "模型调用失败"
        state.set("statusText", "生成错误: " .. tostring(err))
        dialog.toast("生成未成功")
      end
      return nil
    end)

    return nil
  end)

  return nil
end

function copyResult()
  local out = state.get("outputText")
  if out ~= nil and string.len(out) > 0 then
    clipboard.set(out)
    dialog.toast("已复制结果到剪贴板")
  end
  return nil
end

function clearText()
  state.set("inputText", "")
  state.set("outputText", "")
  state.set("hasResult", false)
  state.set("statusText", "已清空")
  dialog.toast("输入已清空")
  return nil
end
