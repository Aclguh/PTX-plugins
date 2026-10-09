-- ai_regex_tool — AI 正则表达与解析大师
-- 通过自然语言输入生成高精度正则表达式，输出捕获组拆解与边界测试用例

function _buildRegexPrompt(req)
  local r = req or "匹配手机号"
  local sys = "你是一位精通各类编程语言正则表达式的资深算法专家。请根据用户的自然语言需求生成最佳正则表达式。输出必须包含：1. 核心正则表达式；2. 捕获组与修饰符语法拆解；3. 典型正向匹配用例与反向拦截用例；4. 常见陷阱与灾难性回溯防护建议。"
  return {
    system = sys,
    user = "需求描述：" .. r
  }
end

-- ---------------- UI 事件 ----------------
function onInit()
  state.set("inputPrompt", "匹配中国大陆 11 位手机号码（允许带 +86 前缀或空格）")
  state.set("resultText", "输入自然语言需求后点击「AI 生成正则」")
  state.set("hasResult", true)
  state.set("statusMsg", "AI 正则引擎就绪")
end

function presetPhone()
  state.set("inputPrompt", "匹配中国大陆 11 位手机号码（允许带 +86 前缀与空格分隔）")
  state.set("statusMsg", "已载入手机号码正则需求")
end

function presetEmail()
  state.set("inputPrompt", "RFC5322 兼容的电子邮箱地址格式校验正则")
  state.set("statusMsg", "已载入电子邮箱正则需求")
end

function presetIp()
  state.set("inputPrompt", "匹配合法的 IPv4 地址及可选的端口号 (0-65535)")
  state.set("statusMsg", "已载入 IP 端口正则需求")
end

function presetPassword()
  state.set("inputPrompt", "强密码校验：8-20位，必须包含大写字母、小写字母、数字和特殊字符")
  state.set("statusMsg", "已载入强密码正则需求")
end

function generateRegex()
  local req = state.get("inputPrompt") or ""
  if string.len(req) == 0 then
    dialog.toast("请输入正则表达式需求描述")
    return nil
  end

  state.set("statusMsg", "AI 正在分析语义并构建正则表达式...")
  local p = _buildRegexPrompt(req)

  ai.chat({
    { role = "system", content = p.system },
    { role = "user", content = p.user }
  }, function(res)
    if res ~= nil and res.ok == true and res.content ~= nil then
      state.set("resultText", res.content)
      state.set("statusMsg", "正则表达式生成完毕！")
      dialog.toast("生成成功")
    else
      local err = "AI 服务无响应"
      if res ~= nil and res.error ~= nil then err = res.error end
      state.set("resultText", "【生成失败】\n" .. err)
      state.set("statusMsg", "生成失败，请检查 AI 配置")
      dialog.toast("AI 调用失败")
    end
    return nil
  end)
end

function copyResult()
  local txt = state.get("resultText") or ""
  if string.len(txt) == 0 then
    dialog.toast("暂无结果可复制")
    return nil
  end
  clipboard.set(txt)
  dialog.toast("已复制正则解析报告")
end
