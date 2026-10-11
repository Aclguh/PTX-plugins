-- GPS 卫星罗盘与多坐标系转换

local PI = 3.1415926535897932384626
local A = 6378245.0
local EE = 0.00669342162296594323
local X_PI = 3.1415926535897932384626 * 3000.0 / 180.0

local function outOfChina(lat, lng)
    if lng < 72.004 then return true end
    if lng > 137.8347 then return true end
    if lat < 0.8293 then return true end
    if lat > 55.8271 then return true end
    return false
end

local function transformLat(x, y)
    local ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(math.abs(x))
    ret = ret + (20.0 * math.sin(6.0 * x * PI) + 20.0 * math.sin(2.0 * x * PI)) * 2.0 / 3.0
    ret = ret + (20.0 * math.sin(y * PI) + 40.0 * math.sin(y / 3.0 * PI)) * 2.0 / 3.0
    ret = ret + (160.0 * math.sin(y / 12.0 * PI) + 320 * math.sin(y * PI / 30.0)) * 2.0 / 3.0
    return ret
end

local function transformLng(x, y)
    local ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * math.sqrt(math.abs(x))
    ret = ret + (20.0 * math.sin(6.0 * x * PI) + 20.0 * math.sin(2.0 * x * PI)) * 2.0 / 3.0
    ret = ret + (20.0 * math.sin(x * PI) + 40.0 * math.sin(x / 3.0 * PI)) * 2.0 / 3.0
    ret = ret + (150.0 * math.sin(x / 12.0 * PI) + 300.0 * math.sin(x / 30.0 * PI)) * 2.0 / 3.0
    return ret
end

local function wgs84ToGcj02(lat, lng)
    if outOfChina(lat, lng) then
        return lat, lng
    end
    local dlat = transformLat(lng - 105.0, lat - 35.0)
    local dlng = transformLng(lng - 105.0, lat - 35.0)
    local radlat = lat / 180.0 * PI
    local magic = math.sin(radlat)
    magic = 1.0 - EE * magic * magic
    local sqrtmagic = math.sqrt(magic)
    dlat = (dlat * 180.0) / ((A * (1.0 - EE)) / (magic * sqrtmagic) * PI)
    dlng = (dlng * 180.0) / (A / sqrtmagic * math.cos(radlat) * PI)
    return lat + dlat, lng + dlng
end

local function myAtan2(y, x)
    if x > 0 then
        return math.atan(y / x)
    else
        if x < 0 then
            if y >= 0 then
                return math.atan(y / x) + PI
            else
                return math.atan(y / x) - PI
            end
        else
            if y > 0 then
                return PI / 2.0
            else
                if y < 0 then
                    return -PI / 2.0
                else
                    return 0.0
                end
            end
        end
    end
end

local function gcj02ToBd09(lat, lng)
    local z = math.sqrt(lng * lng + lat * lat) + 0.00002 * math.sin(lat * X_PI)
    local theta = myAtan2(lat, lng) + 0.000003 * math.cos(lng * X_PI)
    local bd_lng = z * math.cos(theta) + 0.0065
    local bd_lat = z * math.sin(theta) + 0.006
    return bd_lat, bd_lng
end

local function haversineDistKm(lat1, lon1, lat2, lon2)
    local dlat = (lat2 - lat1) * PI / 180.0
    local dlon = (lon2 - lon1) * PI / 180.0
    local rlat1 = lat1 * PI / 180.0
    local rlat2 = lat2 * PI / 180.0
    local a = math.sin(dlat / 2.0) * math.sin(dlat / 2.0) +
              math.cos(rlat1) * math.cos(rlat2) * math.sin(dlon / 2.0) * math.sin(dlon / 2.0)
    local c = 2.0 * myAtan2(math.sqrt(a), math.sqrt(1.0 - a))
    return 6371.0 * c
end

local currentLat = 39.9042
local currentLng = 116.4074

local function updateCoords(lat, lng)
    currentLat = lat
    currentLng = lng

    local gcjLat, gcjLng = wgs84ToGcj02(lat, lng)
    local bdLat, bdLng = gcj02ToBd09(gcjLat, gcjLng)

    state.set("inputLat", string.format("%.6f", lat))
    state.set("inputLng", string.format("%.6f", lng))

    state.set("wgsDisplay", string.format("WGS-84 (GPS标准): %.6f, %.6f", lat, lng))
    state.set("gcjDisplay", string.format("GCJ-02 (火星坐标): %.6f, %.6f", gcjLat, gcjLng))
    state.set("bdDisplay", string.format("BD-09 (百度地图): %.6f, %.6f", bdLat, bdLng))
    state.set("coordSummary", string.format("%.6f, %.6f", lat, lng))
    return nil
end

function onInit()
    currentLat = 39.9042
    currentLng = 116.4074

    state.set("inputLat", "39.904200")
    state.set("inputLng", "116.407400")
    state.set("targetLat", "31.230400")
    state.set("targetLng", "121.473700")
    state.set("distResult", "点击测距计算两地大圆距离")
    state.set("sensorInfo", "定位状态：待刷新")

    refreshLocation()
    return nil
end

function refreshLocation()
    if location ~= nil and location.getCurrentPosition ~= nil then
        pcall(function()
            location.getCurrentPosition(function(res)
                if res ~= nil and res.ok then
                    local lat = res.latitude or 39.9042
                    local lng = res.longitude or 116.4074
                    local alt = res.altitude or 0.0
                    local speed = (res.speed or 0.0) * 3.6
                    local acc = res.accuracy or 0.0
                    updateCoords(lat, lng)
                    state.set("sensorInfo", string.format("海拔: %.1fm | 速度: %.1f km/h | 精度: ±%.1fm", alt, speed, acc))
                    dialog.toast("GPS 卫星读数刷新成功")
                else
                    updateCoords(39.9042, 116.4074)
                    state.set("sensorInfo", "基准坐标 (北京天安门) 模拟值")
                end
            end)
        end)
    else
        updateCoords(39.9042, 116.4074)
        state.set("sensorInfo", "定位模块未连接，展示基准示例")
    end
    return nil
end

function convertManual()
    local lat = tonumber(state.get("inputLat") or "") or 39.9042
    local lng = tonumber(state.get("inputLng") or "") or 116.4074
    updateCoords(lat, lng)
    dialog.toast("坐标系换算完成")
    return nil
end

function calcDistance()
    local lat1 = tonumber(state.get("inputLat") or "") or currentLat
    local lng1 = tonumber(state.get("inputLng") or "") or currentLng
    local lat2 = tonumber(state.get("targetLat") or "") or 31.2304
    local lng2 = tonumber(state.get("targetLng") or "") or 121.4737

    local distKm = haversineDistKm(lat1, lng1, lat2, lng2)
    local distM = distKm * 1000.0

    state.set("distResult", string.format("大圆距离: %.2f km (约 %.0f 米)", distKm, distM))
    dialog.toast(string.format("两点相距 %.1f km", distKm))
    return nil
end

function copyCoords(kind)
    local text = ""
    if kind == "wgs" then
        text = state.get("wgsDisplay") or ""
    else
        if kind == "gcj" then
            text = state.get("gcjDisplay") or ""
        else
            if kind == "bd" then
                text = state.get("bdDisplay") or ""
            else
                text = string.format("%s\n%s\n%s\n%s",
                    state.get("wgsDisplay") or "",
                    state.get("gcjDisplay") or "",
                    state.get("bdDisplay") or "",
                    state.get("sensorInfo") or "")
            end
        end
    end
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("坐标已复制到剪贴板")
    return nil
end

function onDispose()
    return nil
end
