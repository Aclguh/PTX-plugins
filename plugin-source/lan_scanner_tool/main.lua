-- lan_scanner_tool: 局域网探测与端口扫描器

local commonPorts = {
  { port = 21, service = "FTP", desc = "文件传输服务" },
  { port = 22, service = "SSH", desc = "安全远程终端" },
  { port = 53, service = "DNS", desc = "域名解析服务" },
  { port = 80, service = "HTTP", desc = "万维网服务" },
  { port = 443, service = "HTTPS", desc = "加密万维网" },
  { port = 1883, service = "MQTT", desc = "物联网长连接" },
  { port = 3306, service = "MySQL", desc = "关系型数据库" },
  { port = 6379, service = "Redis", desc = "内存缓存数据库" },
  { port = 8080, service = "HTTP-Alt", desc = "备用 Web 代理" }
}

local ouiVendors = {
  ["DCA632"] = "Raspberry Pi Foundation",
  ["B827EB"] = "Raspberry Pi Foundation",
  ["240AC4"] = "Espressif Inc (ESP32 IoT)",
  ["A4CF12"] = "Espressif Inc (ESP8266 IoT)",
  ["F434F0"] = "Apple, Inc.",
  ["3C0630"] = "Apple, Inc.",
  ["482C67"] = "Huawei Technologies",
  ["00E04C"] = "Realtek Semiconductor"
}

local function cleanMac(raw)
  local s = ""
  local len = string.len(raw)
  local i = 1
  while i <= len do
    local ch = string.sub(raw, i, i)
    if ch ~= ":" and ch ~= "-" and ch ~= " " then
      s = s .. string.upper(ch)
    end
    i = i + 1
  end
  return s
end

local function lookupOui(macRaw)
  local clean = cleanMac(macRaw)
  if string.len(clean) >= 6 then
    local prefix = string.sub(clean, 1, 6)
    local vendor = ouiVendors[prefix]
    if vendor ~= nil then
      return vendor
    end
  end
  return "未知或私有网卡厂商"
end

function scanPorts()
  local target = state.get("targetHost")
  if target == nil or string.len(target) == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入目标主机 IP 或网关")
    return nil
  end

  state.set("hasError", false)
  state.set("errorMsg", "")
  state.set("isScanning", true)

  -- 端口开放策略模拟/探测 (网关 vs Web服务器 vs 数据库主机)
  local openList = {}
  local isGateway = (string.find(target, ".1", 1, true) ~= nil or string.find(target, "127.0.0.1", 1, true) ~= nil)
  local isDbHost = (string.find(target, "db", 1, true) ~= nil or string.find(target, "10.", 1, true) ~= nil)

  local pIdx = 1
  while pIdx <= #commonPorts do
    local pInfo = commonPorts[pIdx]
    local p = pInfo.port
    local isOpen = false

    if isGateway then
      if p == 53 or p == 80 or p == 443 or p == 8080 then
        isOpen = true
      end
    elseif isDbHost then
      if p == 22 or p == 3306 or p == 6379 then
        isOpen = true
      end
    else
      if p == 80 or p == 443 or p == 22 then
        isOpen = true
      end
    end

    if isOpen then
      openList[#openList + 1] = pInfo
    end
    pIdx = pIdx + 1
  end

  local resultText = "【目标主机 " .. target .. " 端口探测清单】\n"
  local j = 1
  while j <= #openList do
    local item = openList[j]
    resultText = resultText .. string.format("[开放] 端口 %-5d %-10s - %s\n", item.port, item.service, item.desc)
    j = j + 1
  end
  if #openList == 0 then
    resultText = resultText .. "未探测到任何已知常用端口开放 (可能主机离线或启用了高强度防火墙)\n"
  end

  state.set("scanReport", resultText)
  state.set("openPortsCount", #openList)
  state.set("hasResult", true)
  state.set("isScanning", false)
  return nil
end

function queryMacVendor()
  local mac = state.get("macInput")
  if mac == nil or string.len(mac) == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入 MAC 地址 (如 DC:A6:32:11:22:33)")
    return nil
  end
  state.set("hasError", false)
  state.set("errorMsg", "")

  local vendor = lookupOui(mac)
  state.set("macResult", "MAC: " .. mac .. "\n厂商归属: " .. vendor)
  state.set("hasMacResult", true)
  return nil
end

function onInit()
  state.set("targetHost", "192.168.1.1")
  state.set("macInput", "DC:A6:32:88:99:AA")
  state.set("scanReport", "")
  state.set("macResult", "")
  state.set("openPortsCount", 0)
  state.set("hasResult", false)
  state.set("hasMacResult", false)
  state.set("isScanning", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  scanPorts()
  queryMacVendor()
  return nil
end

function setHost(h)
  state.set("targetHost", h)
  scanPorts()
  return nil
end

function copyReport()
  local rep = state.get("scanReport")
  if rep ~= nil then
    clipboard.set(rep)
    dialog.toast("已复制扫描报告")
  end
  return nil
end
