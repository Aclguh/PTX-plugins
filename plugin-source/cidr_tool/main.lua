-- cidr_tool — IPv4 子网掩码与 CIDR 计算器

local function strLen(s)
  if s == nil then return 0 end
  return string.len(s)
end

local function trim(s)
  if s == nil then return "" end
  local len = strLen(s)
  local i = 1
  while i <= len do
    local c = string.sub(s, i, i)
    if c ~= " " and c ~= "\t" and c ~= "\r" and c ~= "\n" then
      break
    end
    i = i + 1
  end
  local j = len
  while j >= i do
    local c = string.sub(s, j, j)
    if c ~= " " and c ~= "\t" and c ~= "\r" and c ~= "\n" then
      break
    end
    j = j - 1
  end
  if i > j then return "" end
  return string.sub(s, i, j)
end

local function split(s, sep)
  local t = {}
  if s == nil or s == "" then return t end
  local start = 1
  local sepLen = strLen(sep)
  while true do
    local pos = string.find(s, sep, start, true)
    if not pos then
      t[#t + 1] = string.sub(s, start)
      break
    end
    t[#t + 1] = string.sub(s, start, pos - 1)
    start = pos + sepLen
  end
  return t
end

local function bitAnd8(a, b)
  local res = 0
  local p = 1
  local va = a
  local vb = b
  for _ = 0, 7 do
    local ra = va % 2
    local rb = vb % 2
    if ra == 1 and rb == 1 then
      res = res + p
    end
    va = math.floor(va / 2)
    vb = math.floor(vb / 2)
    p = p * 2
  end
  return res
end

local function prefixToMaskOctets(prefix)
  local octets = {0, 0, 0, 0}
  local rem = prefix
  for i = 1, 4 do
    if rem >= 8 then
      octets[i] = 255
      rem = rem - 8
    elseif rem > 0 then
      local val = 0
      local add = 128
      for _ = 1, rem do
        val = val + add
        add = math.floor(add / 2)
      end
      octets[i] = val
      rem = 0
    else
      octets[i] = 0
    end
  end
  return octets
end

local function maskOctetsToPrefix(m)
  local validMaskVals = {
    [0] = 0, [128] = 1, [192] = 2, [224] = 3,
    [240] = 4, [248] = 5, [252] = 6, [254] = 7, [255] = 8
  }
  local prefix = 0
  local mustBeZero = false
  for i = 1, 4 do
    local val = m[i]
    if validMaskVals[val] == nil then
      return nil
    end
    if mustBeZero then
      if val ~= 0 then return nil end
    else
      local bits = validMaskVals[val]
      prefix = prefix + bits
      if bits < 8 then
        mustBeZero = true
      end
    end
  end
  return prefix
end

local function parseIpv4(ipStr)
  local parts = split(trim(ipStr), ".")
  if #parts ~= 4 then
    return nil
  end
  local octets = {}
  for i = 1, 4 do
    local p = trim(parts[i])
    if strLen(p) == 0 then return nil end
    if strLen(p) > 1 and string.sub(p, 1, 1) == "0" then return nil end
    for ci = 1, strLen(p) do
      local c = string.sub(p, ci, ci)
      if c < "0" or c > "9" then return nil end
    end
    local num = tonumber(p)
    if num == nil or num < 0 or num > 255 then
      return nil
    end
    octets[i] = num
  end
  return octets
end

function _classify_ip(o1, o2)
  if o1 == 10 then
    return "私有地址 (RFC 1918 Class A)"
  elseif o1 == 172 and (o2 >= 16 and o2 <= 31) then
    return "私有地址 (RFC 1918 Class B)"
  elseif o1 == 192 and o2 == 168 then
    return "私有地址 (RFC 1918 Class C)"
  elseif o1 == 127 then
    return "环回地址 (Loopback)"
  elseif o1 == 169 and o2 == 254 then
    return "链路本地 (Link-Local / APIPA)"
  elseif o1 >= 224 and o1 <= 239 then
    return "多播组播地址 (Multicast Class D)"
  elseif o1 >= 240 and o1 <= 255 then
    return "保留试验地址 (Class E)"
  elseif o1 == 0 then
    return "未指定网络 (Current Network)"
  else
    return "公网单播地址 (Public IPv4)"
  end
end

function _calc_subnet(ipStr, prefixOrMask)
  local ip = parseIpv4(ipStr)
  if ip == nil then
    return nil, "IPv4 地址格式无效 (应如 192.168.1.1)"
  end

  local prefix = nil
  local maskOct = nil

  local pmStr = trim(tostring(prefixOrMask))
  if string.find(pmStr, ".", 1, true) then
    local m = parseIpv4(pmStr)
    if m == nil then
      return nil, "子网掩码无效 (应如 255.255.255.0)"
    end
    prefix = maskOctetsToPrefix(m)
    if prefix == nil then
      return nil, "非连续子网掩码"
    end
    maskOct = m
  else
    local pNum = tonumber(pmStr)
    if pNum == nil or pNum < 0 or pNum > 32 then
      return nil, "掩码位数必须在 0 ~ 32 之间"
    end
    prefix = math.floor(pNum)
    maskOct = prefixToMaskOctets(prefix)
  end

  local netOct = {}
  local wildOct = {}
  local bcastOct = {}
  for i = 1, 4 do
    netOct[i] = bitAnd8(ip[i], maskOct[i])
    wildOct[i] = 255 - maskOct[i]
    bcastOct[i] = netOct[i] + wildOct[i]
  end

  local totalIps = math.floor(2 ^ (32 - prefix))
  local usableIps = 0
  local firstUsable = ""
  local lastUsable = ""

  if prefix == 32 then
    usableIps = 1
    firstUsable = string.format("%d.%d.%d.%d", ip[1], ip[2], ip[3], ip[4])
    lastUsable = firstUsable
  elseif prefix == 31 then
    usableIps = 2
    firstUsable = string.format("%d.%d.%d.%d", netOct[1], netOct[2], netOct[3], netOct[4])
    lastUsable = string.format("%d.%d.%d.%d", bcastOct[1], bcastOct[2], bcastOct[3], bcastOct[4])
  else
    usableIps = totalIps - 2
    firstUsable = string.format("%d.%d.%d.%d", netOct[1], netOct[2], netOct[3], netOct[4] + 1)
    lastUsable = string.format("%d.%d.%d.%d", bcastOct[1], bcastOct[2], bcastOct[3], bcastOct[4] - 1)
  end

  local netStr = string.format("%d.%d.%d.%d", netOct[1], netOct[2], netOct[3], netOct[4])
  local bcastStr = string.format("%d.%d.%d.%d", bcastOct[1], bcastOct[2], bcastOct[3], bcastOct[4])
  local maskStr = string.format("%d.%d.%d.%d", maskOct[1], maskOct[2], maskOct[3], maskOct[4])
  local wildStr = string.format("%d.%d.%d.%d", wildOct[1], wildOct[2], wildOct[3], wildOct[4])
  local ipClass = _classify_ip(ip[1], ip[2])

  return {
    ip = string.format("%d.%d.%d.%d", ip[1], ip[2], ip[3], ip[4]),
    prefix = prefix,
    cidr = netStr .. "/" .. tostring(prefix),
    netStr = netStr,
    bcastStr = bcastStr,
    maskStr = maskStr,
    wildStr = wildStr,
    totalIps = totalIps,
    usableIps = usableIps,
    firstUsable = firstUsable,
    lastUsable = lastUsable,
    ipClass = ipClass
  }, nil
end

function calculate()
  local raw = trim(state.get("cidrInput") or "")
  if raw == "" then
    state.set("hasError", true)
    state.set("errorMsg", "请输入 IP 地址与子网掩码 (如 192.168.1.1/24)")
    state.set("hasResult", false)
    return nil
  end

  local ipPart = ""
  local maskPart = ""

  local slashPos = string.find(raw, "/", 1, true)
  if slashPos then
    ipPart = string.sub(raw, 1, slashPos - 1)
    maskPart = string.sub(raw, slashPos + 1)
  else
    local spacePos = string.find(raw, " ", 1, true)
    if spacePos then
      ipPart = string.sub(raw, 1, spacePos - 1)
      maskPart = string.sub(raw, spacePos + 1)
    else
      ipPart = raw
      maskPart = state.get("prefixLen") or "24"
    end
  end

  local res, err = _calc_subnet(ipPart, maskPart)
  if res == nil then
    state.set("hasError", true)
    state.set("errorMsg", err or "计算错误")
    state.set("hasResult", false)
    return nil
  end

  state.set("resCidr", res.cidr)
  state.set("resNet", res.netStr)
  state.set("resMask", res.maskStr .. " (/" .. tostring(res.prefix) .. ")")
  state.set("resWild", res.wildStr)
  state.set("resBcast", res.bcastStr)
  state.set("resRange", res.firstUsable .. " ~ " .. res.lastUsable)
  state.set("resUsable", tostring(res.usableIps) .. " / " .. tostring(res.totalIps))
  state.set("resClass", res.ipClass)

  local summary = "CIDR 网络: " .. res.cidr .. "\n" ..
                  "网络地址: " .. res.netStr .. "\n" ..
                  "子网掩码: " .. res.maskStr .. "\n" ..
                  "反掩码: " .. res.wildStr .. "\n" ..
                  "广播地址: " .. res.bcastStr .. "\n" ..
                  "可用主机范围: " .. res.firstUsable .. " ~ " .. res.lastUsable .. "\n" ..
                  "可用主机数: " .. tostring(res.usableIps) .. "\n" ..
                  "IP类型: " .. res.ipClass
  state.set("copyText", summary)

  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function setPrefix(prefixVal)
  local cur = state.get("cidrInput") or "192.168.1.1"
  local slashPos = string.find(cur, "/", 1, true)
  local ipPart = cur
  if slashPos then
    ipPart = string.sub(cur, 1, slashPos - 1)
  end
  state.set("cidrInput", trim(ipPart) .. "/" .. tostring(prefixVal))
  calculate()
  return nil
end

function copyResult()
  local text = state.get("copyText") or ""
  if text ~= "" and clipboard and clipboard.set then
    clipboard.set(text)
  end
  if dialog and dialog.toast then
    dialog.toast("已复制网络计算结果")
  end
  return nil
end

function onInit()
  state.set("cidrInput", "192.168.1.1/24")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  state.set("resCidr", "")
  state.set("resNet", "")
  state.set("resMask", "")
  state.set("resWild", "")
  state.set("resBcast", "")
  state.set("resRange", "")
  state.set("resUsable", "")
  state.set("resClass", "")
  state.set("copyText", "")
  calculate()
  return nil
end
