-- ua_tool — User-Agent 解析工具
-- 识别操作系统、浏览器、渲染内核与设备形态

local function extractVersionAfter(ua, prefix)
  local pos = string.find(ua, prefix, 1, true)
  if pos == nil then return nil end
  local start = pos + string.len(prefix)
  local ualen = string.len(ua)
  local digits = {}
  local i = start
  while i <= ualen do
    local c = string.byte(ua, i)
    if (c >= 48 and c <= 57) or c == 46 or c == 95 then -- 0-9, ., _
      if c == 95 then
        digits[#digits + 1] = "."
      else
        digits[#digits + 1] = string.char(c)
      end
      i = i + 1
    else
      break
    end
  end
  if #digits == 0 then return nil end
  return table.concat(digits)
end

function _parse_ua(ua)
  local res = {
    os = "未知操作系统",
    osVer = "",
    browser = "未知浏览器",
    browserVer = "",
    engine = "未知内核",
    deviceType = "桌面端 (Desktop)"
  }

  if ua == nil or string.len(ua) == 0 then
    return res
  end

  -- 设备形态
  if string.find(ua, "iPad", 1, true) or string.find(ua, "Tablet", 1, true) then
    res.deviceType = "平板 (Tablet)"
  elseif string.find(ua, "Mobile", 1, true) or string.find(ua, "iPhone", 1, true) or string.find(ua, "Android", 1, true) then
    res.deviceType = "移动端 (Mobile)"
  elseif string.find(ua, "bot", 1, true) or string.find(ua, "Spider", 1, true) or string.find(ua, "crawl", 1, true) then
    res.deviceType = "爬虫/网络机器人 (Bot)"
  else
    res.deviceType = "桌面端 (Desktop)"
  end

  -- 内核
  if string.find(ua, "AppleWebKit", 1, true) then
    if string.find(ua, "Chrome", 1, true) or string.find(ua, "CriOS", 1, true) then
      res.engine = "Blink (Chromium)"
    else
      res.engine = "WebKit"
    end
  elseif string.find(ua, "Gecko", 1, true) and string.find(ua, "Firefox", 1, true) then
    res.engine = "Gecko"
  elseif string.find(ua, "Trident", 1, true) or string.find(ua, "MSIE", 1, true) then
    res.engine = "Trident"
  end

  -- 操作系统
  if string.find(ua, "Windows NT 10.0", 1, true) then
    res.os = "Windows"
    res.osVer = "10 / 11"
  elseif string.find(ua, "Windows NT 6.3", 1, true) then
    res.os = "Windows"
    res.osVer = "8.1"
  elseif string.find(ua, "Windows NT 6.1", 1, true) then
    res.os = "Windows"
    res.osVer = "7"
  elseif string.find(ua, "Windows NT", 1, true) then
    res.os = "Windows"
    res.osVer = extractVersionAfter(ua, "Windows NT ") or ""
  elseif string.find(ua, "iPhone", 1, true) or string.find(ua, "iPad", 1, true) then
    res.os = "iOS"
    res.osVer = extractVersionAfter(ua, "CPU iPhone OS ") or extractVersionAfter(ua, "CPU OS ") or ""
  elseif string.find(ua, "Android", 1, true) then
    res.os = "Android"
    res.osVer = extractVersionAfter(ua, "Android ") or ""
  elseif string.find(ua, "HarmonyOS", 1, true) then
    res.os = "HarmonyOS"
    res.osVer = extractVersionAfter(ua, "HarmonyOS ") or ""
  elseif string.find(ua, "Mac OS X", 1, true) then
    res.os = "macOS"
    res.osVer = extractVersionAfter(ua, "Mac OS X ") or ""
  elseif string.find(ua, "Linux", 1, true) then
    res.os = "Linux"
    res.osVer = ""
  end

  -- 浏览器
  if string.find(ua, "MicroMessenger", 1, true) then
    res.browser = "微信内置浏览器"
    res.browserVer = extractVersionAfter(ua, "MicroMessenger/") or ""
  elseif string.find(ua, "QQBrowser", 1, true) then
    res.browser = "QQ 浏览器"
    res.browserVer = extractVersionAfter(ua, "QQBrowser/") or ""
  elseif string.find(ua, "Edg/", 1, true) or string.find(ua, "Edge/", 1, true) then
    res.browser = "Microsoft Edge"
    res.browserVer = extractVersionAfter(ua, "Edg/") or extractVersionAfter(ua, "Edge/") or ""
  elseif string.find(ua, "Chrome/", 1, true) or string.find(ua, "CriOS/", 1, true) then
    res.browser = "Google Chrome"
    res.browserVer = extractVersionAfter(ua, "Chrome/") or extractVersionAfter(ua, "CriOS/") or ""
  elseif string.find(ua, "Firefox/", 1, true) or string.find(ua, "FxiOS/", 1, true) then
    res.browser = "Mozilla Firefox"
    res.browserVer = extractVersionAfter(ua, "Firefox/") or extractVersionAfter(ua, "FxiOS/") or ""
  elseif string.find(ua, "Safari/", 1, true) then
    res.browser = "Apple Safari"
    res.browserVer = extractVersionAfter(ua, "Version/") or ""
  elseif string.find(ua, "MSIE", 1, true) then
    res.browser = "Internet Explorer"
    res.browserVer = extractVersionAfter(ua, "MSIE ") or ""
  end

  return res
end

function parse()
  local input = state.get("uaInput") or ""
  if string.len(input) == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入待解析的 User-Agent 字符串")
    state.set("hasResult", false)
    return nil
  end

  local info = _parse_ua(input)
  state.set("hasError", false)
  state.set("errorMsg", "")
  state.set("osDesc", info.os .. (string.len(info.osVer) > 0 and (" " .. info.osVer) or ""))
  state.set("browserDesc", info.browser .. (string.len(info.browserVer) > 0 and (" " .. info.browserVer) or ""))
  state.set("deviceDesc", info.deviceType)
  state.set("engineDesc", info.engine)

  local summary = string.format("系统: %s\n浏览器: %s\n形态: %s\n内核: %s",
    state.get("osDesc"), state.get("browserDesc"), state.get("deviceDesc"), state.get("engineDesc"))
  state.set("summary", summary)
  state.set("hasResult", true)
  return nil
end

function setPresetWin()
  state.set("uaInput", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
  parse()
  return nil
end

function setPresetIos()
  state.set("uaInput", "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1")
  parse()
  return nil
end

function setPresetAndroid()
  state.set("uaInput", "Mozilla/5.0 (Linux; Android 14; SM-S9180) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.193 Mobile Safari/537.36 MicroMessenger/8.0.47.2560")
  parse()
  return nil
end

function clearAll()
  state.set("uaInput", "")
  state.set("osDesc", "")
  state.set("browserDesc", "")
  state.set("deviceDesc", "")
  state.set("engineDesc", "")
  state.set("summary", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function pasteUa()
  clipboard.get(function(text)
    if text ~= nil then
      state.set("uaInput", text)
      parse()
    end
    return nil
  end)
  return nil
end

function onInit()
  state.set("uaInput", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
  state.set("osDesc", "")
  state.set("browserDesc", "")
  state.set("deviceDesc", "")
  state.set("engineDesc", "")
  state.set("summary", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  parse()
  return nil
end
