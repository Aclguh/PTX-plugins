-- unit_tool — 单位换算
-- 长度/重量/温度/面积/体积/速度/数据/时间 八类, 系数换算 + 温度偏移特判

local MAX_SLOTS = 8

local UNITS = {
  length = { label = "长度", items = {
    { name = "毫米 mm", factor = 0.001 },
    { name = "厘米 cm", factor = 0.01 },
    { name = "米 m", factor = 1 },
    { name = "千米 km", factor = 1000 },
    { name = "英寸 in", factor = 0.0254 },
    { name = "英尺 ft", factor = 0.3048 },
    { name = "英里 mi", factor = 1609.344 },
    { name = "海里 nmi", factor = 1852 },
  }},
  weight = { label = "重量", items = {
    { name = "毫克 mg", factor = 0.000001 },
    { name = "克 g", factor = 0.001 },
    { name = "千克 kg", factor = 1 },
    { name = "吨 t", factor = 1000 },
    { name = "盎司 oz", factor = 0.028349523125 },
    { name = "磅 lb", factor = 0.45359237 },
    { name = "斤", factor = 0.5 },
  }},
  temp = { label = "温度", temp = true, items = {
    { name = "摄氏度 °C" },
    { name = "华氏度 °F" },
    { name = "开尔文 K" },
  }},
  area = { label = "面积", items = {
    { name = "平方厘米 cm²", factor = 0.0001 },
    { name = "平方米 m²", factor = 1 },
    { name = "公顷 ha", factor = 10000 },
    { name = "亩", factor = 6666.6667 },
    { name = "平方千米 km²", factor = 1000000 },
    { name = "平方英尺 ft²", factor = 0.09290304 },
    { name = "英亩 acre", factor = 4046.8564224 },
  }},
  volume = { label = "体积", items = {
    { name = "毫升 mL", factor = 0.001 },
    { name = "升 L", factor = 1 },
    { name = "立方米 m³", factor = 1000 },
    { name = "美制加仑 gal", factor = 3.785411784 },
    { name = "美制品脱 qt", factor = 0.946352946 },
    { name = "液盎司 fl oz", factor = 0.0295735295625 },
  }},
  speed = { label = "速度", items = {
    { name = "米/秒 m/s", factor = 1 },
    { name = "千米/时 km/h", factor = 0.277777777777778 },
    { name = "英里/时 mph", factor = 0.44704 },
    { name = "节 kn", factor = 0.514444444444444 },
    { name = "英尺/秒 ft/s", factor = 0.3048 },
  }},
  data = { label = "数据", items = {
    { name = "比特 bit", factor = 0.125 },
    { name = "字节 B", factor = 1 },
    { name = "KB", factor = 1024 },
    { name = "MB", factor = 1048576 },
    { name = "GB", factor = 1073741824 },
    { name = "TB", factor = 1099511627776 },
  }},
  time = { label = "时间", items = {
    { name = "毫秒 ms", factor = 0.001 },
    { name = "秒 s", factor = 1 },
    { name = "分钟 min", factor = 60 },
    { name = "小时 h", factor = 3600 },
    { name = "天 d", factor = 86400 },
    { name = "周 wk", factor = 604800 },
    { name = "年 (365天)", factor = 31536000 },
  }},
}

local CAT_KEYS = { "length", "weight", "temp", "area", "volume", "speed", "data", "time" }

-- 温度换算: 统一以摄氏度为基准
local function tempToBase(idx, v)
  if idx == 2 then return (v - 32) * 5 / 9 end   -- °F -> °C
  if idx == 3 then return v - 273.15 end          -- K -> °C
  return v
end

local function tempFromBase(idx, v)
  if idx == 2 then return v * 9 / 5 + 32 end      -- °C -> °F
  if idx == 3 then return v + 273.15 end          -- °C -> K
  return v
end

-- 数值格式化: 沙箱 string.format 无 %g/%e, 极端量级手写科学计数
local function fmtNum(x)
  if x == 0 then return "0" end
  local a = math.abs(x)
  if a >= 1e15 or a < 0.000001 then
    local d = math.floor(math.log(a) / 2.302585092994 + 0.000000000001)
    local m = x / (10 ^ d)
    return string.format("%.4f", m) .. "e" .. d
  end
  local s = string.format("%.6f", x)
  local dot = string.find(s, ".", 1, true)
  if dot then
    local endPos = string.len(s)
    while endPos > dot and string.sub(s, endPos, endPos) == "0" do
      endPos = endPos - 1
    end
    if string.sub(s, endPos, endPos) == "." then endPos = endPos - 1 end
    s = string.sub(s, 1, endPos)
  end
  return s
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _convert(catKey, fromIdx, toIdx, value)
  local cat = UNITS[catKey]
  if cat == nil then return nil, "未知分类" end
  if cat.items[fromIdx] == nil or cat.items[toIdx] == nil then return nil, "单位下标越界" end
  local result
  if cat.temp then
    result = tempFromBase(toIdx, tempToBase(fromIdx, value))
  else
    result = value * cat.items[fromIdx].factor / cat.items[toIdx].factor
  end
  return { v = result, text = fmtNum(result) }
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("inputValue", "1")
  selectCategory("length")
end

local function unitName(cat, idx)
  local item = cat.items[idx]
  if item then return item.name end
  return ""
end

local function refreshSlots(catKey, fromIdx, toIdx)
  local cat = UNITS[catKey]
  for i = 1, MAX_SLOTS do
    local has = cat.items[i] ~= nil
    state.set("f" .. i .. "on", has)
    state.set("t" .. i .. "on", has)
    if has then
      state.set("f" .. i, (i == fromIdx and "> " or "") .. cat.items[i].name)
      state.set("t" .. i, (i == toIdx and "> " or "") .. cat.items[i].name)
    else
      state.set("f" .. i, "")
      state.set("t" .. i, "")
    end
  end
end

function selectCategory(catKey)
  local cat = UNITS[catKey]
  if cat == nil then return nil end
  state.set("catKey", catKey)
  state.set("catLabel", cat.label .. " (基准: "
      .. (cat.temp and "摄氏度" or cat.items[1].name) .. ")")
  -- 宿主 VM 的取小函数行为等同于取大, 默认目标下标手写
  local defaultTo = 2
  if #cat.items < 2 then defaultTo = #cat.items end
  refreshSlots(catKey, 1, defaultTo)
  convert()
end

function tapFrom(idx)
  idx = math.floor(tonumber(idx) or 1)
  local cat = UNITS[state.get("catKey")]
  if cat and cat.items[idx] then
    state.set("fromIdx", idx)
    refreshSlots(state.get("catKey"), idx, tonumber(state.get("toIdx")) or 2)
    convert()
  end
end

function tapTo(idx)
  idx = math.floor(tonumber(idx) or 1)
  local cat = UNITS[state.get("catKey")]
  if cat and cat.items[idx] then
    state.set("toIdx", idx)
    refreshSlots(state.get("catKey"), tonumber(state.get("fromIdx")) or 1, idx)
    convert()
  end
end

function swapUnits()
  local fromIdx = tonumber(state.get("fromIdx")) or 1
  local toIdx = tonumber(state.get("toIdx")) or 2
  state.set("fromIdx", toIdx)
  state.set("toIdx", fromIdx)
  refreshSlots(state.get("catKey"), toIdx, fromIdx)
  convert()
end

function convert()
  local catKey = state.get("catKey")
  local cat = UNITS[catKey]
  if cat == nil then return nil end
  local fromIdx = tonumber(state.get("fromIdx")) or 1
  local toIdx = tonumber(state.get("toIdx")) or 2
  if cat.items[fromIdx] == nil or cat.items[toIdx] == nil then return nil end

  local v = tonumber(state.get("inputValue") or "")
  if v == nil then
    state.set("resultText", "请输入有效数字")
    return nil
  end

  local result
  if cat.temp then
    result = tempFromBase(toIdx, tempToBase(fromIdx, v))
  else
    result = v * cat.items[fromIdx].factor / cat.items[toIdx].factor
  end
  state.set("resultText", fmtNum(v) .. " " .. cat.items[fromIdx].name
      .. " = " .. fmtNum(result) .. " " .. cat.items[toIdx].name)
end
