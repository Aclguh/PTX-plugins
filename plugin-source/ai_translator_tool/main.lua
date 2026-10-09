-- ai_translator_tool — AI 多语言地道翻译对比
-- 同时生成商务正式、日常地道口语与学术严谨三种风格译文

local currentTargetLang = "英语"

function _buildTranslatorPrompt(targetLang, text)
  local lang = targetLang or "英语"
  local txt = text or ""
  local sys = "你是一位精通多国语言本土化翻译的高级同声传译专家。请将用户输入的原文翻译为目标语言（" .. lang .. "）。输出格式必须严格划分为三个独立板块：\n1. 【商务正式版 (Business/Formal)】（适合邮件、商务汇报、合同交流）\n2. 【地道口语版 (Casual/Idiomatic)】（适合日常生活、社交媒体、朋友闲聊，包含地道俚语搭配）\n3. 【学术严谨版 (Academic/Precise)】（逻辑严密、用词考究精准）\n4. 【重点词汇与本土化解析】"
  return {
    system = sys,
    user = "待翻译原文：\n" .. txt
  }
end

-- ---------------- UI 事件 ----------------
function onInit()
  currentTargetLang = "英语"
  state.set("targetLang", "目标语言: 英语 (English)")
  state.set("inputSource", "我们这个季度优先攻坚核心性能瓶颈，下个迭代再考虑边缘功能拓展。")
  state.set("outputResult", "点击「开始深度翻译」获取三种风格对照")
  state.set("hasResult", true)
  state.set("statusMsg", "AI 翻译模型就绪")
end

function setLangEnglish()
  currentTargetLang = "英语"
  state.set("targetLang", "目标语言: 英语 (English)")
  state.set("statusMsg", "已切换目标语言为英语")
end

function setLangJapanese()
  currentTargetLang = "日语"
  state.set("targetLang", "目标语言: 日语 (Japanese)")
  state.set("statusMsg", "已切换目标语言为日语")
end

function setLangChinese()
  currentTargetLang = "中文"
  state.set("targetLang", "目标语言: 中文 (Chinese)")
  state.set("statusMsg", "已切换目标语言为中文")
end

function setLangGerman()
  currentTargetLang = "德语"
  state.set("targetLang", "目标语言: 德语 (German)")
  state.set("statusMsg", "已切换目标语言为德语")
end

function translateText()
  local src = state.get("inputSource") or ""
  if string.len(src) == 0 then
    dialog.toast("请输入待翻译的文本")
    return nil
  end

  state.set("statusMsg", "AI 正在多维度地道翻译与润色中...")
  local p = _buildTranslatorPrompt(currentTargetLang, src)

  ai.chat({
    { role = "system", content = p.system },
    { role = "user", content = p.user }
  }, function(res)
    if res ~= nil and res.ok == true and res.content ~= nil then
      state.set("outputResult", res.content)
      state.set("statusMsg", "翻译对比完成 (" .. currentTargetLang .. ")")
      dialog.toast("翻译完成")
    else
      local err = "AI 响应异常"
      if res ~= nil and res.error ~= nil then err = res.error end
      state.set("outputResult", "【翻译失败】\n" .. err)
      state.set("statusMsg", "翻译失败，请检查网络与 AI 权限")
      dialog.toast("AI 翻译失败")
    end
    return nil
  end)
end

function copyResult()
  local txt = state.get("outputResult") or ""
  if string.len(txt) == 0 then
    dialog.toast("暂无译文可复制")
    return nil
  end
  clipboard.set(txt)
  dialog.toast("已复制翻译对比结果")
end
