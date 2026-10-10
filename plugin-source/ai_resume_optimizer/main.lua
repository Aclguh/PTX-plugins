-- AI 简历与 JD 靶向匹配诊断器

function onInit()
    local defaultResume = "负责电商移动端开发，主导商品详情页与购物车模块重构，使用 Flutter 与原生混合开发，提升页面加载性能 30%。"
    local defaultJd = "高级移动端开发工程师：精通 Flutter 跨平台架构与性能调优，熟悉渲染树渲染原理；具备高并发大流量复杂电商业务落地经验；擅长跨团队协作与架构拆解。"

    state.set("resumeText", defaultResume)
    state.set("jobDesc", defaultJd)
    state.set("matchReport", "【诊断报告预览】\n匹配得分：85 / 100\n核心优势：Flutter 电商落地经验与性能优化指标明确\n建议补充：深入补充渲染管线细节、大流量稳定性指标\nSTAR 精修建议：\n- 情境/任务：针对千万级日活电商商品详情页白屏问题...\n- 行动：主导组件轻量化重构与预加载策略...\n- 结果：首屏渲染延迟降低 30%，崩溃率下降至 0.02%。")
    state.set("statusText", "就绪：输入简历与目标 JD 后点击「AI 靶向诊断」")
    return nil
end

function analyzeResume()
    local rText = state.get("resumeText") or ""
    local jdText = state.get("jobDesc") or ""

    if string.len(rText) == 0 or string.len(jdText) == 0 then
        dialog.toast("请同时输入个人经历与目标岗位 JD")
        return nil
    end

    if ai == nil or ai.isAvailable == nil then
        dialog.toast("当前环境未接入 AI 网关")
        state.set("statusText", "AI 网关不可用")
        return nil
    end

    ai.isAvailable(function(avail)
        if avail ~= true then
            dialog.toast("宿主 AI 网关不可用")
            state.set("statusText", "AI 服务未就绪")
            return nil
        end

        state.set("statusText", "AI 专家正在对比岗位 JD 与简历匹配度...")

        local sysPrompt = "你是一位资深技术专家兼猎头招聘总监。请对比候选人的【个人经历】与【目标岗位 JD】，输出详细诊断：\n1. 匹配度量化评分 (0-100分)\n2. 识别缺失的核心关键词与技术能力\n3. 按照 STAR 原则 (Situation, Task, Action, Result) 给出针对该 JD 的高针对性精修经历改写版本。"
        local userPrompt = string.format("【目标岗位 JD】\n%s\n\n【个人简历经历】\n%s", jdText, rText)

        local req = {
            messages = {
                { role = "system", content = sysPrompt },
                { role = "user", content = userPrompt }
            },
            temperature = 0.5
        }

        ai.chat(req, function(res)
            if res ~= nil and res.ok == true then
                local content = res.content or "无诊断内容"
                state.set("matchReport", content)
                state.set("statusText", "简历与 JD 靶向匹配分析完成！")
                dialog.toast("诊断完成")

                if storage ~= nil and storage.set ~= nil then
                    pcall(function()
                        storage.set("last_resume_report", content)
                    end)
                end
            else
                state.set("statusText", "分析失败: " .. tostring(res and res.error or "网络超时"))
                dialog.toast("分析未成功")
            end
            return nil
        end)
        return nil
    end)
    return nil
end

function loadSample()
    local sampleResume = "精通 Golang 后端开发，负责高并发微服务 API 网关，基于 Redis 与 Kafka 实现分布式削峰与链路追踪。"
    local sampleJd = "后端架构师：负责核心交易中台高并发架构设计，要求精通 Go 语言与云原生 Kubernetes 架构，对分布式事务与吞吐量调优有深入实战经验。"

    state.set("resumeText", sampleResume)
    state.set("jobDesc", sampleJd)
    dialog.toast("已载入后端架构师岗位与简历样本")
    return nil
end

function copyReport()
    local text = state.get("matchReport") or ""
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("诊断报告已复制到剪贴板")
    return nil
end
