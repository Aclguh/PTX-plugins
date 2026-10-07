-- git_commit_tool — 规范化 Git Commit 生成器

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

function _build_commit_msg(cType, scope, subject, body, isBreaking, breakingDesc, issue)
  local t = trim(cType or "feat")
  local sc = trim(scope or "")
  local sb = trim(subject or "")
  local bd = trim(body or "")
  local bkDesc = trim(breakingDesc or "")
  local isBk = (isBreaking == true or isBreaking == "true" or bkDesc ~= "")
  local iss = trim(issue or "")

  if sb == "" then
    return nil, "提交主题 (Subject) 不能为空"
  end

  local header = t
  if sc ~= "" then
    header = header .. "(" .. sc .. ")"
  end
  if isBk then
    header = header .. "!"
  end
  header = header .. ": " .. sb

  local sections = { header }

  if bd ~= "" then
    sections[#sections + 1] = bd
  end

  if isBk then
    if bkDesc ~= "" then
      sections[#sections + 1] = "BREAKING CHANGE: " .. bkDesc
    else
      sections[#sections + 1] = "BREAKING CHANGE: " .. sb
    end
  end

  if iss ~= "" then
    sections[#sections + 1] = iss
  end

  local fullMsg = table.concat(sections, "\n\n")

  local escaped = ""
  for i = 1, strLen(fullMsg) do
    local c = string.sub(fullMsg, i, i)
    if c == '"' then
      escaped = escaped .. '\\"'
    elseif c == "$" then
      escaped = escaped .. "\\$"
    elseif c == "`" then
      escaped = escaped .. "\\`"
    else
      escaped = escaped .. c
    end
  end

  local gitCmd = 'git commit -m "' .. escaped .. '"'

  return {
    header = header,
    fullMsg = fullMsg,
    gitCmd = gitCmd
  }, nil
end

function generate()
  local cType = state.get("commitType") or "feat"
  local scope = state.get("commitScope") or ""
  local subject = state.get("commitSubject") or ""
  local body = state.get("commitBody") or ""
  local isBk = state.get("isBreaking") or false
  local bkDesc = state.get("breakingDesc") or ""
  local issue = state.get("commitIssue") or ""

  local res, err = _build_commit_msg(cType, scope, subject, body, isBk, bkDesc, issue)
  if res == nil then
    state.set("hasError", true)
    state.set("errorMsg", err or "生成失败")
    state.set("hasResult", false)
    return nil
  end

  state.set("resHeader", res.header)
  state.set("resFullMsg", res.fullMsg)
  state.set("resGitCmd", res.gitCmd)
  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function setType(t)
  state.set("commitType", t)
  generate()
  return nil
end

function toggleBreaking()
  local cur = state.get("isBreaking") or false
  state.set("isBreaking", not cur)
  generate()
  return nil
end

function copyMsg()
  local msg = state.get("resFullMsg") or ""
  if msg ~= "" and clipboard and clipboard.set then
    clipboard.set(msg)
  end
  if dialog and dialog.toast then
    dialog.toast("已复制 Commit 信息")
  end
  return nil
end

function copyCmd()
  local cmd = state.get("resGitCmd") or ""
  if cmd ~= "" and clipboard and clipboard.set then
    clipboard.set(cmd)
  end
  if dialog and dialog.toast then
    dialog.toast("已复制 git commit 完整命令")
  end
  return nil
end

function onInit()
  state.set("commitType", "feat")
  state.set("commitScope", "network")
  state.set("commitSubject", "添加 CIDR 与子网掩码计算器")
  state.set("commitBody", "支持输入 IP/掩码计算网络地址、广播地址与可用主机范围。")
  state.set("breakingDesc", "")
  state.set("commitIssue", "Closes #102")
  state.set("isBreaking", false)
  state.set("resHeader", "")
  state.set("resFullMsg", "")
  state.set("resGitCmd", "")
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  generate()
  return nil
end
