-- nfc_toolbox main.lua
-- NFC 标签读写多功能箱

function _formatRecordSummary(type, payload)
  local t = type or "TEXT"
  local p = payload or ""
  return string.format("[%s] %s", t, p)
end

function onInit()
  state.set("nfcStatus", "空闲中，准备就绪")
  state.set("tagPayload", "暂无读取内容")
  state.set("tagType", "未感应")
  state.set("hasTag", false)
  state.set("inputPayload", "https://github.com/Aclguh/PTX-plugins")
  return nil
end

function readNdefTag()
  nfc.isAvailable(function(avail)
    if avail ~= true then
      dialog.toast("NFC 硬件不可用或未开启")
      state.set("nfcStatus", "NFC 不可用，请在系统设置中启用 NFC")
      return nil
    end

    state.set("nfcStatus", "正在等待贴近 NFC 标签卡片...")
    nfc.readNdef(function(res)
      if res ~= nil and res.ok == true then
        local records = res.records or {}
        if #records > 0 then
          local first = records[1]
          local p = first.payload or "空负载"
          local t = first.type or "NDEF 标准记录"
          state.set("tagPayload", tostring(p))
          state.set("tagType", tostring(t))
          state.set("hasTag", true)
          state.set("nfcStatus", "成功读取 1 个 NDEF 记录")
          dialog.toast("NFC 标签读取成功")
        else
          state.set("nfcStatus", "读取成功，但未包含 NDEF 记录")
        end
      else
        local err = (res and res.error) or "感应超时或未识别"
        state.set("nfcStatus", "读取失败: " .. tostring(err))
      end
      return nil
    end)

    return nil
  end)
  return nil
end

function writeNdefTag()
  local payload = state.get("inputPayload")
  if payload == nil or string.len(payload) == 0 then
    dialog.toast("请输入待写入的内容")
    return nil
  end

  state.set("nfcStatus", "正在等待贴近空白标签进行烧录...")
  local records = {
    {
      type = "text",
      payload = payload
    }
  }

  nfc.writeNdef(records, function(res)
    if res ~= nil and res.ok == true then
      state.set("nfcStatus", "写入成功！数据已持久化至标签")
      dialog.toast("NFC 标签写入完成")
    else
      local err = (res and res.error) or "写入超时或卡片只读"
      state.set("nfcStatus", "写入未完成: " .. tostring(err))
    end
    return nil
  end)

  return nil
end

function copyTagContent()
  local content = state.get("tagPayload")
  if content ~= nil and string.len(content) > 0 then
    clipboard.set(content)
    dialog.toast("已复制标签内容到剪贴板")
  end
  return nil
end

function clearData()
  state.set("tagPayload", "暂无读取内容")
  state.set("tagType", "未感应")
  state.set("hasTag", false)
  state.set("nfcStatus", "数据已清空")
  dialog.toast("记录已清空")
  return nil
end
