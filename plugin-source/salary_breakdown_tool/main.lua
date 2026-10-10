-- 五险一金与薪资筹划对比器

local currentCity = "beijing"

local cityConfigs = {
    beijing = { name = "北京", minBase = 6326, maxBase = 35283, fundRate = 0.12, medExtra = 3 },
    shanghai = { name = "上海", minBase = 7310, maxBase = 36549, fundRate = 0.07, medExtra = 0 },
    shenzhen = { name = "深圳", minBase = 2520, maxBase = 35283, fundRate = 0.05, medExtra = 0 },
    standard = { name = "全国基准", minBase = 5000, maxBase = 30000, fundRate = 0.08, medExtra = 0 }
}

local function calcTax(taxable)
    if taxable <= 0 then
        return 0, 0, 0
    end
    if taxable <= 3000 then return taxable * 0.03, 0.03, 0 end
    if taxable <= 12000 then return taxable * 0.10 - 210, 0.10, 210 end
    if taxable <= 25000 then return taxable * 0.20 - 1410, 0.20, 1410 end
    if taxable <= 35000 then return taxable * 0.25 - 2660, 0.25, 2660 end
    if taxable <= 55000 then return taxable * 0.30 - 4410, 0.30, 4410 end
    if taxable <= 80000 then return taxable * 0.35 - 7160, 0.35, 7160 end
    return taxable * 0.45 - 15160, 0.45, 15160
end

local function calcBonusTaxSeparate(bonus)
    if bonus <= 0 then return 0 end
    local m = bonus / 12.0
    if m <= 3000 then return bonus * 0.03 end
    if m <= 12000 then return bonus * 0.10 - 210 end
    if m <= 25000 then return bonus * 0.20 - 1410 end
    if m <= 35000 then return bonus * 0.25 - 2660 end
    if m <= 55000 then return bonus * 0.30 - 4410 end
    if m <= 80000 then return bonus * 0.35 - 7160 end
    return bonus * 0.45 - 15160
end

local function computeAll()
    local gross = tonumber(state.get("inputGross") or "15000") or 15000
    local deduct = tonumber(state.get("inputDeduct") or "1500") or 1500
    local bonus = tonumber(state.get("inputBonus") or "30000") or 30000

    local cfg = cityConfigs[currentCity] or cityConfigs.beijing
    local base = gross
    if base < cfg.minBase then base = cfg.minBase end
    if base > cfg.maxBase then base = cfg.maxBase end

    -- 个人缴纳明细
    local pension = base * 0.08
    local medical = base * 0.02 + cfg.medExtra
    local unemp = base * 0.005
    local fund = base * cfg.fundRate
    local totalSocial = pension + medical + unemp + fund

    -- 个人所得税 (免征额 5000)
    local taxable = gross - totalSocial - 5000 - deduct
    if taxable < 0 then taxable = 0 end
    local tax = calcTax(taxable)

    local netSalary = gross - totalSocial - tax

    -- 年终奖筹划
    local bonusTaxSep = calcBonusTaxSeparate(bonus)
    local bonusNetSep = bonus - bonusTaxSep

    -- 合并计税估算
    local bonusTaxCombined = calcTax(taxable + bonus) - tax
    if bonusTaxCombined < 0 then bonusTaxCombined = 0 end
    local bonusNetComb = bonus - bonusTaxCombined

    local planAdvice = ""
    if bonusTaxSep <= bonusTaxCombined then
        local saved = bonusTaxCombined - bonusTaxSep
        planAdvice = string.format("推荐【单独计税】：省税 %.2f 元 (单独税: %.2f 元, 合并税: %.2f 元)", saved, bonusTaxSep, bonusTaxCombined)
    else
        local saved = bonusTaxSep - bonusTaxCombined
        planAdvice = string.format("推荐【合并计税】：省税 %.2f 元 (合并税: %.2f 元, 单独税: %.2f 元)", saved, bonusTaxCombined, bonusTaxSep)
    end

    state.set("netDisplay", string.format("¥ %.2f", netSalary))
    state.set("socialDetail", string.format("五险一金个人共扣: ¥ %.2f (养老: %.1f, 医疗: %.1f, 失业: %.1f, 公积金: %.1f)",
        totalSocial, pension, medical, unemp, fund))
    state.set("taxDetail", string.format("个税扣除: ¥ %.2f (应纳税所得额: ¥ %.2f)", tax, taxable))
    state.set("bonusAdvice", planAdvice)
    state.set("bonusSummary", string.format("年终奖实际到手: ¥ %.2f (税后)", bonusNetSep))
    state.set("cityLabel", "当前城市基准: " .. cfg.name)
    return nil
end

function onInit()
    currentCity = "beijing"
    state.set("inputGross", "15000")
    state.set("inputDeduct", "1500")
    state.set("inputBonus", "30000")

    computeAll()
    return nil
end

function calculateSalary()
    computeAll()
    dialog.toast("薪资与五险一金计算完毕")
    return nil
end

function setCity(city)
    currentCity = city or "beijing"
    computeAll()
    dialog.toast("已切换为城市: " .. (cityConfigs[city] and cityConfigs[city].name or city))
    return nil
end

function copySummary()
    local text = string.format("薪资与五险一金精算报告:\n%s\n税后实发月薪: %s\n%s\n%s\n%s\n%s",
        state.get("cityLabel") or "",
        state.get("netDisplay") or "",
        state.get("socialDetail") or "",
        state.get("taxDetail") or "",
        state.get("bonusSummary") or "",
        state.get("bonusAdvice") or "")
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("薪资报告已复制到剪贴板")
    return nil
end
