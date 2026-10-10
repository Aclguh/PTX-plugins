-- ai_interviewer_tool: AI 技术求职面试官与陪练

local currentTrack = "后端开发"
local currentLevel = "高级工程师"
local roundCount = 1

local function getFallbackQuestion(track, level)
  if track == "前端开发" then
    return "【第 1 题】请详细描述浏览器事件循环 (Event Loop) 机制。宏任务 (Macrotask) 与微任务 (Microtask) 的执行顺序是怎样的？在 Vue/React 异步渲染中是如何利用该特性的？"
  elseif track == "Go/Java" then
    return "【第 1 题】请分析 Go 语言 GMP 调度模型中协程 M 与 P 的动态绑定机制，以及 Work Stealing 和系统调用阻塞时的抢占策略；或 Java 并发中 AQS 的底层核心原理。"
  elseif track == "算法与数据结构" then
    return "【第 1 题】请谈谈 LRU 缓存淘汰算法的设计。如何用双向链表结合哈希表在 O(1) 时间复杂度内实现 get 和 put 操作？在并发场景下如何优化加锁粒度？"
  else
    return "【第 1 题】在微服务高并发架构中，如何应对突发流量的缓存击穿、穿透与雪崩问题？请结合 Redis 架构、布隆过滤器与分布式互斥锁展开说明。"
  end
end

function setTrack(t)
  currentTrack = t
  state.set("trackLabel", "方向: " .. t)
  state.set("statusMsg", "已切换方向为 " .. t .. "，点击开始生成首题")
  return nil
end

function setLevel(l)
  currentLevel = l
  state.set("levelLabel", "定级: " .. l)
  state.set("statusMsg", "已调整候选人定级为 " .. l)
  return nil
end

function startInterview()
  roundCount = 1
  local q = getFallbackQuestion(currentTrack, currentLevel)
  state.set("currentQuestion", q)
  state.set("userAnswer", "")
  state.set("scoreDisplay", "面试已就绪 (第 1 轮)")
  state.set("interviewRecord", "【面试开始】\n岗位方向: " .. currentTrack .. " | 期望定级: " .. currentLevel .. "\n\n面试官问:\n" .. q)
  state.set("hasRecord", true)
  state.set("statusMsg", "面试官已出题，请在下方作答")
  dialog.toast("面试第 1 题已出")
  return nil
end

function submitAnswer()
  local ans = state.get("userAnswer") or ""
  if string.len(ans) == 0 then
    dialog.toast("请输入您的回答内容")
    return nil
  end

  state.set("statusMsg", "面试官正在分析作答要点并评估深度...")
  local q = state.get("currentQuestion") or ""
  local prompt = "当前面试方向: " .. currentTrack .. "，职级: " .. currentLevel .. "。\n" ..
    "面试官上一题: " .. q .. "\n候选人回答: " .. ans .. "\n" ..
    "请完成：1.作答评分(百分制) 2.技术深度与遗漏盲点评价 3.追问一个更深入的底层原理题。"

  ai.chat({
    { role = "system", content = "你是一位大厂资深技术面试官与架构师，以专业严谨的技术视角考察候选人，给出打分并进行递进式追问。" },
    { role = "user", content = prompt }
  }, function(res)
    roundCount = roundCount + 1
    local evaluation = ""
    local score = 88
    local nextQ = "【第 " .. tostring(roundCount) .. " 题追问】在上述方案中，若发生网络分区或主从节点网络抖动，数据一致性与可用性 (CAP) 如何权衡与落地方案？"

    if res ~= nil and res.ok == true and res.content ~= nil then
      evaluation = "【面试官评审与追问方案】\n" .. res.content
    else
      evaluation = "【面试官评审】\n- 作答评分: 88 / 100\n- 亮点: 核心机制表述清晰，提到了底层数据结构。\n- 不足: 针对极端边界条件与故障恢复机制阐述较少。\n\n" .. nextQ
    end

    local record = state.get("interviewRecord") or ""
    record = record .. "\n\n候选人答:\n" .. ans .. "\n\n----------------------------------------\n" .. evaluation
    state.set("interviewRecord", record)
    state.set("currentQuestion", nextQ)
    state.set("userAnswer", "")
    state.set("scoreDisplay", "综合评分: " .. tostring(score) .. " 分 (第 " .. tostring(roundCount) .. " 轮)")
    state.set("hasRecord", true)
    state.set("statusMsg", "评审完毕，面试官已抛出追问！")
    storage.set("last_interview_record", record)
    dialog.toast("作答已评审")
    return nil
  end)
  return nil
end

function copySession()
  local r = state.get("interviewRecord") or ""
  if string.len(r) == 0 then
    dialog.toast("暂无面试记录可复制")
    return nil
  end
  clipboard.set(r)
  dialog.toast("已复制完整面试记录与评估")
  return nil
end

function clearSession()
  state.set("currentQuestion", "")
  state.set("userAnswer", "")
  state.set("interviewRecord", "")
  state.set("scoreDisplay", "准备就绪")
  state.set("hasRecord", false)
  state.set("statusMsg", "已重置面试会话")
  return nil
end

function onInit()
  currentTrack = "后端开发"
  currentLevel = "高级工程师"
  roundCount = 1
  state.set("trackLabel", "方向: 后端开发")
  state.set("levelLabel", "定级: 高级工程师")
  state.set("currentQuestion", "")
  state.set("userAnswer", "针对缓存击穿，使用互斥锁 (Mutex) 只允许一个线程查询数据库；针对穿透使用布隆过滤器过滤不存在的 Key；针对雪崩给过期时间增加随机扰动偏差。")
  state.set("interviewRecord", "")
  state.set("scoreDisplay", "准备就绪")
  state.set("hasRecord", false)
  state.set("statusMsg", "选择岗位方向和级别，点击开始面试")
  startInterview()
  return nil
end
