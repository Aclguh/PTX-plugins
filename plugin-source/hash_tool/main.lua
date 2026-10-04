-- hash_tool — MD5 / SHA-1 / SHA-256 哈希计算 (v1.1.0 增强版)
-- 在 sample_plugins 基础版之上新增大小写切换与剪贴板粘贴

local function toUpperIfNeeded(s)
  if state.get("isUpper") then
    return string.upper(s)
  end
  return s
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _hashAll(text)
  return {
    md5 = toUpperIfNeeded(hash.md5(text)),
    sha1 = toUpperIfNeeded(hash.sha1(text)),
    sha256 = toUpperIfNeeded(hash.sha256(text)),
  }
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("input", "")
  state.set("md5Val", "")
  state.set("sha1Val", "")
  state.set("sha256Val", "")
  state.set("hasResult", false)
  state.set("isUpper", false)
  state.set("caseLabel", "输出: 小写")
end

function calculate()
  local str = state.get("input") or ""
  if str == "" then
    dialog.toast("请输入内容")
    return nil
  end
  state.set("md5Val", toUpperIfNeeded(hash.md5(str)))
  state.set("sha1Val", toUpperIfNeeded(hash.sha1(str)))
  state.set("sha256Val", toUpperIfNeeded(hash.sha256(str)))
  state.set("hasResult", true)
  dialog.toast("哈希计算完成")
end

function toggleCase()
  local nextVal = not state.get("isUpper")
  state.set("isUpper", nextVal)
  if nextVal then
    state.set("caseLabel", "输出: 大写")
  else
    state.set("caseLabel", "输出: 小写")
  end
  -- 已有结果时按新格式重算
  if state.get("hasResult") then
    local str = state.get("input") or ""
    if str ~= "" then
      state.set("md5Val", toUpperIfNeeded(hash.md5(str)))
      state.set("sha1Val", toUpperIfNeeded(hash.sha1(str)))
      state.set("sha256Val", toUpperIfNeeded(hash.sha256(str)))
    end
  end
end

function pasteInput()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("input", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end
