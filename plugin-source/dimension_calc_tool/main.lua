-- dimension_calc_tool: 量纲分析与单位计算器

local unitFactors = {
  -- 速度基准: m/s
  velocity = {
    ["m/s"] = 1.0,
    ["km/h"] = 0.27777777777778,
    ["mph"] = 0.44704,
    ["knot"] = 0.51444444444444,
    ["ft/s"] = 0.3048
  },
  -- 压强基准: Pa
  pressure = {
    ["Pa"] = 1.0,
    ["kPa"] = 1000.0,
    ["MPa"] = 1000000.0,
    ["bar"] = 100000.0,
    ["psi"] = 6894.757293168,
    ["atm"] = 101325.0,
    ["mmHg"] = 133.322387415
  },
  -- 能量基准: J
  energy = {
    ["J"] = 1.0,
    ["kJ"] = 1000.0,
    ["MJ"] = 1000000.0,
    ["cal"] = 4.184,
    ["kcal"] = 4184.0,
    ["kWh"] = 3600000.0,
    ["eV"] = 0.0000000000000000001602176634
  },
  -- 功率基准: W
  power = {
    ["W"] = 1.0,
    ["kW"] = 1000.0,
    ["MW"] = 1000000.0,
    ["hp"] = 745.69987158227022, -- 英制马力
    ["ps"] = 735.49875 -- 米制马力
  },
  -- 质量基准: kg
  mass = {
    ["kg"] = 1.0,
    ["g"] = 0.001,
    ["mg"] = 0.000001,
    ["t"] = 1000.0,
    ["lb"] = 0.45359237,
    ["oz"] = 0.028349523125
  },
  -- 长度基准: m
  length = {
    ["m"] = 1.0,
    ["km"] = 1000.0,
    ["cm"] = 0.01,
    ["mm"] = 0.001,
    ["in"] = 0.0254,
    ["ft"] = 0.3048,
    ["yd"] = 0.9144,
    ["mi"] = 1609.344,
    ["nmi"] = 1852.0
  }
}

function onInit()
  state.set("category", "velocity")
  state.set("inputValue", "120")
  state.set("sourceUnit", "km/h")
  state.set("targetUnit", "m/s")
  state.set("resultDisplay", "33.333333 m/s")
  state.set("formulaDetail", "120 km/h = 33.333333 m/s (系数: 0.277778)")
  state.set("kineticMass", "1500") -- 1500 kg
  state.set("kineticSpeed", "100") -- 100 km/h
  state.set("kineticEnergyResult", "578.7 kJ (0.1608 kWh)")
  state.set("hasError", false)
  state.set("errorMsg", "")
  calculate()
  calcKinetic()
  return nil
end

function calculate()
  local cat = state.get("category")
  if cat == nil then cat = "velocity" end
  local valStr = state.get("inputValue")
  local src = state.get("sourceUnit")
  local tgt = state.get("targetUnit")

  local val = tonumber(valStr)
  if val == nil then
    state.set("hasError", true)
    state.set("errorMsg", "请输入合法的数值")
    return nil
  end

  local catTable = unitFactors[cat]
  if catTable == nil then
    state.set("hasError", true)
    state.set("errorMsg", "未知量纲分类: " .. tostring(cat))
    return nil
  end

  local srcFactor = catTable[src]
  local tgtFactor = catTable[tgt]
  if srcFactor == nil or tgtFactor == nil then
    state.set("hasError", true)
    state.set("errorMsg", "无效的单位: " .. tostring(src) .. " -> " .. tostring(tgt))
    return nil
  end

  state.set("hasError", false)
  state.set("errorMsg", "")

  -- 换算到基准，再除以目标单位系数
  local baseVal = val * srcFactor
  local finalVal = baseVal / tgtFactor

  local resStr = string.format("%.6f %s", finalVal, tgt)
  local detail = string.format("%s %s = %.6f %s (基准量: %.4f)", tostring(val), src, finalVal, tgt, baseVal)

  state.set("resultDisplay", resStr)
  state.set("formulaDetail", detail)
  return nil
end

function calcKinetic()
  local mStr = state.get("kineticMass")
  local vStr = state.get("kineticSpeed")
  local m = tonumber(mStr)
  local v = tonumber(vStr)

  if m == nil or v == nil or m < 0 or v < 0 then
    state.set("kineticEnergyResult", "输入数据无效")
    return nil
  end

  -- 速度由 km/h 转 m/s: v * 1000 / 3600
  local vMs = v * (1000.0 / 3600.0)
  -- 动能 Ek = 0.5 * m * v^2 (单位: 焦耳 J)
  local ekJoules = 0.5 * m * vMs * vMs
  local ekKj = ekJoules / 1000.0
  local ekKwh = ekJoules / 3600000.0

  local res = string.format("%.2f kJ (%.4f kWh)", ekKj, ekKwh)
  state.set("kineticEnergyResult", res)
  return nil
end

function setCategory(cat)
  state.set("category", cat)
  if cat == "velocity" then
    state.set("inputValue", "120")
    state.set("sourceUnit", "km/h")
    state.set("targetUnit", "m/s")
  elseif cat == "pressure" then
    state.set("inputValue", "1")
    state.set("sourceUnit", "atm")
    state.set("targetUnit", "psi")
  elseif cat == "energy" then
    state.set("inputValue", "1")
    state.set("sourceUnit", "kWh")
    state.set("targetUnit", "kJ")
  elseif cat == "power" then
    state.set("inputValue", "150")
    state.set("sourceUnit", "kW")
    state.set("targetUnit", "hp")
  elseif cat == "mass" then
    state.set("inputValue", "50")
    state.set("sourceUnit", "kg")
    state.set("targetUnit", "lb")
  elseif cat == "length" then
    state.set("inputValue", "10")
    state.set("sourceUnit", "km")
    state.set("targetUnit", "mi")
  end
  calculate()
  return nil
end

function copyResult()
  local res = state.get("resultDisplay")
  if res ~= nil then
    clipboard.set(res)
    dialog.toast("已复制计算结果")
  end
  return nil
end
