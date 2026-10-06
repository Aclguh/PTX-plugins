local STATUS_CODES = {
  { code = "100", en = "Continue", zh = "继续", desc = "客户端应继续其请求。常用于大文件上传 Expect: 100-continue 预检。" },
  { code = "101", en = "Switching Protocols", zh = "切换协议", desc = "服务器已理解且同意切换协议，常用于从 HTTP 升级到 WebSocket 协议。" },
  { code = "103", en = "Early Hints", zh = "早期提示", desc = "允许客户端在服务器仍在准备完整响应时，提前预加载 Link 头部指定的资源。" },

  { code = "200", en = "OK", zh = "请求成功", desc = "请求已成功处理。GET 返回实体，POST 返回处理结果。" },
  { code = "201", en = "Created", zh = "已创建", desc = "请求成功且服务器已创建了新资源，常在 Location 头中给出新资源的 URL。" },
  { code = "202", en = "Accepted", zh = "已接受", desc = "已接受请求但尚未处理完毕，常用于异步队列任务或长时间批处理。" },
  { code = "204", en = "No Content", zh = "无内容", desc = "成功处理但不需要返回响应实体，常用于 DELETE 操作或无需更新视图的表单提交。" },
  { code = "206", en = "Partial Content", zh = "部分内容", desc = "服务器已成功处理部分 GET 请求，常用于多线程分块下载或 Range 视频播放。" },

  { code = "301", en = "Moved Permanently", zh = "永久重定向", desc = "资源已永久转移到新 URL。搜索引擎会迁移权重，浏览器会默认永久缓存该跳转。" },
  { code = "302", en = "Found", zh = "临时重定向", desc = "资源临时位于新 URL。搜索引擎不会转移权重，传统实现中可能将 POST 变成 GET。" },
  { code = "303", en = "See Other", zh = "查看其它", desc = "必须使用 GET 方法定向到新 URL，常用于 POST 提交后防止重复提交表单跳转。" },
  { code = "304", en = "Not Modified", zh = "未修改 (协商缓存)", desc = "资源未发生修改，客户端应直接使用本地协商缓存 (If-None-Match/If-Modified-Since)。" },
  { code = "307", en = "Temporary Redirect", zh = "临时重定向 (保持方法)", desc = "严格保持原始 HTTP 请求方法 (POST 仍为 POST) 进行临时重定向。" },
  { code = "308", en = "Permanent Redirect", zh = "永久重定向 (保持方法)", desc = "严格保持原始 HTTP 请求方法 (POST 仍为 POST) 进行永久重定向。" },

  { code = "400", en = "Bad Request", zh = "错误请求", desc = "客户端请求语法错误或参数不合法，服务器无法理解。" },
  { code = "401", en = "Unauthorized", zh = "未授权 / 认证失败", desc = "请求需要身份验证 (Token 过期、缺失或无效)，需在 WWW-Authenticate 头提供凭据。" },
  { code = "402", en = "Payment Required", zh = "要求付费", desc = "保留给未来数字支付使用，部分 SaaS API 用于配额耗尽提示。" },
  { code = "403", en = "Forbidden", zh = "禁止访问", desc = "服务器理解请求但拒绝授权，即使用户已登录也无权限操作该资源。" },
  { code = "404", en = "Not Found", zh = "未找到资源", desc = "服务器无法根据 URI 找到对应资源，或不想暴露资源存在而隐瞒 403。" },
  { code = "405", en = "Method Not Allowed", zh = "方法不允许", desc = "请求行中指定的 HTTP 方法 (如 GET/POST/PUT) 不被该资源支持。" },
  { code = "408", en = "Request Timeout", zh = "请求超时", desc = "服务器等待客户端发送请求超时，客户端可直接重试。" },
  { code = "409", en = "Conflict", zh = "资源冲突", desc = "请求与服务器当前资源状态发生冲突，常见于并发乐观锁更新或重复主键冲突。" },
  { code = "410", en = "Gone", zh = "资源已永久删除", desc = "资源曾经存在但现已被永久移除，且不会再恢复。搜索引擎会立即清理该索引。" },
  { code = "413", en = "Payload Too Large", zh = "请求体过大", desc = "客户端发送的请求体超过了服务器能够或愿意处理的最大体积限制。" },
  { code = "415", en = "Unsupported Media Type", zh = "不支持的媒体类型", desc = "客户端上传实体的 Content-Type 格式不被服务器支持 (如传入 XML 但只接受 JSON)。" },
  { code = "418", en = "I'm a teapot", zh = "我是茶壶 (愚人节彩蛋)", desc = "RFC 2324 超文本咖啡壶控制协议彩蛋，服务器拒绝冲泡咖啡，因为它是茶壶。" },
  { code = "422", en = "Unprocessable Entity", zh = "无法处理的实体 (校验失败)", desc = "请求格式语法正确但包含语义错误，RESTful API 极常用于字段参数校验失败返回。" },
  { code = "429", en = "Too Many Requests", zh = "请求过多 (触发限流)", desc = "用户在给定时间内发送了太多请求，触发了 API 限流/防刷机制，常伴随 Retry-After 头。" },
  { code = "451", en = "Unavailable For Legal Reasons", zh = "因法律原因不可用", desc = "资源因政府审查或法律禁令而被屏蔽阻止访问。" },

  { code = "500", en = "Internal Server Error", zh = "内部服务器错误", desc = "服务器遇到未捕获的异常或内部逻辑崩溃，无法完成请求。" },
  { code = "501", en = "Not Implemented", zh = "未实现", desc = "服务器不支持实现该请求所需的功能或方法。" },
  { code = "502", en = "Bad Gateway", zh = "网关错误", desc = "作为网关或反向代理的服务器 (如 Nginx) 从上游服务器收到了无效响应。" },
  { code = "503", en = "Service Unavailable", zh = "服务不可用 (过载/维护)", desc = "服务器当前超载或正在停机维护，通常为暂时状态，可配合 Retry-After 头。" },
  { code = "504", en = "Gateway Timeout", zh = "网关超时", desc = "作为网关或反向代理的服务器在规定时间内未能从上游服务器及时获得响应。" },
  { code = "505", en = "HTTP Version Not Supported", zh = "HTTP 版本不支持", desc = "服务器不支持请求中所使用的 HTTP 协议主版本。" }
}

local MIME_TYPES = {
  { ext = "json", mime = "application/json", desc = "JSON 数据交互标准格式" },
  { ext = "html", mime = "text/html; charset=utf-8", desc = "HTML 网页文档" },
  { ext = "form", mime = "application/x-www-form-urlencoded", desc = "标准表单 POST 键值对" },
  { ext = "multipart", mime = "multipart/form-data", desc = "文件上传复合表单" },
  { ext = "xml", mime = "application/xml", desc = "XML 数据交互格式" },
  { ext = "js", mime = "application/javascript", desc = "JavaScript 脚本" },
  { ext = "css", mime = "text/css; charset=utf-8", desc = "CSS 层叠样式表" },
  { ext = "plain", mime = "text/plain; charset=utf-8", desc = "纯文本内容" },
  { ext = "png", mime = "image/png", desc = "PNG 无损位图图像" },
  { ext = "jpeg/jpg", mime = "image/jpeg", desc = "JPEG 有损压缩图像" },
  { ext = "webp", mime = "image/webp", desc = "Google WebP 现代高压缩图像" },
  { ext = "svg", mime = "image/svg+xml", desc = "SVG 矢量图形" },
  { ext = "pdf", mime = "application/pdf", desc = "PDF 便携式文档" },
  { ext = "zip", mime = "application/zip", desc = "ZIP 压缩归档文件" },
  { ext = "octet-stream", mime = "application/octet-stream", desc = "通用二进制流 (强迫下载)" },
  { ext = "sse", mime = "text/event-stream", desc = "Server-Sent Events 实时事件流" },
  { ext = "mp4", mime = "video/mp4", desc = "MP4 视音频媒体流" }
}

local function to_lower(s)
  local len = string.len(s)
  local out = {}
  for i = 1, len do
    local b = string.byte(s, i)
    if b >= 65 and b <= 90 then
      out[#out + 1] = string.char(b + 32)
    else
      out[#out + 1] = string.sub(s, i, i)
    end
  end
  return table.concat(out, "")
end

function _search_status(query)
  local q = to_lower(query or "")
  local results = {}
  for i = 1, #STATUS_CODES do
    local item = STATUS_CODES[i]
    if q == "" then
      results[#results + 1] = item
    else
      local cMatch = string.find(item.code, q, 1, true) ~= nil
      local enMatch = string.find(to_lower(item.en), q, 1, true) ~= nil
      local zhMatch = string.find(item.zh, q, 1, true) ~= nil
      local descMatch = string.find(item.desc, q, 1, true) ~= nil
      if cMatch or enMatch or zhMatch or descMatch then
        results[#results + 1] = item
      end
    end
  end
  return results
end

function _search_mime(query)
  local q = to_lower(query or "")
  local results = {}
  for i = 1, #MIME_TYPES do
    local item = MIME_TYPES[i]
    if q == "" then
      results[#results + 1] = item
    else
      local extMatch = string.find(to_lower(item.ext), q, 1, true) ~= nil
      local mimeMatch = string.find(to_lower(item.mime), q, 1, true) ~= nil
      local descMatch = string.find(item.desc, q, 1, true) ~= nil
      if extMatch or mimeMatch or descMatch then
        results[#results + 1] = item
      end
    end
  end
  return results
end

local function format_display(statuses, mimes)
  local lines = {}
  if #statuses > 0 then
    lines[#lines + 1] = "【HTTP 状态码 (" .. tostring(#statuses) .. " 个匹配)】"
    for i = 1, #statuses do
      local s = statuses[i]
      lines[#lines + 1] = string.format("[%s %s] %s", s.code, s.en, s.zh)
      lines[#lines + 1] = "  释义: " .. s.desc
      lines[#lines + 1] = ""
    end
  end

  if #mimes > 0 then
    lines[#lines + 1] = "【MIME Content-Type 常见类型 (" .. tostring(#mimes) .. " 个匹配)】"
    for i = 1, #mimes do
      local m = mimes[i]
      lines[#lines + 1] = string.format("• %s -> %s (%s)", m.ext, m.mime, m.desc)
    end
  end

  if #statuses == 0 and #mimes == 0 then
    lines[#lines + 1] = "未找到与关键词匹配的状态码或 MIME 类型"
  end

  return table.concat(lines, "\n")
end

function searchQuery()
  local q = state.get("inputText") or ""
  local statuses = _search_status(q)
  local mimes = _search_mime(q)
  local outStr = format_display(statuses, mimes)
  state.set("output", outStr)
  state.set("resultCount", "共匹配到 " .. tostring(#statuses) .. " 个状态码与 " .. tostring(#mimes) .. " 个 MIME 类型")
  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function filter2xx()
  state.set("inputText", "2")
  searchQuery()
  return nil
end

function filter3xx()
  state.set("inputText", "3")
  searchQuery()
  return nil
end

function filter4xx()
  state.set("inputText", "4")
  searchQuery()
  return nil
end

function filter5xx()
  state.set("inputText", "5")
  searchQuery()
  return nil
end

function filterMime()
  state.set("inputText", "json")
  searchQuery()
  return nil
end

function copyResult()
  local out = state.get("output") or ""
  if out ~= "" then
    clipboard.set(out)
    dialog.toast("已复制词典查询结果")
  end
  return nil
end

function clearAll()
  state.set("inputText", "")
  searchQuery()
  return nil
end

function onInit()
  state.set("inputText", "404")
  searchQuery()
  return nil
end
