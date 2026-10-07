-- whois_tool — 域名 WHOIS 与 RDAP 查询

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

function _clean_domain(raw)
  local s = trim(string.lower(raw or ""))
  if string.find(s, "https://", 1, true) == 1 then
    s = string.sub(s, 9)
  elseif string.find(s, "http://", 1, true) == 1 then
    s = string.sub(s, 8)
  end

  local slashPos = string.find(s, "/", 1, true)
  if slashPos then
    s = string.sub(s, 1, slashPos - 1)
  end

  local colonPos = string.find(s, ":", 1, true)
  if colonPos then
    s = string.sub(s, 1, colonPos - 1)
  end

  return trim(s)
end

function _valid_domain(s)
  if s == "" then return false end
  local len = strLen(s)
  if len > 253 or len < 3 then return false end
  if not string.find(s, ".", 1, true) then return false end

  for i = 1, len do
    local c = string.sub(s, i, i)
    local isOk = false
    if c >= "a" and c <= "z" then isOk = true end
    if c >= "0" and c <= "9" then isOk = true end
    if c == "." or c == "-" then isOk = true end
    if not isOk then return false end
  end
  return true
end

function _parse_rdap_json(bodyStr)
  local ok, data = pcall(function()
    return json.decode(bodyStr)
  end)
  if not ok or type(data) ~= "table" then
    return nil, "RDAP 响应无法解析为 JSON"
  end

  local domainName = data.ldhName or data.handle or "未知"
  local regDate = "-"
  local expDate = "-"
  local updDate = "-"

  if type(data.events) == "table" then
    for i = 1, #data.events do
      local ev = data.events[i]
      if type(ev) == "table" then
        local act = ev.eventAction
        local d = ev.eventDate or "-"
        if act == "registration" then
          regDate = d
        elseif act == "expiration" then
          expDate = d
        elseif act == "last changed" or act == "last update" then
          updDate = d
        end
      end
    end
  end

  local registrarName = "-"
  if type(data.entities) == "table" then
    for i = 1, #data.entities do
      local ent = data.entities[i]
      if type(ent) == "table" and type(ent.roles) == "table" then
        local isReg = false
        for r = 1, #ent.roles do
          if ent.roles[r] == "registrar" then isReg = true end
        end
        if isReg then
          if ent.vcardArray ~= nil and type(ent.vcardArray) == "table" and type(ent.vcardArray[2]) == "table" then
            local vprops = ent.vcardArray[2]
            for vp = 1, #vprops do
              local prop = vprops[vp]
              if type(prop) == "table" and prop[1] == "fn" then
                registrarName = tostring(prop[4] or ent.handle or "-")
              end
            end
          elseif ent.handle ~= nil then
            registrarName = tostring(ent.handle)
          end
        end
      end
    end
  end

  local statusList = {}
  if type(data.status) == "table" then
    for i = 1, #data.status do
      statusList[#statusList + 1] = tostring(data.status[i])
    end
  end
  local statusStr = (#statusList > 0) and table.concat(statusList, ", ") or "active"

  local nsList = {}
  if type(data.nameservers) == "table" then
    for i = 1, #data.nameservers do
      local ns = data.nameservers[i]
      if type(ns) == "table" and ns.ldhName ~= nil then
        nsList[#nsList + 1] = tostring(ns.ldhName)
      end
    end
  end
  local nsStr = (#nsList > 0) and table.concat(nsList, "\n") or "-"

  return {
    domain = domainName,
    registrar = registrarName,
    regDate = regDate,
    expDate = expDate,
    updDate = updDate,
    status = statusStr,
    nameservers = nsStr
  }, nil
end

function queryWhois()
  local raw = state.get("domainInput") or ""
  local domain = _clean_domain(raw)

  if not _valid_domain(domain) then
    state.set("hasError", true)
    state.set("errorMsg", "请输入有效的域名 (如 github.com 或 example.org)")
    state.set("hasResult", false)
    return nil
  end

  state.set("domainInput", domain)
  state.set("hasError", false)
  state.set("errorMsg", "")
  state.set("isLoading", true)
  state.set("resDomain", "正在查询 " .. domain .. " ...")

  local url = "https://rdap.org/domain/" .. domain
  if network and network.get then
    network.get(url)
  else
    state.set("hasError", true)
    state.set("errorMsg", "网络模块不可用")
    state.set("isLoading", false)
  end
  return nil
end

function onNetworkResponse(status, body)
  state.set("isLoading", false)
  local statusCode = tonumber(status) or 0

  if statusCode == 404 then
    state.set("hasError", true)
    state.set("errorMsg", "未找到该域名注册信息 (可能尚未注册或不支持 RDAP)")
    state.set("hasResult", false)
    return nil
  elseif statusCode ~= 200 then
    state.set("hasError", true)
    state.set("errorMsg", "RDAP 查询失败，HTTP 状态码: " .. tostring(status))
    state.set("hasResult", false)
    return nil
  end

  local res, err = _parse_rdap_json(body)
  if res == nil then
    state.set("hasError", true)
    state.set("errorMsg", err or "解析 WHOIS 失败")
    state.set("hasResult", false)
    return nil
  end

  state.set("resDomain", res.domain)
  state.set("resRegistrar", res.registrar)
  state.set("resRegDate", res.regDate)
  state.set("resExpDate", res.expDate)
  state.set("resUpdDate", res.updDate)
  state.set("resStatus", res.status)
  state.set("resNs", res.nameservers)

  local report = "【域名 WHOIS 查询报告】\n" ..
                 "域名: " .. res.domain .. "\n" ..
                 "注册商: " .. res.registrar .. "\n" ..
                 "注册时间: " .. res.regDate .. "\n" ..
                 "到期时间: " .. res.expDate .. "\n" ..
                 "更新时间: " .. res.updDate .. "\n" ..
                 "状态: " .. res.status .. "\n" ..
                 "Name Servers:\n" .. res.nameservers
  state.set("copyText", report)

  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function onNetworkError(message)
  state.set("isLoading", false)
  state.set("hasError", true)
  state.set("errorMsg", "网络请求出错: " .. tostring(message or "未知错误"))
  state.set("hasResult", false)
  return nil
end

function setDomain(d)
  state.set("domainInput", d)
  queryWhois()
  return nil
end

function copyResult()
  local text = state.get("copyText") or ""
  if text ~= "" and clipboard and clipboard.set then
    clipboard.set(text)
  end
  if dialog and dialog.toast then
    dialog.toast("已复制 WHOIS 报告")
  end
  return nil
end

function onInit()
  state.set("domainInput", "github.com")
  state.set("isLoading", false)
  state.set("resDomain", "")
  state.set("resRegistrar", "")
  state.set("resRegDate", "")
  state.set("resExpDate", "")
  state.set("resUpdDate", "")
  state.set("resStatus", "")
  state.set("resNs", "")
  state.set("copyText", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end
