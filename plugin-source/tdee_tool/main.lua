-- tdee_tool — 宏量营养素与 TDEE 饮食规划

local function strLen(s)
  if s == nil then return 0 end
  return string.len(s)
end

local function min(a, b)
  if a < b then return a else return b end
end

local function max(a, b)
  if a > b then return a else return b end
end

local ACTIVITY_FACTORS = { 1.2, 1.375, 1.55, 1.725 }
local ACTIVITY_WATER = { 0, 300, 500, 800 }

function _calc_macros(gender, weightKg, heightCm, ageYears, actIdx, goal, dietStyle)
  local w = tonumber(weightKg) or 0
  local h = tonumber(heightCm) or 0
  local a = tonumber(ageYears) or 0
  local act = tonumber(actIdx) or 1
  if act < 1 then act = 1 end
  if act > 4 then act = 4 end

  if w < 20 or w > 350 then
    return nil, "体重必须在 20 ~ 350 kg 之间"
  end
  if h < 50 or h > 260 then
    return nil, "身高必须在 50 ~ 260 cm 之间"
  end
  if a < 10 or a > 120 then
    return nil, "年龄必须在 10 ~ 120 岁之间"
  end

  -- Mifflin-St Jeor 公式
  local bmr = 10 * w + 6.25 * h - 5 * a
  if gender == "female" then
    bmr = bmr - 161
  else
    bmr = bmr + 5
  end
  bmr = math.floor(bmr + 0.5)

  local factor = ACTIVITY_FACTORS[act] or 1.2
  local tdee = math.floor(bmr * factor + 0.5)

  local targetCal = tdee
  if goal == "cut" then
    targetCal = tdee - 400
    if targetCal < bmr then
      targetCal = bmr
    end
  elseif goal == "bulk" then
    targetCal = tdee + 350
  end

  local pPct = 0.25
  local cPct = 0.50
  local fPct = 0.25

  if dietStyle == "high_protein" then
    pPct = 0.35
    cPct = 0.40
    fPct = 0.25
  elseif dietStyle == "low_fat" then
    pPct = 0.30
    cPct = 0.55
    fPct = 0.15
  end

  local proteinG = math.floor((targetCal * pPct) / 4 + 0.5)
  local carbsG = math.floor((targetCal * cPct) / 4 + 0.5)
  local fatG = math.floor((targetCal * fPct) / 9 + 0.5)

  local baseWater = w * 35
  local addWater = ACTIVITY_WATER[act] or 300
  local totalWater = math.floor(baseWater + addWater)

  return {
    bmr = bmr,
    tdee = tdee,
    targetCal = targetCal,
    proteinG = proteinG,
    carbsG = carbsG,
    fatG = fatG,
    proteinCal = math.floor(targetCal * pPct),
    carbsCal = math.floor(targetCal * cPct),
    fatCal = math.floor(targetCal * fPct),
    waterMl = totalWater,
    pPct = math.floor(pPct * 100),
    cPct = math.floor(cPct * 100),
    fPct = math.floor(fPct * 100)
  }, nil
end

function calculate()
  local gender = state.get("gender") or "male"
  local wStr = state.get("weight") or "70"
  local hStr = state.get("height") or "175"
  local aStr = state.get("age") or "26"
  local actIdx = tonumber(state.get("activityIndex") or "2") or 2
  local goal = state.get("goal") or "maintain"
  local dietStyle = state.get("dietStyle") or "balanced"

  local res, err = _calc_macros(gender, wStr, hStr, aStr, actIdx, goal, dietStyle)
  if res == nil then
    state.set("hasError", true)
    state.set("errorMsg", err or "计算错误")
    state.set("hasResult", false)
    return nil
  end

  state.set("resTargetCal", tostring(res.targetCal) .. " kcal")
  state.set("resEnergyDetail", "基础代谢 BMR: " .. tostring(res.bmr) .. " kcal | 每日能耗 TDEE: " .. tostring(res.tdee) .. " kcal")
  state.set("resProtein", tostring(res.proteinG) .. " g (" .. tostring(res.pPct) .. "% 供能)")
  state.set("resCarbs", tostring(res.carbsG) .. " g (" .. tostring(res.cPct) .. "% 供能)")
  state.set("resFat", tostring(res.fatG) .. " g (" .. tostring(res.fPct) .. "% 供能)")
  state.set("resWater", tostring(res.waterMl) .. " ml / 天")

  local copyMsg = "【每日热量与营养预算】\n" ..
                  "目标摄入热量: " .. tostring(res.targetCal) .. " kcal\n" ..
                  "BMR: " .. tostring(res.bmr) .. " kcal / TDEE: " .. tostring(res.tdee) .. " kcal\n" ..
                  "蛋白质: " .. tostring(res.proteinG) .. " g\n" ..
                  "碳水化合物: " .. tostring(res.carbsG) .. " g\n" ..
                  "健康脂肪: " .. tostring(res.fatG) .. " g\n" ..
                  "建议饮水量: " .. tostring(res.waterMl) .. " ml"
  state.set("copyText", copyMsg)

  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function setGoal(g)
  state.set("goal", g)
  calculate()
  return nil
end

function setGender(g)
  state.set("gender", g)
  calculate()
  return nil
end

function setDietStyle(d)
  state.set("dietStyle", d)
  calculate()
  return nil
end

function copyResult()
  local text = state.get("copyText") or ""
  if text ~= "" and clipboard and clipboard.set then
    clipboard.set(text)
  end
  if dialog and dialog.toast then
    dialog.toast("已复制营养预算方案")
  end
  return nil
end

function onInit()
  state.set("gender", "male")
  state.set("weight", "70")
  state.set("height", "175")
  state.set("age", "26")
  state.set("activityIndex", "2")
  state.set("goal", "maintain")
  state.set("dietStyle", "balanced")
  state.set("resTargetCal", "")
  state.set("resEnergyDetail", "")
  state.set("resProtein", "")
  state.set("resCarbs", "")
  state.set("resFat", "")
  state.set("resWater", "")
  state.set("copyText", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  calculate()
  return nil
end
