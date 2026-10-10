-- AI 学术论文与地道英文润色

local currentTone = "formal"

local toneDescriptions = {
    formal = "严谨学术 (Formal Academic): 遵循 IEEE/Nature 规范，消解口语化，强化客观论证与被动/主动平衡",
    concise = "精炼紧凑 (Concise & Dense): 剔除冗余虚词，合并主谓短语，最大化摘要与字数受限场景信息密度",
    native = "母语流利 (Native Speaker): 消除中式英语痕迹，运用丰富学术动词与起承转合衔接词"
}

function onInit()
    currentTone = "formal"
    local defaultInput = "In this paper, we try to use a new method to fix the latency issue. It is very useful and makes the system run much more faster than before."

    state.set("inputPaperText", defaultInput)
    state.set("toneDesc", toneDescriptions.formal)
    state.set("proofreadOutput", "【润色推荐】\nIn this paper, we propose a novel framework to mitigate the latency bottleneck. Empirical evaluations demonstrate that the proposed approach substantially outperforms existing baselines in computational efficiency.\n\n【学术升阶动词】\n• try to use -> propose / leverage\n• fix the issue -> mitigate the bottleneck\n• very useful / much more faster -> substantially outperforms existing baselines")
    state.set("statusText", "就绪：输入英文草稿后点击「AI 深度学术润色」")
    return nil
end

function setTone(tone)
    currentTone = tone or "formal"
    state.set("toneDesc", toneDescriptions[currentTone] or toneDescriptions.formal)
    dialog.toast("已切换润色风格: " .. (tone == "formal" and "严谨学术" or (tone == "concise" and "精炼紧凑" or "母语流利")))
    return nil
end

function proofread()
    local text = state.get("inputPaperText") or ""
    if string.len(text) == 0 then
        dialog.toast("请输入待润色的英文文本")
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

        state.set("statusText", "AI 语言学专家正在进行语法诊断与地道学术润色...")

        local tonePrompt = "风格偏好：严谨学术 (Formal Academic)"
        if currentTone == "concise" then
            tonePrompt = "风格偏好：精炼紧凑 (Concise & Dense)，尽可能缩减篇幅"
        elseif currentTone == "native" then
            tonePrompt = "风格偏好：母语地道流利 (Native English Flow)"
        end

        local sysPrompt = "你是一位常年担任 Nature、IEEE Trans 与顶会审稿人的资深学术母语英语润色专家。请对用户输入的学术论文草稿进行深度润色：\n" .. tonePrompt .. "\n输出规范：\n1. 【润色文稿】：输出地道流畅的高质量修改后英文\n2. 【语法与用词诊断】：标出原稿中的 Chinglish、语法风险或低级词汇\n3. 【学术升阶词汇映射】：列出核心动词与短语的学术级替换列表。"
        local userPrompt = text

        local req = {
            messages = {
                { role = "system", content = sysPrompt },
                { role = "user", content = userPrompt }
            },
            temperature = 0.3
        }

        ai.chat(req, function(res)
            if res ~= nil and res.ok == true then
                local content = res.content or "无润色文本"
                state.set("proofreadOutput", content)
                state.set("statusText", "学术论文润色完成！")
                dialog.toast("英文润色成功")
            else
                state.set("statusText", "润色失败: " .. tostring(res and res.error or "网络超时"))
                dialog.toast("润色未成功")
            end
            return nil
        end)
        return nil
    end)
    return nil
end

function loadSample()
    local sample = "We do a lot of experiments on the dataset. The result shows that our model can get good performance in image recognition."
    state.set("inputPaperText", sample)
    dialog.toast("已载入计算机视觉论文摘要草稿样例")
    return nil
end

function copyResult()
    local text = state.get("proofreadOutput") or ""
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("润色成果已复制到剪贴板")
    return nil
end
