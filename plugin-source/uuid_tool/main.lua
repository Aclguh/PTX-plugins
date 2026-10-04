-- uuid_tool — UUID 生成器
-- 批量生成 UUID v4, 支持大写/无连字符/花括号格式变换与一键复制

local BATCH_MAX = 100

local function removeDashes(s)
  local out = {}
  for i = 1, string.len(s) do
    local c = string.sub(s, i, i)
    if c ~= "-" then out[#out + 1] = c end
  end
  return table.concat(out)
end

local function applyFormat(id, mode)
  if mode == "upper" then
    return string.upper(id)
  elseif mode == "nodash" then
    return removeDashes(id)
  elseif mode == "brace" then
    return "{" .. string.upper(id) .. "}"
  end
  return id
end

-- ---------------- 测试钩子 (harness 专用) ----------------
function _uuidFormat(id, mode)
  return applyFormat(id, mode)
end

-- ---------------- 插件状态与交互 ----------------
function onInit()
  state.set("genCount", "5")
  state.set("fmtMode", "std")
  state.set("uuidDisplay", "")
  state.set("uuidInfo", "")
  state.set("hasResult", false)
end

local function regenerateIfPossible()
  if state.get("hasResult") then
    generate()
  end
end

function generate()
  local count = tonumber(state.get("genCount") or "5")
  if count == nil then count = 5 end
  count = math.floor(count)
  if count < 1 then count = 1 end
  if count > BATCH_MAX then count = BATCH_MAX end

  local mode = state.get("fmtMode") or "std"
  local lines = {}
  for _ = 1, count do
    lines[#lines + 1] = applyFormat(util.uuid(), mode)
  end
  state.set("uuidDisplay", table.concat(lines, "\n"))
  state.set("uuidInfo", "已生成 " .. count .. " 个 UUID v4 (格式: "
      .. (mode == "std" and "标准" or mode == "upper" and "大写" or mode == "nodash" and "无连字符" or "花括号") .. ")")
  state.set("hasResult", true)
end

function setMode(mode)
  state.set("fmtMode", mode)
  regenerateIfPossible()
end
