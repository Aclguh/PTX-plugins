local ACTIVITY_FACTORS = { 1.2, 1.375, 1.55, 1.725 }
local ACTIVITY_NAMES = {
  "久坐少动 (工作久坐、无规律运动)",
  "轻度活动 (每周运动 1-3 次)",
  "中度活动 (每周运动 3-5 次)",
  "高度活动 (每周大运动量 6-7 次)"
}

local function round1(num)
  return math.floor(num * 10 + 0.5) / 10
end

local function round2(num)
  return math.floor(num * 100 + 0.5) / 100
end

function _compute_bmi(heightCm, weightKg)
  local hm = heightCm / 100
  if hm <= 0 then return 0 end
  local bmi = weightKg / (hm * hm)
  return round2(bmi)
end

function _get_bmi_category(bmi)
  if bmi < 18.5 then
    return "偏瘦 (体重过轻)"
  elseif bmi < 24.0 then
    return "正常健康 (标准体型)"
  elseif bmi < 28.0 then
    return "超重 (偏重)"
  else
    return "肥胖 (注意代谢健康)"
  end
end

function _compute_bmr(gender, heightCm, weightKg, age)
  -- Mifflin-St Jeor 基础代谢公式
  local bmr = 10 * weightKg + 6.25 * heightCm - 5 * age
  if gender == "male" then
    bmr = bmr + 5
  else
    bmr = bmr - 161
  end
  return math.floor(bmr + 0.5)
end

function _compute_body_fat(bmi, age, gender)
  -- 成人常用体脂率评估公式
  local gFactor = 1
  if gender == "female" then
    gFactor = 0
  end
  local bfp = 1.2 * bmi + 0.23 * age - 5.4 - (10.8 * gFactor)
  if bfp < 3 then bfp = 3 end
  if bfp > 65 then bfp = 65 end
  return round1(bfp)
end

function calculate()
  local heightStr = state.get("height") or "175"
  local weightStr = state.get("weight") or "70"
  local ageStr = state.get("age") or "25"
  local gender = state.get("gender") or "male"
  local actIdx = tonumber(state.get("activityIndex") or "1") or 1

  local height = tonumber(heightStr)
  local weight = tonumber(weightStr)
  local age = tonumber(ageStr)

  if height == nil or height < 50 or height > 260 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入有效的身高 (50 - 260 cm)")
    state.set("hasResult", false)
    return nil
  end

  if weight == nil or weight < 20 or weight > 350 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入有效的体重 (20 - 350 kg)")
    state.set("hasResult", false)
    return nil
  end

  if age == nil or age < 5 or age > 120 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入有效的年龄 (5 - 120 岁)")
    state.set("hasResult", false)
    return nil
  end

  local bmi = _compute_bmi(height, weight)
  local bmiCategory = _get_bmi_category(bmi)

  local hm = height / 100
  local minIdeal = round1(18.5 * hm * hm)
  local maxIdeal = round1(23.9 * hm * hm)
  local idealWeightStr = tostring(minIdeal) .. " kg ~ " .. tostring(maxIdeal) .. " kg"

  local bodyFat = _compute_body_fat(bmi, age, gender)
  local bmr = _compute_bmr(gender, height, weight, age)
  local factor = ACTIVITY_FACTORS[actIdx] or 1.2
  local tdee = math.floor(bmr * factor + 0.5)

  local fatLossCal = tdee - 400
  if fatLossCal < bmr then
    fatLossCal = bmr
  end
  local muscleGainCal = tdee + 300

  state.set("bmiVal", tostring(bmi))
  state.set("bmiLevel", "BMI: " .. tostring(bmi) .. " (" .. bmiCategory .. ")")
  state.set("idealWeight", "标准健康体重范围: " .. idealWeightStr)
  state.set("bodyFatVal", "预估体脂率 (BFP): " .. tostring(bodyFat) .. "%")
  state.set("bmrVal", "基础代谢 (BMR): " .. tostring(bmr) .. " kcal / 天")
  state.set("tdeeVal", "每日总消耗 (TDEE): " .. tostring(tdee) .. " kcal / 天")
  state.set("dietPlan", "减脂目标摄入: " .. tostring(fatLossCal) .. " kcal | 增肌目标摄入: " .. tostring(muscleGainCal) .. " kcal")

  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function toggleGender()
  local g = state.get("gender") or "male"
  if g == "male" then
    state.set("gender", "female")
    state.set("genderDesc", "性别: 女性")
  else
    state.set("gender", "male")
    state.set("genderDesc", "性别: 男性")
  end
  calculate()
  return nil
end

function cycleActivity()
  local actIdx = tonumber(state.get("activityIndex") or "1") or 1
  actIdx = actIdx + 1
  if actIdx > 4 then
    actIdx = 1
  end
  state.set("activityIndex", actIdx)
  state.set("activityDesc", "活动量: " .. ACTIVITY_NAMES[actIdx])
  calculate()
  return nil
end

function copyReport()
  local report = {
    "【健康与热量代谢测算报告】",
    state.get("bmiLevel") or "",
    state.get("idealWeight") or "",
    state.get("bodyFatVal") or "",
    state.get("bmrVal") or "",
    state.get("tdeeVal") or "",
    state.get("dietPlan") or ""
  }
  local out = table.concat(report, "\n")
  clipboard.set(out)
  dialog.toast("已复制健康测算报告")
  return nil
end

function resetDefault()
  state.set("height", "175")
  state.set("weight", "70")
  state.set("age", "25")
  state.set("gender", "male")
  state.set("genderDesc", "性别: 男性")
  state.set("activityIndex", 1)
  state.set("activityDesc", "活动量: " .. ACTIVITY_NAMES[1])
  calculate()
  return nil
end

function onInit()
  resetDefault()
  return nil
end
