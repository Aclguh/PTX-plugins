-- ai_mindmap_tool: AI 思维导图与知识大纲生成器

local currentFormat = "markdown"

local function buildSampleData(sampleType)
  if sampleType == "product" then
    return "新一代智能协作办公软件产品发布会筹划，涵盖产品核心亮点演示、渠道宣发矩阵、技术架构分享与早期种子用户招募策略。"
  elseif sampleType == "study" then
    return "系统学习 Rust 语言与系统级编程全景指南，包括所有权与生命周期借用检查、并发无畏安全、Cargo 生态与 WebAssembly 跨平台编译实战。"
  else
    return "现代分布式微服务架构演进设计，包括服务注册发现、API 网关鉴权限流、分布式事务与 Seata、可观测性链路追踪与混沌工程韧性测试。"
  end
end

local function getFallbackTree(topic, fmt)
  if fmt == "mermaid" then
    return "mindmap\n" ..
      "  root((分布式架构演进))\n" ..
      "    服务网格治理\n" ..
      "      注册与发现(Consul/Nacos)\n" ..
      "      智能路由与限流(Sentinel)\n" ..
      "    数据一致性\n" ..
      "      两阶段提交(2PC)\n" ..
      "      最终一致性(TCC/Saga)\n" ..
      "    可观测体系\n" ..
      "      链路追踪(OpenTelemetry)\n" ..
      "      指标度量(Prometheus)\n" ..
      "      统一日志(ELK Stack)"
  elseif fmt == "tree" then
    return "【分布式架构演进】\n" ..
      "├── 1. 服务网格与流量治理\n" ..
      "│   ├── 注册与发现 (Consul / Nacos / Eureka)\n" ..
      "│   └── 智能路由与自适应限流 (Sentinel / Envoy)\n" ..
      "├── 2. 分布式数据与事务一致性\n" ..
      "│   ├── 强一致性模型 (Raft / Paxos / 2PC)\n" ..
      "│   └── 最终一致性解决方案 (TCC / Saga / 本地消息表)\n" ..
      "└── 3. 全链路可观测性基座\n" ..
      "    ├── 分布式追踪 (OpenTelemetry / Jaeger)\n" ..
      "    ├── 实时指标告警 (Prometheus + Grafana)\n" ..
      "    └── 统一高吞吐日志分析 (Elasticsearch / ClickHouse)"
  else
    return "# 分布式架构演进设计\n\n" ..
      "## 1. 服务网格与流量治理\n" ..
      "- **注册与发现**: 动态节点心跳探活与健康检查 (Nacos / Consul)\n" ..
      "- **智能路由与熔断**: 基于滑动窗口的自适应限流与降级防护 (Sentinel)\n\n" ..
      "## 2. 分布式数据与事务一致性\n" ..
      "- **强一致性共识**: Raft 算法选举与复制日志\n" ..
      "- **最终一致性实践**: TCC 补偿模式与可靠消息最终一致方案\n\n" ..
      "## 3. 全链路可观测性与高可用保障\n" ..
      "- **分布式链路跟踪**: W3C Trace Context 与 OpenTelemetry 标准\n" ..
      "- **指标与告警闭环**: Prometheus 聚合与时序存储告警\n" ..
      "- **混沌工程**: 周期性网络延迟注入与节点宕机容灾演练"
  end
end

function setFormat(fmt)
  currentFormat = fmt
  state.set("formatLabel", "输出格式: " .. fmt)
  state.set("statusMsg", "已切换输出格式为 " .. fmt .. "，点击生成")
  return nil
end

function loadSample(sampleType)
  local t = buildSampleData(sampleType)
  state.set("inputTopic", t)
  state.set("hasResult", false)
  state.set("statusMsg", "已载入预设主题，点击生成导图大纲")
  return nil
end

function generateMindmap()
  local topic = state.get("inputTopic") or ""
  if string.len(topic) == 0 then
    dialog.toast("请输入知识主题或文本内容")
    return nil
  end

  state.set("statusMsg", "AI 知识架构师正在梳理思维层次与知识图谱...")
  local fallbackText = getFallbackTree(topic, currentFormat)

  local prompt = "请分析以下文本/主题，并生成清晰严谨的 " .. currentFormat .. " 层次思维导图：\n" .. topic

  ai.chat({
    { role = "system", content = "你是一位擅长将复杂知识点结构化的专业知识架构师，熟练运用 Markdown 与 Mermaid 语法。" },
    { role = "user", content = prompt }
  }, function(res)
    local result = ""
    if res ~= nil and res.ok == true and res.content ~= nil then
      result = "【AI 思维导图与知识大纲】\n" .. res.content .. "\n\n----------------\n" .. fallbackText
    else
      result = fallbackText
    end

    state.set("mindmapResult", result)
    state.set("hasResult", true)
    state.set("statusMsg", "思维导图与大纲生成完成！")
    storage.set("last_mindmap", result)
    dialog.toast("思维导图生成成功")
    return nil
  end)
  return nil
end

function copyResult()
  local r = state.get("mindmapResult") or ""
  if string.len(r) == 0 then
    dialog.toast("暂无导图内容可复制")
    return nil
  end
  clipboard.set(r)
  dialog.toast("已复制思维导图大纲")
  return nil
end

function clearAll()
  state.set("inputTopic", "")
  state.set("mindmapResult", "")
  state.set("hasResult", false)
  state.set("statusMsg", "已清空")
  return nil
end

function onInit()
  currentFormat = "markdown"
  state.set("formatLabel", "输出格式: markdown")
  state.set("inputTopic", "现代分布式微服务架构演进设计，包括服务注册发现、API 网关鉴权限流、分布式事务与 Seata、可观测性链路追踪与混沌工程韧性测试。")
  state.set("mindmapResult", "")
  state.set("hasResult", false)
  state.set("statusMsg", "准备就绪，点击开始生成思维导图")
  generateMindmap()
  return nil
end
