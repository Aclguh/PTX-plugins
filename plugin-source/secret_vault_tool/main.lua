-- secret_vault_tool main.lua
-- 生物认证隐私保险箱

local cachedSecret = ""

function _maskData(s)
  if s == nil then return "" end
  local len = string.len(s)
  if len == 0 then return "" end
  return string.rep("*", len)
end

function onInit()
  cachedSecret = ""
  state.set("isUnlocked", false)
  state.set("showLocked", true)
  state.set("vaultData", "")
  state.set("inputSecret", "")
  state.set("statusText", "保险箱受硬件级生物认证防护，请核验指纹/面容解锁")
  return nil
end

function unlockVault()
  biometrics.isAvailable(function(avail)
    if avail ~= true then
      dialog.toast("当前设备未启用或不支持生物认证")
      state.set("statusText", "设备无可用指纹/面容硬件")
      return nil
    end

    biometrics.authenticate("请验证指纹以解锁机密保险箱", function(res)
      if res ~= nil and res.ok == true then
        storage.get("user_secret_data", function(val)
          if val == nil or string.len(val) == 0 then
            cachedSecret = "（保险箱当前为空，可在下方录入并保存机密内容）"
          else
            cachedSecret = val
          end
          state.set("vaultData", cachedSecret)
          state.set("isUnlocked", true)
          state.set("showLocked", false)
          dialog.toast("核验成功，保险箱已打开")
          return nil
        end)
      else
        state.set("statusText", "身份核验未通过，已拒绝访问")
        dialog.toast("核验未通过")
      end
      return nil
    end)

    return nil
  end)
  return nil
end

function saveSecret()
  local s = state.get("inputSecret")
  if s == nil or string.len(s) == 0 then
    dialog.toast("输入内容不能为空")
    return nil
  end

  storage.set("user_secret_data", s)
  cachedSecret = s
  state.set("vaultData", s)
  state.set("inputSecret", "")
  dialog.toast("已安全保存至加密保险箱")
  return nil
end

function lockVault()
  cachedSecret = ""
  state.set("vaultData", "")
  state.set("isUnlocked", false)
  state.set("showLocked", true)
  state.set("statusText", "保险箱已加锁锁定")
  dialog.toast("保险箱已重新加锁")
  return nil
end

function copyVault()
  if string.len(cachedSecret) > 0 then
    clipboard.set(cachedSecret)
    dialog.toast("机密内容已复制到剪贴板")
  end
  return nil
end
