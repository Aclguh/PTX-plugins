-- nfc_smart_tag — NFC 电子名片与快捷写入器
-- 支持标准 Wi-Fi 接入标签 (WIFI:S:..)、vCard 电子名片与网址 URI 编码烧录

local currentTagType = "wifi" -- "wifi" | "vcard" | "uri"

function _buildWifiPayload(ssid, pwd, auth)
  local s = ssid or "MyWiFi"
  local p = pwd or ""
  local a = auth or "WPA"
  return "WIFI:T:" .. a .. ";S:" .. s .. ";P:" .. p .. ";;"
end

function _buildVCardPayload(name, phone, email, org)
  local n = name or "张三"
  local t = phone or ""
  local e = email or ""
  local o = org or ""
  return "BEGIN:VCARD\nVERSION:3.0\nFN:" .. n .. "\nTEL:" .. t .. "\nEMAIL:" .. e .. "\nORG:" .. o .. "\nEND:VCARD"
end

local function updatePreview()
  local payload = ""
  if currentTagType == "wifi" then
    local ssid = state.get("wifiSsid") or ""
    local pwd = state.get("wifiPwd") or ""
    payload = _buildWifiPayload(ssid, pwd, "WPA")
  elseif currentTagType == "vcard" then
    local name = state.get("vcardName") or ""
    local phone = state.get("vcardPhone") or ""
    local email = state.get("vcardEmail") or ""
    local org = state.get("vcardOrg") or ""
    payload = _buildVCardPayload(name, phone, email, org)
  else
    payload = state.get("uriInput") or "https://github.com/Aclguh/PTX-plugins"
  end
  state.set("generatedPayload", payload)
end

-- ---------------- UI 事件 ----------------
function onInit()
  currentTagType = "wifi"

  state.set("isWifiType", true)
  state.set("isVcardType", false)
  state.set("isUriType", false)
  state.set("typeTitle", "当前类型: Wi-Fi 快速接入标签")

  state.set("wifiSsid", "Office-5G")
  state.set("wifiPwd", "SecurePass123")
  state.set("vcardName", "李工")
  state.set("vcardPhone", "13800138000")
  state.set("vcardEmail", "developer@example.com")
  state.set("vcardOrg", "科技创新实验室")
  state.set("uriInput", "https://github.com/Aclguh/PTX-plugins")

  state.set("statusMsg", "请选择标签类型并填写参数后贴近卡片写入")
  state.set("hasReadData", false)
  state.set("readResult", "")
  updatePreview()
end

function selectWifi()
  currentTagType = "wifi"
  state.set("isWifiType", true)
  state.set("isVcardType", false)
  state.set("isUriType", false)
  state.set("typeTitle", "当前类型: Wi-Fi 快速接入标签")
  updatePreview()
end

function selectVcard()
  currentTagType = "vcard"
  state.set("isWifiType", false)
  state.set("isVcardType", true)
  state.set("isUriType", false)
  state.set("typeTitle", "当前类型: vCard 电子名片标签")
  updatePreview()
end

function selectUri()
  currentTagType = "uri"
  state.set("isWifiType", false)
  state.set("isVcardType", false)
  state.set("isUriType", true)
  state.set("typeTitle", "当前类型: 网页直达 URL 标签")
  updatePreview()
end

function refreshPreview()
  updatePreview()
  dialog.toast("已更新 NDEF 报文预览")
end

function writeTag()
  updatePreview()
  local payload = state.get("generatedPayload") or ""
  if string.len(payload) == 0 then
    dialog.toast("待写入报文为空")
    return nil
  end

  state.set("statusMsg", "正在等待贴近 NFC 标签卡片...")
  nfc.writeNdef(payload, function(res)
    if res ~= nil and res.ok == true then
      state.set("statusMsg", "写入成功！标签已烧录完毕")
      dialog.toast("NFC 标签写入成功")
    else
      state.set("statusMsg", "写入失败或超时")
      dialog.toast("写入失败")
    end
    return nil
  end)
end

function readAndParseTag()
  state.set("statusMsg", "正在等待贴近 NFC 标签读取...")
  nfc.readNdef(function(res)
    if res ~= nil and res.ok == true and res.records ~= nil and #res.records > 0 then
      local first = res.records[1]
      local p = first.payload or ""
      state.set("readResult", p)
      state.set("hasReadData", true)
      state.set("statusMsg", "成功读取 NFC 智能标签")
      dialog.toast("读取解析完成")
    else
      state.set("statusMsg", "未感应到有效 NDEF 标签")
      dialog.toast("未读取到标签")
    end
    return nil
  end)
end

function copyPayload()
  local txt = state.get("generatedPayload") or ""
  if string.len(txt) == 0 then
    dialog.toast("暂无报文可复制")
    return nil
  end
  clipboard.set(txt)
  dialog.toast("已复制报文")
end
