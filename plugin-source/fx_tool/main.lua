-- fx_tool — 汇率换算
-- 数据源: https://open.er-api.com/v6/latest/USD (免费 HTTPS, 无需密钥);
-- 结果经 storage 缓存 12 小时, 避免每次进入页面都请求网络

local API = "https://open.er-api.com/v6/latest/USD"
local CACHE_KEY = "fx_cache_v1"
local CACHE_TTL = 43200 -- 12 小时 (秒)
local CURRENCIES = { "USD", "CNY", "EUR", "JPY", "GBP", "HKD", "KRW", "AUD" }

local rates = nil
local fromIdx = 1
local toIdx = 2

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

-- 数值 -> 货币展示串 (大额 2 位, 中额 4 位, 小额 6 位, 去尾零)
function _fmtAmount(v)
  local f = "%.2f"
  local abs = math.abs(v)
  if abs < 1000 then f = "%.4f" end
  if abs < 1 then f = "%.6f" end
  local s = string.format(f, v)
  while string.sub(s, string.len(s)) == "0" do
    s = string.sub(s, 1, string.len(s) - 1)
  end
  if string.sub(s, string.len(s)) == "." then
    s = string.sub(s, 1, string.len(s) - 1)
  end
  return s
end

-- 交叉汇率: amount / rates[from] * rates[to]
function _convertWith(r, amount, from, to)
  local rf = r[from]
  local rt = r[to]
  if rf == nil then return nil end
  if rt == nil then return nil end
  if rf == 0 then return nil end
  return amount / rf * rt
end

local function refreshLabels()
  state.set("fromLbl", "源货币: " .. CURRENCIES[fromIdx])
  state.set("toLbl", "目标货币: " .. CURRENCIES[toIdx])
end

local function refLines()
  if rates == nil then return "" end
  local from = CURRENCIES[fromIdx]
  local rf = rates[from]
  if rf == nil or rf == 0 then return "" end
  local shown = { "CNY", "EUR", "JPY", "HKD", "USD" }
  local out = {}
  for _, code in ipairs(shown) do
    if code ~= from and rates[code] ~= nil then
      out[#out + 1] = "1 " .. from .. " = " .. _fmtAmount(rates[code] / rf) .. " " .. code
    end
  end
  return table.concat(out, "\n")
end

local function applyRates()
  refreshLabels()
  state.set("refText", refLines())
end

-- ---------------- 测试钩子 (harness 专用) ----------------

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("amount", "1")
  state.set("fromLbl", "")
  state.set("toLbl", "")
  state.set("convTitle", "")
  state.set("convResult", "")
  state.set("refText", "")
  state.set("fxInfo", "汇率加载中...")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  refreshLabels()
  storage.get(CACHE_KEY, function(raw)
    -- 沙箱 VM 对回调内深嵌套块中的 return 存在静默穿透风险,
    -- 一律以无早退结构表达"命中缓存则不联网"
    local used = false
    if raw and raw ~= "" then
      local ok, c = pcall(json.decode, raw)
      if ok then
        if type(c) == "table" then
          if type(c.rates) == "table" then
            local ts = tonumber(c.ts) or 0
            if util.timestamp() - ts < CACHE_TTL then
              rates = c.rates
              applyRates()
              state.set("fxInfo", "使用本地缓存汇率 (写入于 Unix " .. ts .. ")")
              convert()
              used = true
            end
          end
        end
      end
    end
    if not used then
      fetchRates()
    end
  end)
end

function fetchRates()
  state.set("fxInfo", "汇率加载中...")
  network.get(API)
end

function cycleFrom()
  fromIdx = fromIdx % #CURRENCIES + 1
  applyRates()
  convert()
end

function cycleTo()
  toIdx = toIdx % #CURRENCIES + 1
  applyRates()
  convert()
end

function convert()
  if rates == nil then return nil end
  clearError()
  state.set("hasResult", false)
  local amount = tonumber(state.get("amount") or "")
  if amount == nil then return nil end
  local from = CURRENCIES[fromIdx]
  local to = CURRENCIES[toIdx]
  local res = _convertWith(rates, amount, from, to)
  if res == nil then return nil end
  state.set("convTitle", amount .. " " .. from .. " =")
  state.set("convResult", _fmtAmount(res) .. " " .. to)
  state.set("hasResult", true)
end

function onNetworkResponse(status, body)
  if status ~= 200 then
    state.set("fxInfo", "汇率加载失败: HTTP " .. status)
    return nil
  end
  local ok, data = pcall(json.decode, body or "")
  if not ok then
    state.set("fxInfo", "汇率数据解析失败")
    return nil
  end
  if type(data) ~= "table" then
    state.set("fxInfo", "汇率数据解析失败")
    return nil
  end
  if data.result ~= "success" then
    state.set("fxInfo", "汇率数据解析失败")
    return nil
  end
  if type(data.rates) ~= "table" then
    state.set("fxInfo", "汇率数据解析失败")
    return nil
  end
  rates = data.rates
  local ts = util.timestamp()
  storage.set(CACHE_KEY, json.encode({ ts = ts, rates = rates }))
  applyRates()
  state.set("fxInfo", "汇率已更新 (Unix " .. ts .. ")")
  convert()
end

function onNetworkError(msg)
  state.set("fxInfo", "汇率加载失败: " .. (msg or "未知错误"))
end
