local CACHE_PREFIX = "weather_cache_v1_"
local CACHE_TTL = 3600 -- 1 小时 (秒)

local CITIES = {
  { name = "北京", lat = "39.9042", lon = "116.4074" },
  { name = "上海", lat = "31.2304", lon = "121.4737" },
  { name = "广州", lat = "23.1291", lon = "113.2644" },
  { name = "深圳", lat = "22.5431", lon = "114.0579" },
  { name = "成都", lat = "30.5728", lon = "104.0668" },
  { name = "杭州", lat = "30.2741", lon = "120.1551" },
  { name = "东京", lat = "35.6762", lon = "139.6503" },
  { name = "纽约", lat = "40.7128", lon = "-74.0060" }
}

local WEATHER_CODES = {
  [0] = "晴朗 (Clear sky)",
  [1] = "主要晴朗 (Mainly clear)",
  [2] = "部分多云 (Partly cloudy)",
  [3] = "阴天 (Overcast)",
  [45] = "大雾 (Fog)",
  [48] = "冻雾 (Depositing rime fog)",
  [51] = "轻微毛毛雨 (Light drizzle)",
  [53] = "中度毛毛雨 (Moderate drizzle)",
  [55] = "稠密毛毛雨 (Dense drizzle)",
  [61] = "小雨 (Slight rain)",
  [63] = "中雨 (Moderate rain)",
  [65] = "大雨 (Heavy rain)",
  [71] = "小雪 (Slight snow)",
  [73] = "中雪 (Moderate snow)",
  [75] = "暴雪 (Heavy snow)",
  [80] = "小阵雨 (Rain showers)",
  [81] = "中度阵雨 (Moderate showers)",
  [82] = "强暴雨 (Violent showers)",
  [95] = "雷阵雨 (Thunderstorm)"
}

local cityIndex = 1
local lastQueriedUrl = ""

local function get_weather_desc(code)
  return WEATHER_CODES[code] or "天气状况良好 (" .. tostring(code) .. ")"
end

local function get_wind_direction_desc(deg)
  if deg == nil then
    return "未知"
  end
  local dirs = { "北风", "东北风", "东风", "东南风", "南风", "西南风", "西风", "西北风" }
  local idx = math.floor(((deg + 22.5) % 360) / 45) + 1
  return dirs[idx] or "北风"
end

local function build_api_url(lat, lon)
  return "https://api.open-meteo.com/v1/forecast?latitude=" .. lat .. "&longitude=" .. lon .. "&current_weather=true"
end

local function update_weather_display(cityName, cw, isCached)
  local tempStr = tostring(cw.temperature or 0) .. " °C"
  local code = cw.weathercode or 0
  local weatherDesc = get_weather_desc(code)
  local windSpeed = tostring(cw.windspeed or 0) .. " km/h"
  local windDir = get_wind_direction_desc(cw.winddirection) .. " (" .. tostring(cw.winddirection or 0) .. "°)"
  local timeStr = cw.time or "近期"

  local cacheNotice = "实时联网获取"
  if isCached then
    cacheNotice = "使用本地缓存数据 (< 1小时)"
  end

  state.set("cityName", cityName)
  state.set("tempStr", tempStr)
  state.set("weatherDesc", weatherDesc)
  state.set("windInfo", "风速: " .. windSpeed .. " | 风向: " .. windDir)
  state.set("updateTime", "观测时间: " .. timeStr .. " (" .. cacheNotice .. ")")
  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function _parse_weather_json(body)
  local ok, data = pcall(json.decode, body or "")
  if not ok or type(data) ~= "table" then
    return nil, "气象数据格式异常"
  end
  local cw = data.current_weather
  if type(cw) ~= "table" then
    return nil, "未找到实时气象字段"
  end
  return cw, nil
end

function queryWeather()
  local lat = state.get("latitude") or ""
  local lon = state.get("longitude") or ""
  local cityName = state.get("cityName") or "当前坐标"

  if lat == "" or lon == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入有效的经纬度坐标")
    state.set("hasResult", false)
    return nil
  end

  local cacheKey = CACHE_PREFIX .. lat .. "_" .. lon
  storage.get(cacheKey, function(raw)
    local used = false
    if raw and raw ~= "" then
      local ok, cached = pcall(json.decode, raw)
      if ok and type(cached) == "table" and cached.cw ~= nil then
        local ts = tonumber(cached.ts) or 0
        if util.timestamp() - ts < CACHE_TTL then
          update_weather_display(cityName, cached.cw, true)
          used = true
        end
      end
    end

    if not used then
      local url = build_api_url(lat, lon)
      lastQueriedUrl = url
      state.set("updateTime", "正在请求气象卫星数据...")
      network.get(url)
    end
    return nil
  end)
  return nil
end

function cycleCity()
  cityIndex = cityIndex + 1
  if cityIndex > #CITIES then
    cityIndex = 1
  end
  local c = CITIES[cityIndex]
  state.set("cityName", c.name)
  state.set("latitude", c.lat)
  state.set("longitude", c.lon)
  queryWeather()
  return nil
end

function forceRefresh()
  local lat = state.get("latitude") or ""
  local lon = state.get("longitude") or ""
  if lat == "" or lon == "" then
    return nil
  end
  local url = build_api_url(lat, lon)
  lastQueriedUrl = url
  state.set("updateTime", "正在强制刷新气象数据...")
  network.get(url)
  return nil
end

function copyWeatherReport()
  local lines = {
    "【" .. (state.get("cityName") or "") .. " 实时天气】",
    "气温: " .. (state.get("tempStr") or ""),
    "天气: " .. (state.get("weatherDesc") or ""),
    (state.get("windInfo") or ""),
    (state.get("updateTime") or "")
  }
  local out = table.concat(lines, "\n")
  clipboard.set(out)
  dialog.toast("已复制天气报告")
  return nil
end

function onNetworkResponse(status, body)
  if status ~= 200 then
    state.set("hasError", true)
    state.set("errorMsg", "获取气象信息失败: HTTP " .. tostring(status))
    return nil
  end

  local cw, err = _parse_weather_json(body)
  if err ~= nil then
    state.set("hasError", true)
    state.set("errorMsg", err)
    return nil
  end

  local lat = state.get("latitude") or ""
  local lon = state.get("longitude") or ""
  local cityName = state.get("cityName") or "当前坐标"
  local cacheKey = CACHE_PREFIX .. lat .. "_" .. lon
  local ts = util.timestamp()

  storage.set(cacheKey, json.encode({ ts = ts, cw = cw }))
  update_weather_display(cityName, cw, false)
  dialog.toast("已获取最新气象数据")
  return nil
end

function onNetworkError(msg)
  state.set("hasError", true)
  state.set("errorMsg", "网络连接异常: " .. (msg or "请检查网络连接"))
  return nil
end

function onInit()
  local defaultCity = CITIES[1]
  cityIndex = 1
  state.set("cityName", defaultCity.name)
  state.set("latitude", defaultCity.lat)
  state.set("longitude", defaultCity.lon)
  state.set("tempStr", "-- °C")
  state.set("weatherDesc", "等待加载天气...")
  state.set("windInfo", "")
  state.set("updateTime", "未加载")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  queryWeather()
  return nil
end
