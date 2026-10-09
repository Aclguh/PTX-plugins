-- mock_data_tool — 模拟测试数据生成器
-- 纯算法生成姓名、手机号、合规身份证、邮箱、IP、银行卡，支持批量生成与格式转换

local SURNAMES = {
  "赵", "钱", "孙", "李", "周", "吴", "郑", "王", "冯", "陈",
  "褚", "卫", "蒋", "沈", "韩", "杨", "朱", "秦", "尤", "许",
  "何", "吕", "施", "张", "孔", "曹", "严", "华", "金", "魏"
}

local GIVEN_NAMES = {
  "伟", "芳", "娜", "秀英", "敏", "静", "丽", "强", "磊", "军",
  "洋", "勇", "艳", "杰", "娟", "涛", "明", "超", "秀兰", "霞",
  "平", "刚", "桂英", "玉兰", "文", "辉", "力", "明辉", "晨阳", "思远"
}

local AREA_CODES = {
  "110101", "120101", "310101", "440106", "510104", "330106", "320102", "420106", "610113", "370102"
}

local ID_WEIGHTS = { 7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2 }
local ID_CHECK_CODES = { "1", "0", "X", "9", "8", "7", "6", "5", "4", "3", "2" }

local PHONE_PREFIXES = { "138", "139", "150", "158", "186", "188", "177", "199", "135", "136" }
local EMAIL_DOMAINS = { "gmail.com", "qq.com", "163.com", "outlook.com", "foxmail.com", "corp.net" }
local BANK_PREFIXES = { "622202", "622848", "621700", "622588", "621226" }

local currentCount = 5
local currentFormat = "json" -- "json" | "sql" | "kv"

local function rndItem(t)
  return t[math.random(1, #t)]
end

local function padZero(num, len)
  local s = tostring(num)
  while string.len(s) < len do
    s = "0" .. s
  end
  return s
end

-- 生成符合 ISO 7064 Mod 11-2 的真实有效校验码 18 位身份证
function _generateIdCard()
  local area = rndItem(AREA_CODES)
  local year = tostring(math.random(1975, 2005))
  local month = padZero(math.random(1, 12), 2)
  local day = padZero(math.random(1, 28), 2)
  local seq = padZero(math.random(100, 999), 3)
  local prefix17 = area .. year .. month .. day .. seq

  local sum = 0
  for i = 1, 17 do
    local digit = tonumber(string.sub(prefix17, i, i)) or 0
    sum = sum + digit * ID_WEIGHTS[i]
  end
  local modVal = sum % 11
  local checkChar = ID_CHECK_CODES[modVal + 1]
  return prefix17 .. checkChar
end

-- 生成随机姓名
function _generateName()
  return rndItem(SURNAMES) .. rndItem(GIVEN_NAMES)
end

-- 生成手机号
function _generatePhone()
  local pre = rndItem(PHONE_PREFIXES)
  local tail = padZero(math.random(10000000, 99999999), 8)
  return pre .. tail
end

-- 生成邮箱
function _generateEmail()
  local chars = "abcdefghijklmnopqrstuvwxyz"
  local user = ""
  for i = 1, math.random(5, 8) do
    local idx = math.random(1, string.len(chars))
    user = user .. string.sub(chars, idx, idx)
  end
  user = user .. tostring(math.random(10, 99))
  return user .. "@" .. rndItem(EMAIL_DOMAINS)
end

-- 生成 IPv4 地址
function _generateIp()
  return tostring(math.random(10, 220)) .. "." ..
         tostring(math.random(1, 254)) .. "." ..
         tostring(math.random(1, 254)) .. "." ..
         tostring(math.random(1, 254))
end

-- 生成符合 Luhn 算法的 16 位银行卡号
function _generateBankCard()
  local pre = rndItem(BANK_PREFIXES)
  local mid = padZero(math.random(100000000, 999999999), 9)
  local pre15 = pre .. mid
  local sum = 0
  for i = 1, 15 do
    local digit = tonumber(string.sub(pre15, 16 - i, 16 - i)) or 0
    if i % 2 == 1 then
      digit = digit * 2
      if digit > 9 then
        digit = digit - 9
      end
    end
    sum = sum + digit
  end
  local check = (10 - (sum % 10)) % 10
  return pre15 .. tostring(check)
end

-- 单条数据实体
function _generateOneRecord(idVal)
  return {
    id = idVal,
    name = _generateName(),
    phone = _generatePhone(),
    idCard = _generateIdCard(),
    email = _generateEmail(),
    ip = _generateIp(),
    bankCard = _generateBankCard()
  }
end

-- 导出格式化
function _formatRecords(records, fmt)
  if fmt == "json" then
    return json.encode(records)
  end
  if fmt == "sql" then
    local lines = {}
    for i = 1, #records do
      local r = records[i]
      local sql = "INSERT INTO `mock_users` (`id`, `name`, `phone`, `id_card`, `email`, `ip`, `bank_card`) VALUES (" ..
        r.id .. ", '" .. r.name .. "', '" .. r.phone .. "', '" .. r.idCard .. "', '" .. r.email .. "', '" .. r.ip .. "', '" .. r.bankCard .. "');"
      lines[#lines + 1] = sql
    end
    return table.concat(lines, "\n")
  end
  -- kv
  local lines = {}
  for i = 1, #records do
    local r = records[i]
    lines[#lines + 1] = "【序号 " .. r.id .. "】"
    lines[#lines + 1] = "姓名: " .. r.name
    lines[#lines + 1] = "手机号: " .. r.phone
    lines[#lines + 1] = "身份证: " .. r.idCard
    lines[#lines + 1] = "电子邮箱: " .. r.email
    lines[#lines + 1] = "IP地址: " .. r.ip
    lines[#lines + 1] = "银行卡: " .. r.bankCard
    lines[#lines + 1] = "----------------------------------------"
  end
  return table.concat(lines, "\n")
end

-- ---------------- UI 事件 ----------------
function onInit()
  math.randomseed(util.timestampMs() % 2147483647)
  state.set("countLabel", "数量: 5 条")
  state.set("formatLabel", "格式: JSON 数组")
  state.set("resultText", "")
  state.set("hasResult", false)
  state.set("statusMsg", "点击「立即生成」批量产出测试数据")
end

function setCount1()
  currentCount = 1
  state.set("countLabel", "数量: 1 条")
end

function setCount5()
  currentCount = 5
  state.set("countLabel", "数量: 5 条")
end

function setCount10()
  currentCount = 10
  state.set("countLabel", "数量: 10 条")
end

function setCount20()
  currentCount = 20
  state.set("countLabel", "数量: 20 条")
end

function setFormatJson()
  currentFormat = "json"
  state.set("formatLabel", "格式: JSON 数组")
end

function setFormatSql()
  currentFormat = "sql"
  state.set("formatLabel", "格式: SQL INSERT 语句")
end

function setFormatKv()
  currentFormat = "kv"
  state.set("formatLabel", "格式: 键值纯文本")
end

function generateData()
  local list = {}
  for i = 1, currentCount do
    list[i] = _generateOneRecord(i)
  end
  local outStr = _formatRecords(list, currentFormat)
  state.set("resultText", outStr)
  state.set("hasResult", true)
  state.set("statusMsg", "已生成 " .. currentCount .. " 条模拟数据 (" .. currentFormat .. ")")
  dialog.toast("生成成功")
end

function copyResult()
  local text = state.get("resultText") or ""
  if string.len(text) == 0 then
    dialog.toast("暂无数据可复制")
    return nil
  end
  clipboard.set(text)
  dialog.toast("已复制到剪贴板")
end
