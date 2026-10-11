-- 汽车油耗与充电成本追踪器

local currentEnergyType = "gas" -- "gas" or "ev"
local memoryRecords = {}

local function querySummary()
    if db ~= nil and db.query ~= nil then
        pcall(function()
            db.query("SELECT * FROM fuel_records ORDER BY id DESC", function(res)
                if res ~= nil and res.rows ~= nil then
                    memoryRecords = res.rows
                end
            end)
        end)
    end

    local totalDist = 0.0
    local totalVol = 0.0
    local totalCost = 0.0
    local count = #memoryRecords

    local i = 1
    while i <= count do
        local r = memoryRecords[i]
        local d = tonumber(r.distance) or 0.0
        local v = tonumber(r.volume) or 0.0
        local c = tonumber(r.cost) or 0.0
        totalDist = totalDist + d
        totalVol = totalVol + v
        totalCost = totalCost + c
        i = i + 1
    end

    if totalDist <= 0 then
        totalDist = 520.0
        totalVol = 38.5
        totalCost = 308.0
        count = 1
    end

    local avgPer100 = (totalVol / totalDist) * 100.0
    local costKm = totalCost / totalDist

    local unitStr = (currentEnergyType == "gas") and "L/100km" or "kWh/100km"
    state.set("avgPer100Display", string.format("%.2f %s", avgPer100, unitStr))
    state.set("costPerKmDisplay", string.format("每公里成本: ¥ %.3f 元", costKm))
    state.set("totalsDisplay", string.format("累计记录 %d 次 | 行驶 %.1f km | 补能 %.1f | 支出 ¥ %.1f",
        count, totalDist, totalVol, totalCost))
    return nil
end

function onInit()
    currentEnergyType = "gas"
    state.set("inputDistance", "520.0")
    state.set("inputVolume", "38.5")
    state.set("inputPrice", "8.00")
    state.set("inputTripDist", "300")
    state.set("tripEstimate", "预估行程费用计算")
    state.set("energyTypeDesc", "当前模式：燃油车 (汽油升数)")

    if db ~= nil and db.execute ~= nil then
        pcall(function()
            db.execute("CREATE TABLE IF NOT EXISTS fuel_records (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, distance REAL, volume REAL, price REAL, cost REAL, date TEXT)")
        end)
    end

    querySummary()
    return nil
end

function setEnergyType(kind)
    if kind == "ev" then
        currentEnergyType = "ev"
        state.set("energyTypeDesc", "当前模式：纯电动车 (度数 kWh)")
        state.set("inputPrice", "1.20")
    else
        currentEnergyType = "gas"
        state.set("energyTypeDesc", "当前模式：燃油车 (汽油升数)")
        state.set("inputPrice", "8.00")
    end
    querySummary()
    dialog.toast("已切换能耗类型: " .. state.get("energyTypeDesc"))
    return nil
end

local function getTodayDateStr()
    local ts = util.timestamp()
    local days = math.floor(ts / 86400) + 719468
    local era = math.floor(days / 146097)
    local doe = days - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local mp = math.floor((5 * doy + 2) / 153)
    local d = doy - math.floor((153 * mp + 2) / 5) + 1
    local m = mp + (mp < 10 and 3 or -9)
    if m <= 2 then y = y + 1 end
    return string.format("%04d-%02d-%02d", y, m, d)
end

function addRecord()
    local dist = tonumber(state.get("inputDistance") or "500") or 500
    local vol = tonumber(state.get("inputVolume") or "35") or 35
    local price = tonumber(state.get("inputPrice") or "8.0") or 8.0
    local cost = vol * price
    local dateStr = getTodayDateStr()

    local rec = {
        id = #memoryRecords + 1,
        type = currentEnergyType,
        distance = dist,
        volume = vol,
        price = price,
        cost = cost,
        date = dateStr
    }
    table.insert(memoryRecords, 1, rec)

    if db ~= nil and db.execute ~= nil then
        pcall(function()
            local sql = string.format("INSERT INTO fuel_records (type, distance, volume, price, cost, date) VALUES ('%s', %.2f, %.2f, %.2f, %.2f, '%s')",
                currentEnergyType, dist, vol, price, cost, dateStr)
            db.execute(sql)
        end)
    end

    querySummary()
    dialog.toast(string.format("已新增补能记录：行驶 %.1f km, 支出 ¥ %.2f", dist, cost))
    return nil
end

function calcTrip()
    local km = tonumber(state.get("inputTripDist") or "300") or 300
    local avgText = state.get("avgPer100Display") or "7.40"
    local spacePos = string.find(avgText, " ", 1, true)
    local avgNum = 7.4
    if spacePos then
        avgNum = tonumber(string.sub(avgText, 1, spacePos - 1)) or 7.4
    end
    local price = tonumber(state.get("inputPrice") or "8.0") or 8.0

    local neededVol = (km / 100.0) * avgNum
    local estCost = neededVol * price
    state.set("tripEstimate", string.format("行程 %d km 预估需 %.1f %s，预估花费 ¥ %.2f 元",
        km, neededVol, currentEnergyType == "gas" and "升" or "度", estCost))
    dialog.toast("行程成本预估完成")
    return nil
end

function clearRecords()
    memoryRecords = {}
    if db ~= nil and db.execute ~= nil then
        pcall(function()
            db.execute("DELETE FROM fuel_records")
        end)
    end
    querySummary()
    dialog.toast("本地 SQLite 能耗记录已清空")
    return nil
end

function copySummary()
    local text = string.format("车辆能耗报告 (%s):\n百公里能耗: %s\n%s\n%s\n%s",
        state.get("energyTypeDesc") or "",
        state.get("avgPer100Display") or "",
        state.get("costPerKmDisplay") or "",
        state.get("totalsDisplay") or "",
        state.get("tripEstimate") or "")
    if clipboard ~= nil then
        pcall(function()
            clipboard.set(text)
        end)
    end
    dialog.toast("能耗统计已复制")
    return nil
end
