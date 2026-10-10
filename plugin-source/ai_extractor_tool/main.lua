-- 万能杂乱文本结构化抽取器

local currentTpl = "express"

local function buildPrompt(tpl, text)
    local sys = "你是一位精通自然语言理解与信息抽取的专家助手。请从用户输入的杂乱非结构化文本中精准提取关键实体，并必须以严格的 JSON 格式输出，不要输出任何多余解释。"
    if tpl == "express" then
        sys = sys .. " 模板【快递收发件】：提取 recipient(姓名), phone(手机号), province(省), city(市), district(区县), address(详细街道门牌), tracking_no(单号)。"
    elseif tpl == "meeting" then
        sys = sys .. " 模板【会议日程】：提取 topic(会议主题), time(起止时间), location(地点或链接), attendees(参会人列表), action_items(待办行动项列表)。"
    elseif tpl == "receipt" then
        sys = sys .. " 模板【账单转账】：提取 counterparty(交易对象), amount(金额数字), currency(币种), payment_method(支付方式), timestamp(时间), order_id(订单号)。"
    elseif tpl == "card" then
        sys = sys .. " 模板【名片信息】：提取 name(姓名), title(职位), company(公司组织), mobile(联系电话), email(邮箱), website(官方网站)。"
    end
    return sys, text
end

function onInit()
    currentTpl = "express"
    local sampleText = "张三丰 13800138000 广东省深圳市南山区科技园中区科苑路15号科兴科学园B3栋 顺丰单号SF1234567890"
    state.set("rawText", sampleText)
    state.set("tplTitle", "当前模板：快递与收发件地址")
    state.set("outputJson", "{\n  \"recipient\": \"张三丰\",\n  \"phone\": \"13800138000\",\n  \"city\": \"深圳市\",\n  \"tracking_no\": \"SF1234567890\"\n}")
    state.set("statusText", "就绪：输入杂乱文本后点击「AI 结构化提纯」")
    return nil
end

function setTemplate(tpl)
    currentTpl = tpl or "express"
    if tpl == "express" then
        state.set("tplTitle", "当前模板：快递与收发件地址")
        state.set("rawText", "寄件人：李雷 电话 13911112222 地址：北京市朝阳区酒仙桥路4号 798艺术区")
    elseif tpl == "meeting" then
        state.set("tplTitle", "当前模板：会议纪要与日程")
        state.set("rawText", "周五下午2点到4点在3号会议室开技术评审会，参会人有张工、李工和王总，会后需要李工产出架构设计文档并在周一前发邮件。")
    elseif tpl == "receipt" then
        state.set("tplTitle", "当前模板：账单流水与转账")
        state.set("rawText", "微信支付凭证：向【全家便利店科技园店】成功付款 28.50 元，支付方式为招商银行信用卡，交易单号 420000213820261010。")
    elseif tpl == "card" then
        state.set("tplTitle", "当前模板：名片与商务联络")
        state.set("rawText", "王建国 / 高级架构师 / 字节跳动技术部 / 手机: 18600008888 / 邮箱: wangjg@bytedance.com / 网址: www.bytedance.com")
    end
    dialog.toast("已切换抽取模板: " .. state.get("tplTitle"))
    return nil
end

function extractAi()
    local text = state.get("rawText") or ""
    if string.len(text) == 0 then
        dialog.toast("请先输入需要抽取的文本")
        return nil
    end

    if ai == nil or ai.isAvailable == nil then
        dialog.toast("当前环境未接入 AI 网关")
        state.set("statusText", "AI 网关不可用")
        return nil
    end

    ai.isAvailable(function(avail)
        if avail ~= true then
            dialog.toast("宿主 AI 网关不可用或无配额")
            state.set("statusText", "AI 服务未就绪")
            return nil
        end

        state.set("statusText", "大模型正在深度解析并提取实体字段...")
        local sysPrompt, userPrompt = buildPrompt(currentTpl, text)

        local req = {
            messages = {
                { role = "system", content = sysPrompt },
                { role = "user", content = userPrompt }
            },
            temperature = 0.2
        }

        ai.chat(req, function(res)
            if res ~= nil and res.ok == true then
                local content = res.content or "{}"
                state.set("outputJson", content)
                state.set("statusText", "结构化实体抽取完成！")
                dialog.toast("AI 结构化抽取成功")
            else
                state.set("statusText", "AI 抽取失败: " .. tostring(res and res.error or "未知错误"))
                dialog.toast("抽取未成功")
            end
            return nil
        end)
        return nil
    end)
    return nil
end

function copyJson()
    local text = state.get("outputJson") or ""
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("结构化 JSON 已复制到剪贴板")
    return nil
end
