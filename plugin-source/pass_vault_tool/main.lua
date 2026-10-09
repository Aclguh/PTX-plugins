-- pass_vault_tool — 密码与安全凭证备忘本
-- 生物认证解锁 + 独立 SQLite 存储敏感账号口令

local accounts = {}
local isUnlocked = false
local showPlainPassword = false

function _maskPassword(pwd)
  if pwd == nil then return "" end
  local len = string.len(pwd)
  if len == 0 then return "" end
  return string.rep("•", len)
end

function _calcPasswordEntropy(pwd)
  if pwd == nil then return 0 end
  local len = string.len(pwd)
  if len == 0 then return 0 end

  local pool = 0
  local hasLower = false
  local hasUpper = false
  local hasDigit = false
  local hasSymbol = false

  for i = 1, len do
    local b = string.byte(pwd, i)
    if b >= 97 and b <= 122 then
      hasLower = true
    elseif b >= 65 and b <= 90 then
      hasUpper = true
    elseif b >= 48 and b <= 57 then
      hasDigit = true
    else
      hasSymbol = true
    end
  end

  if hasLower then pool = pool + 26 end
  if hasUpper then pool = pool + 26 end
  if hasDigit then pool = pool + 10 end
  if hasSymbol then pool = pool + 32 end
  if pool == 0 then pool = 10 end

  -- entropy = len * log2(pool)
  local log2Pool = math.log(pool) / math.log(2)
  return math.floor(len * log2Pool + 0.5)
end

local function renderAccountsList()
  if not isUnlocked then
    state.set("accountsText", "【保险箱已锁定】请通过生物认证后查看")
    state.set("accountCount", "已锁定")
    return nil
  end

  if #accounts == 0 then
    state.set("accountsText", "保险箱暂无凭证，请在下方录入首个账号")
    state.set("accountCount", "0 个账号")
    return nil
  end

  local lines = {}
  for i = 1, #accounts do
    local a = accounts[i]
    local pwd = a.password or "SampleSecretToken"
    local pwdDisplay = _maskPassword(pwd)
    if showPlainPassword then
      pwdDisplay = pwd
    end
    local sName = a.service or a.category or "默认服务"
    local uName = a.username or "user"
    lines[#lines + 1] = "#" .. tostring(a.id or i) .. " 服务: " .. sName
    lines[#lines + 1] = "   账号: " .. uName
    lines[#lines + 1] = "   密码: " .. pwdDisplay .. " (熵值: " .. _calcPasswordEntropy(pwd) .. " bits)"
    if a.note ~= nil and string.len(a.note) > 0 then
      lines[#lines + 1] = "   备注: " .. a.note
    end
    lines[#lines + 1] = "----------------------------------------"
  end

  state.set("accountsText", table.concat(lines, "\n"))
  state.set("accountCount", #accounts .. " 个凭证")
end

local function reloadAccounts()
  db.query("SELECT * FROM vault_accounts ORDER BY id ASC;", function(res)
    if res ~= nil and res.ok == true and res.rows ~= nil then
      accounts = res.rows
    else
      accounts = {}
    end
    renderAccountsList()
    return nil
  end)
end

-- ---------------- UI 事件 ----------------
function onInit()
  accounts = {}
  isUnlocked = false
  showPlainPassword = false

  state.set("isUnlocked", false)
  state.set("isLocked", true)
  state.set("accountsText", "【受生物认证保护】请验证身份后查阅")
  state.set("accountCount", "已锁定")
  state.set("inputService", "")
  state.set("inputUser", "")
  state.set("inputPwd", "")
  state.set("inputNote", "")
  state.set("maskBtnText", "显示明文密码")
  state.set("statusMsg", "点击「指纹/面容解锁」查阅敏感凭证")

  db.execute("CREATE TABLE IF NOT EXISTS vault_accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, service TEXT, username TEXT, password TEXT, note TEXT);", function(r1)
    db.query("SELECT count(*) as c FROM vault_accounts;", function(r2)
      local c = 0
      if r2 ~= nil and r2.rows ~= nil and #r2.rows > 0 then
        c = tonumber(r2.rows[1].c) or 0
      end
      if c == 0 then
        db.execute("INSERT INTO vault_accounts (service, username, password, note) VALUES ('GitHub 个人令牌', 'developer', 'ghp_SampleSecretToken9876', '主仓库私有只读'), ('家庭 Wi-Fi 路由器', 'admin', 'RootAdmin#2026', '后台管理 192.168.1.1');", function(r3)
          return nil
        end)
      end
      return nil
    end)
    return nil
  end)
end

function onDispose()
  lockVault()
end

function unlockWithBiometrics()
  biometrics.isAvailable(function(avail)
    if not avail then
      dialog.toast("当前设备未配置或不支持生物识别")
      return nil
    end

    biometrics.authenticate("请验证指纹/面容以查阅密码库", function(res)
      if res ~= nil and res.ok == true then
        isUnlocked = true
        state.set("isUnlocked", true)
        state.set("isLocked", false)
        state.set("statusMsg", "身份认证成功，保险箱已打开")
        dialog.toast("认证通过")
        reloadAccounts()
      else
        state.set("statusMsg", "生物认证未通过")
        dialog.toast("认证未通过")
      end
      return nil
    end)
    return nil
  end)
end

function lockVault()
  isUnlocked = false
  showPlainPassword = false
  state.set("isUnlocked", false)
  state.set("isLocked", true)
  state.set("statusMsg", "保险箱已安全加锁")
  state.set("maskBtnText", "显示明文密码")
  renderAccountsList()
  dialog.toast("保险箱已锁定")
end

function toggleMask()
  showPlainPassword = not showPlainPassword
  if showPlainPassword then
    state.set("maskBtnText", "脱敏遮蔽密码")
  else
    state.set("maskBtnText", "显示明文密码")
  end
  renderAccountsList()
end

function addAccount()
  if not isUnlocked then
    dialog.toast("请先解锁保险箱")
    return nil
  end

  local s = state.get("inputService") or ""
  local u = state.get("inputUser") or ""
  local p = state.get("inputPwd") or ""
  local n = state.get("inputNote") or ""

  if string.len(s) == 0 or string.len(p) == 0 then
    dialog.toast("服务名称与密码不能为空")
    return nil
  end

  db.execute("INSERT INTO vault_accounts (service, username, password, note) VALUES ('" .. s .. "', '" .. u .. "', '" .. p .. "', '" .. n .. "');", function(r)
    dialog.toast("凭证保存成功")
    state.set("inputService", "")
    state.set("inputUser", "")
    state.set("inputPwd", "")
    state.set("inputNote", "")
    reloadAccounts()
    return nil
  end)
end

function copyVaultList()
  local txt = state.get("accountsText") or ""
  if not isUnlocked then
    dialog.toast("未解锁状态禁止导出复制")
    return nil
  end
  clipboard.set(txt)
  dialog.toast("已复制凭证清单")
end
