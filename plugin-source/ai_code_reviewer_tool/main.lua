-- ai_code_reviewer_tool — AI 代码审查与复杂度分析器
-- 针对代码片段评估边界 Bug、安全漏洞、时空复杂度与最佳实践重构

local currentLang = "Python"

local SNIPPET_RECURSION = "def fib(n):\n    if n <= 1:\n        return n\n    return fib(n-1) + fib(n-2)"
local SNIPPET_SQL_INJECTION = "def get_user(user_id):\n    sql = f\"SELECT * FROM users WHERE id = '{user_id}'\"\n    cursor.execute(sql)\n    return cursor.fetchall()"
local SNIPPET_QUICKSORT = "def quicksort(arr):\n    if len(arr) <= 1:\n        return arr\n    pivot = arr[len(arr) // 2]\n    left = [x for x in arr if x < pivot]\n    middle = [x for x in arr if x == pivot]\n    right = [x for x in arr if x > pivot]\n    return quicksort(left) + middle + quicksort(right)"

function _buildReviewPrompt(lang, code)
  local l = lang or "通用代码"
  local c = code or ""
  local sys = "你是一位大厂资深架构师兼代码审查专家。请对用户提供的 " .. l .. " 代码片段进行细致的代码审查 (Code Review)。输出必须包含以下四个维度：\n1. 【潜在 Bug 与边界风险】（空指针/溢出/资源释放/竞态条件）\n2. 【安全与合规漏洞】（注入风险/越权/敏感信息泄露）\n3. 【时空复杂度评估】（给出渐近时间复杂度与空间复杂度 Big-O 分析）\n4. 【优化重构建议与改进代码】（给出重构后的最佳实践代码样例）"
  return {
    system = sys,
    user = "待审查代码片段：\n```" .. l .. "\n" .. c .. "\n```"
  }
end

-- ---------------- UI 事件 ----------------
function onInit()
  currentLang = "Python"
  state.set("langLabel", "目标语言: Python")
  state.set("inputCode", SNIPPET_RECURSION)
  state.set("reviewResult", "点击「开始 AI 审查」获取专业评审报告")
  state.set("hasResult", true)
  state.set("statusMsg", "代码审查引擎就绪")
end

function setLangPython()
  currentLang = "Python"
  state.set("langLabel", "目标语言: Python")
  state.set("statusMsg", "已切换语言为 Python")
end

function setLangJavaScript()
  currentLang = "JavaScript"
  state.set("langLabel", "目标语言: JavaScript")
  state.set("statusMsg", "已切换语言为 JavaScript")
end

function setLangJava()
  currentLang = "Java"
  state.set("langLabel", "目标语言: Java")
  state.set("statusMsg", "已切换语言为 Java")
end

function setLangGo()
  currentLang = "Go"
  state.set("langLabel", "目标语言: Go")
  state.set("statusMsg", "已切换语言为 Go")
end

function loadSampleRecursion()
  currentLang = "Python"
  state.set("langLabel", "目标语言: Python")
  state.set("inputCode", SNIPPET_RECURSION)
  state.set("statusMsg", "已载入斐波那契递归样例 (性能缺陷)")
end

function loadSampleSql()
  currentLang = "Python"
  state.set("langLabel", "目标语言: Python")
  state.set("inputCode", SNIPPET_SQL_INJECTION)
  state.set("statusMsg", "已载入 SQL 拼接查询样例 (注入漏洞)")
end

function loadSampleSort()
  currentLang = "Python"
  state.set("langLabel", "目标语言: Python")
  state.set("inputCode", SNIPPET_QUICKSORT)
  state.set("statusMsg", "已载入快速排序样例 (算法分析)")
end

function reviewCode()
  local c = state.get("inputCode") or ""
  if string.len(c) == 0 then
    dialog.toast("请输入待审查的代码片段")
    return nil
  end

  state.set("statusMsg", "AI 架构师正在深入审查代码缺陷与复杂度...")
  local p = _buildReviewPrompt(currentLang, c)

  ai.chat({
    { role = "system", content = p.system },
    { role = "user", content = p.user }
  }, function(res)
    if res ~= nil and res.ok == true and res.content ~= nil then
      state.set("reviewResult", res.content)
      state.set("statusMsg", "代码审查报告已生成！")
      dialog.toast("审查完成")
    else
      local err = "AI 响应异常"
      if res ~= nil and res.error ~= nil then err = res.error end
      state.set("reviewResult", "【审查失败】\n" .. err)
      state.set("statusMsg", "审查失败，请检查 AI 配置")
      dialog.toast("调用失败")
    end
    return nil
  end)
end

function copyResult()
  local txt = state.get("reviewResult") or ""
  if string.len(txt) == 0 then
    dialog.toast("暂无报告可复制")
    return nil
  end
  clipboard.set(txt)
  dialog.toast("已复制审查报告")
end
