-- file_hash_tool — 本地文件哈希校验与属性分析
-- 快速计算 MD5、SHA-1、SHA-256 与 CRC32 校验码，并提供哈希比对验证

function _formatSize(bytes)
  if bytes == nil or bytes < 0 then
    return "0 B"
  end
  if bytes < 1024 then
    return tostring(bytes) .. " B"
  elseif bytes < 1048576 then
    return string.format("%.1f KB", bytes / 1024)
  elseif bytes < 1073741824 then
    return string.format("%.2f MB", bytes / 1048576)
  else
    return string.format("%.2f GB", bytes / 1073741824)
  end
end

function _formatTime(ms)
  if ms == nil or ms <= 0 then
    return "未知"
  end
  local sec = math.floor(ms / 1000)
  return util.formatTime(sec, "YYYY-MM-DD HH:mm:ss")
end

function _trim(s)
  if s == nil then return "" end
  local i = 1
  local j = string.len(s)
  while i <= j and string.byte(s, i) <= 32 do
    i = i + 1
  end
  while j >= i and string.byte(s, j) <= 32 do
    j = j - 1
  end
  if i > j then return "" end
  return string.sub(s, i, j)
end

function onInit()
  state.set("hasFile", false)
  state.set("fileName", "")
  state.set("fileSize", "")
  state.set("fileExt", "")
  state.set("fileTime", "")
  state.set("md5Val", "")
  state.set("sha1Val", "")
  state.set("sha256Val", "")
  state.set("crc32Val", "")
  state.set("compareHashText", "")
  state.set("hasCompareResult", false)
  state.set("compareResult", "")
end

function chooseFile()
  fs.pickFile(function(path)
    if path and path ~= "" then
      local meta, err = fs.hash(path)
      if meta then
        state.set("fileName", meta.name or path)
        state.set("fileSize", _formatSize(meta.size or 0))
        local ext = meta.extension or ""
        if ext == "" then ext = "未知" end
        state.set("fileExt", ext)
        state.set("fileTime", _formatTime(meta.modifiedMs or 0))
        state.set("md5Val", string.upper(meta.md5 or ""))
        state.set("sha1Val", string.upper(meta.sha1 or ""))
        state.set("sha256Val", string.upper(meta.sha256 or ""))
        state.set("crc32Val", string.upper(meta.crc32 or ""))
        state.set("hasFile", true)
        state.set("hasCompareResult", false)
        dialog.toast("哈希计算完成")
      else
        dialog.toast("计算哈希失败: " .. (err or "无法读取文件"))
      end
    else
      dialog.toast("已取消选择文件")
    end
  end)
end

function copyMd5()
  local val = state.get("md5Val") or ""
  if val ~= "" then
    clipboard.set(val)
    dialog.toast("已复制 MD5 校验码")
  end
end

function copySha1()
  local val = state.get("sha1Val") or ""
  if val ~= "" then
    clipboard.set(val)
    dialog.toast("已复制 SHA-1 校验码")
  end
end

function copySha256()
  local val = state.get("sha256Val") or ""
  if val ~= "" then
    clipboard.set(val)
    dialog.toast("已复制 SHA-256 校验码")
  end
end

function copyCrc32()
  local val = state.get("crc32Val") or ""
  if val ~= "" then
    clipboard.set(val)
    dialog.toast("已复制 CRC32 校验码")
  end
end

function checkCompare()
  local raw = state.get("compareHashText") or ""
  local target = string.upper(_trim(raw))
  if target == "" then
    dialog.toast("请输入待比对的校验码")
    return nil
  end

  local m = state.get("md5Val") or ""
  local s1 = state.get("sha1Val") or ""
  local s256 = state.get("sha256Val") or ""
  local c32 = state.get("crc32Val") or ""

  if target == m then
    state.set("compareResult", "✅ 匹配成功: 与 MD5 校验值完全一致")
  elseif target == s1 then
    state.set("compareResult", "✅ 匹配成功: 与 SHA-1 校验值完全一致")
  elseif target == s256 then
    state.set("compareResult", "✅ 匹配成功: 与 SHA-256 校验值完全一致")
  elseif target == c32 then
    state.set("compareResult", "✅ 匹配成功: 与 CRC32 校验值完全一致")
  else
    state.set("compareResult", "❌ 比对失败: 不匹配计算出的任何哈希值")
  end
  state.set("hasCompareResult", true)
end

function pasteAndCompare()
  clipboard.get(function(text)
    if text and text ~= "" then
      state.set("compareHashText", _trim(text))
      checkCompare()
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
