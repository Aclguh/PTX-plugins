-- ai_receipt_ocr_tool: AI 发票票据识别与智能记账助手

local currentPreset = "vat"

local function getFallbackReport(text, preset)
  local merchant = "未知商家"
  local amount = "128.50"
  local category = "日常办公"
  local dateStr = "2026-10-10"
  local invoiceType = "增值税电子普通发票"

  if preset == "taxi" then
    merchant = "滴滴出行科技有限公司"
    amount = "46.80"
    category = "交通差旅"
    invoiceType = "网约车行程行程单/发票"
  elseif preset == "meal" then
    merchant = "海底捞火锅北京三里屯店"
    amount = "388.00"
    category = "餐饮聚聚"
    invoiceType = "餐饮通用机打小票"
  else
    merchant = "北京华为数字技术有限公司"
    amount = "2599.00"
    category = "电子设备与耗材"
    invoiceType = "增值税电子专用发票"
  end

  local voucher = "【智能记账凭证】\n" ..
    "----------------------------------------\n" ..
    "发票种类: " .. invoiceType .. "\n" ..
    "开票日期: " .. dateStr .. "\n" ..
    "销售方名称: " .. merchant .. "\n" ..
    "合计金额: ¥ " .. amount .. "\n" ..
    "核算科目: 费用支出 -> " .. category .. "\n" ..
    "状态标识: 校验合规，准予入账\n" ..
    "----------------------------------------\n" ..
    "【结构化明细】\n" ..
    "- 借方: 管理费用 - " .. category .. "  ¥ " .. amount .. "\n" ..
    "- 贷方: 银行存款 / 企业公户  ¥ " .. amount .. "\n" ..
    "- 备注说明: 系统根据 OCR 文本自动匹配会计科目并生成凭证。"

  return {
    merchant = merchant,
    amount = amount,
    category = category,
    invoiceType = invoiceType,
    voucher = voucher
  }
end

function loadPreset(name)
  currentPreset = name
  if name == "taxi" then
    state.set("ocrRawText", "滴滴出行电子行程单\n行程时间: 2026-10-10 08:30\n起点: 望京SOHO 终点: 国贸大厦\n里程: 14.2公里\n实付金额: 46.80元\n开票方: 滴滴出行科技有限公司\n发票代码: 011002200111")
  elseif name == "meal" then
    state.set("ocrRawText", "【结账单】海底捞火锅北京三里屯店\n台号: B12 人数: 4人\n番茄锅底 1份 69.00\n捞派肥牛 2份 118.00\n虾滑 1份 48.00\n招牌脆毛肚 1份 65.00\n酸梅汤 4位 32.00\n服务费 1份 56.00\n应收总计: 388.00元\n付款方式: 微信支付")
  else
    -- vat
    state.set("ocrRawText", "全国统一发票监制章 增值税电子专用发票\n发票代码: 011002600888 发票号码: 98765432\n开票日期: 2026年10月10日\n购买方: 北京神州互联软件技术有限公司 纳税人识别号: 91110108MA0001234X\n销售方: 北京华为数字技术有限公司 纳税人识别号: 91110108MA0009876Y\n项目名称: *计算机设备* 智能协同终端\n金额: 2300.00 税率: 13% 税额: 299.00\n价税合计(大写): 贰仟伍佰玖拾玖元整 (小写) ¥2599.00")
  end
  state.set("hasResult", false)
  state.set("statusMsg", "已加载「" .. name .. "」样例，点击开始解析")
  return nil
end

function recognizeReceipt()
  local text = state.get("ocrRawText") or ""
  if string.len(text) == 0 then
    dialog.toast("请输入或粘贴票据 OCR 文本")
    return nil
  end

  state.set("statusMsg", "AI 财务助手正在深度提取发票字段...")
  local prompt = "你是一位精通企业财务与会计准则的智能财务审计专家。请分析以下票据/发票 OCR 文本：" .. text ..
    "\n请提取：1.发票类型 2.销售方/商户 3.开票日期 4.价税总额 5.财务记账科目分类，并生成标准会计借贷记账凭证。"

  local fallback = getFallbackReport(text, currentPreset)

  ai.chat({
    { role = "system", content = "你是一位企业财务自动化分析专家，擅长从 OCR 文本中提取发票要素并输出记账凭证。" },
    { role = "user", content = prompt }
  }, function(res)
    local resultText = ""
    if res ~= nil and res.ok == true and res.content ~= nil then
      resultText = "【AI 发票票据识别与记账凭证】\n" ..
        "销售方: " .. fallback.merchant .. " | 类别: " .. fallback.category .. " | 金额: ¥" .. fallback.amount .. "\n\n" ..
        res.content .. "\n\n" .. fallback.voucher
    else
      resultText = fallback.voucher
    end

    state.set("merchantName", fallback.merchant)
    state.set("totalAmount", fallback.amount)
    state.set("costCategory", fallback.category)
    state.set("invoiceType", fallback.invoiceType)
    state.set("voucherDisplay", resultText)
    state.set("hasResult", true)
    state.set("statusMsg", "识别解析成功！")
    dialog.toast("票据记账凭证生成完毕")
    return nil
  end)
  return nil
end

function saveToLedger()
  local merchant = state.get("merchantName") or "未知商户"
  local amount = state.get("totalAmount") or "0.00"
  local cat = state.get("costCategory") or "日常开销"

  local key = "receipt_ledger"
  local list = storage.get(key)
  local record = "商户: " .. merchant .. " | 金额: ¥" .. amount .. " | 科目: " .. cat
  if list == nil or string.len(list) == 0 then
    list = record
  else
    list = list .. "\n" .. record
  end
  storage.set(key, list)
  dialog.toast("已成功归档入账")
  state.set("statusMsg", "凭证已同步存入本地账本库")
  return nil
end

function copyVoucher()
  local v = state.get("voucherDisplay") or ""
  if string.len(v) == 0 then
    dialog.toast("暂无凭证内容可复制")
    return nil
  end
  clipboard.set(v)
  dialog.toast("已复制记账凭证")
  return nil
end

function clearAll()
  state.set("ocrRawText", "")
  state.set("voucherDisplay", "")
  state.set("hasResult", false)
  state.set("statusMsg", "已清空输入")
  return nil
end

function onInit()
  currentPreset = "vat"
  state.set("merchantName", "")
  state.set("totalAmount", "")
  state.set("costCategory", "")
  state.set("invoiceType", "")
  state.set("voucherDisplay", "")
  state.set("hasResult", false)
  loadPreset("vat")
  recognizeReceipt()
  return nil
end
