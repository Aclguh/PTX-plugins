local KINSHIP_DICT = {
  ["f"] = "爸爸 (父亲)",
  ["m"] = "妈妈 (母亲)",
  ["ob"] = "哥哥",
  ["lb"] = "弟弟",
  ["os"] = "姐姐",
  ["ls"] = "妹妹",
  ["s"] = "儿子",
  ["d"] = "女儿",
  ["h"] = "丈夫 (老公)",
  ["w"] = "妻子 (老婆)",

  ["f,f"] = "爷爷 (祖父)",
  ["f,m"] = "奶奶 (祖母)",
  ["f,ob"] = "伯父 (大伯)",
  ["f,lb"] = "叔叔 (叔父)",
  ["f,os"] = "姑姑 (大姑/姑妈)",
  ["f,ls"] = "姑姑 (小姑)",
  ["f,s"] = "兄弟",
  ["f,d"] = "姐妹",
  ["f,w"] = "妈妈",

  ["m,f"] = "外公 (姥爷)",
  ["m,m"] = "外婆 (姥姥)",
  ["m,ob"] = "舅舅 (大舅)",
  ["m,lb"] = "舅舅 (小舅)",
  ["m,os"] = "姨妈 (大姨)",
  ["m,ls"] = "阿姨 (小姨)",
  ["m,s"] = "兄弟",
  ["m,d"] = "姐妹",
  ["m,h"] = "爸爸",

  ["ob,w"] = "嫂子",
  ["lb,w"] = "弟妹 (弟媳)",
  ["os,h"] = "姐夫",
  ["ls,h"] = "妹夫",
  ["ob,s"] = "侄子",
  ["ob,d"] = "侄女",
  ["lb,s"] = "侄子",
  ["lb,d"] = "侄女",
  ["os,s"] = "外甥",
  ["os,d"] = "外甥女",
  ["ls,s"] = "外甥",
  ["ls,d"] = "外甥女",

  ["s,w"] = "儿媳",
  ["d,h"] = "女婿",
  ["s,s"] = "孙子",
  ["s,d"] = "孙女",
  ["d,s"] = "外孙",
  ["d,d"] = "外孙女",

  ["h,f"] = "公公",
  ["h,m"] = "婆婆",
  ["h,ob"] = "大伯子",
  ["h,lb"] = "小叔子",
  ["h,os"] = "大姑子",
  ["h,ls"] = "小姑子",

  ["w,f"] = "岳父 (老丈人)",
  ["w,m"] = "岳母 (丈母娘)",
  ["w,ob"] = "大舅子",
  ["w,lb"] = "小舅子",
  ["w,os"] = "大姨子",
  ["w,ls"] = "小姨子",

  ["f,f,f"] = "曾祖父 (太爷爷)",
  ["f,f,m"] = "曾祖母 (太奶奶)",
  ["m,f,f"] = "外曾祖父 (太姥爷)",
  ["m,f,m"] = "外曾祖母 (太姥姥)",
  ["f,m,f"] = "曾外祖父",
  ["f,m,m"] = "曾外祖母",
  ["m,m,f"] = "外曾外祖父",
  ["m,m,m"] = "外曾外祖母",

  ["f,ob,w"] = "伯母 (大娘/大妈)",
  ["f,lb,w"] = "婶婶 (婶娘)",
  ["f,ob,s"] = "堂兄 / 堂弟",
  ["f,ob,d"] = "堂姐 / 堂妹",
  ["f,lb,s"] = "堂兄 / 堂弟",
  ["f,lb,d"] = "堂姐 / 堂妹",

  ["f,os,h"] = "姑父 (大姑父)",
  ["f,ls,h"] = "姑父 (小姑父)",
  ["f,os,s"] = "表兄 / 表弟 (姑表兄弟)",
  ["f,os,d"] = "表姐 / 表妹 (姑表姐妹)",
  ["f,ls,s"] = "表兄 / 表弟",
  ["f,ls,d"] = "表姐 / 表妹",

  ["m,ob,w"] = "舅妈 (妗子)",
  ["m,lb,w"] = "舅妈",
  ["m,ob,s"] = "表兄 / 表弟 (舅表兄弟)",
  ["m,ob,d"] = "表姐 / 表妹",
  ["m,lb,s"] = "表兄 / 表弟",
  ["m,lb,d"] = "表姐 / 表妹",

  ["m,os,h"] = "姨父 (大姨夫)",
  ["m,ls,h"] = "姨父 (小姨夫)",
  ["m,os,s"] = "表兄 / 表弟 (姨表兄弟)",
  ["m,os,d"] = "表姐 / 表妹",
  ["m,ls,s"] = "表兄 / 表弟",
  ["m,ls,d"] = "表姐 / 表妹",

  ["s,s,s"] = "曾孙",
  ["s,s,d"] = "曾孙女",
  ["d,s,s"] = "曾外孙",
  ["d,s,d"] = "曾外孙女",

  ["f,ob,s,s"] = "堂侄",
  ["f,ob,s,d"] = "堂侄女",
  ["f,lb,s,s"] = "堂侄",
  ["f,lb,s,d"] = "堂侄女",
  ["m,ob,s,s"] = "表侄",
  ["m,ob,s,d"] = "表侄女"
}

local REVERSE_MAP = {
  ["f,f"] = { ["male"] = "孙子", ["female"] = "孙女" },
  ["f,m"] = { ["male"] = "孙子", ["female"] = "孙女" },
  ["m,f"] = { ["male"] = "外孙", ["female"] = "外孙女" },
  ["m,m"] = { ["male"] = "外孙", ["female"] = "外孙女" },
  ["f,ob"] = { ["male"] = "侄子", ["female"] = "侄女" },
  ["f,lb"] = { ["male"] = "侄子", ["female"] = "侄女" },
  ["f,os"] = { ["male"] = "内侄 (外甥)", ["female"] = "内侄女 (外甥女)" },
  ["f,ls"] = { ["male"] = "内侄 (外甥)", ["female"] = "内侄女 (外甥女)" },
  ["m,ob"] = { ["male"] = "外甥", ["female"] = "外甥女" },
  ["m,lb"] = { ["male"] = "外甥", ["female"] = "外甥女" },
  ["m,os"] = { ["male"] = "姨甥 (外甥)", ["female"] = "姨甥女 (外甥女)" },
  ["m,ls"] = { ["male"] = "姨甥 (外甥)", ["female"] = "姨甥女 (外甥女)" },
  ["w,f"] = { ["male"] = "女婿", ["female"] = "儿媳" },
  ["w,m"] = { ["male"] = "女婿", ["female"] = "儿媳" },
  ["h,f"] = { ["male"] = "女婿", ["female"] = "儿媳" },
  ["h,m"] = { ["male"] = "女婿", ["female"] = "儿媳" },
  ["s,w"] = { ["male"] = "公公", ["female"] = "婆婆" },
  ["d,h"] = { ["male"] = "岳父", ["female"] = "岳母" }
}

local TOKEN_TO_CODE = {
  ["父"] = "f",
  ["爸爸"] = "f",
  ["父亲"] = "f",
  ["爹"] = "f",
  ["母"] = "m",
  ["妈妈"] = "m",
  ["母亲"] = "m",
  ["娘"] = "m",
  ["兄"] = "ob",
  ["哥哥"] = "ob",
  ["弟"] = "lb",
  ["弟弟"] = "lb",
  ["姐"] = "os",
  ["姐姐"] = "os",
  ["妹"] = "ls",
  ["妹妹"] = "ls",
  ["子"] = "s",
  ["儿"] = "s",
  ["儿子"] = "s",
  ["女"] = "d",
  ["女儿"] = "d",
  ["夫"] = "h",
  ["丈夫"] = "h",
  ["老公"] = "h",
  ["妻"] = "w",
  ["妻子"] = "w",
  ["老婆"] = "w"
}

local CODE_TO_NAME = {
  ["f"] = "爸爸",
  ["m"] = "妈妈",
  ["ob"] = "哥哥",
  ["lb"] = "弟弟",
  ["os"] = "姐姐",
  ["ls"] = "妹妹",
  ["s"] = "儿子",
  ["d"] = "女儿",
  ["h"] = "丈夫",
  ["w"] = "妻子"
}

local currentChain = {}

function _parse_text_to_codes(text)
  local codes = {}
  local len = string.len(text)
  local i = 1
  while i <= len do
    local matched = false
    for _, step in ipairs({ 2, 1 }) do
      if i + step - 1 <= len then
        local sub = string.sub(text, i, i + step - 1)
        local c = TOKEN_TO_CODE[sub]
        if c ~= nil then
          codes[#codes + 1] = c
          i = i + step
          matched = true
          break
        end
      end
    end
    if not matched then
      local singleChar = string.sub(text, i, i)
      if singleChar == "的" or singleChar == " " or singleChar == "我" then
        i = i + 1
      else
        local c = TOKEN_TO_CODE[singleChar]
        if c ~= nil then
          codes[#codes + 1] = c
          i = i + 1
        else
          i = i + 1
        end
      end
    end
  end
  return codes
end

function _calculate_kinship(codes, gender)
  if #codes == 0 then
    return "自己", "自己"
  end

  local key = table.concat(codes, ",")
  local title = KINSHIP_DICT[key]
  if title == nil then
    local reduced = {}
    for idx = 1, #codes do
      reduced[#reduced + 1] = codes[idx]
    end
    key = table.concat(reduced, ",")
    title = KINSHIP_DICT[key]
  end

  if title == nil then
    title = "关系较远或需细分长幼 (暂未收录称谓)"
  end

  local revObj = REVERSE_MAP[key]
  local revTitle = ""
  if revObj ~= nil then
    local g = gender or "male"
    revTitle = "TA 称呼我: " .. (revObj[g] or "亲戚")
  else
    revTitle = "TA 称呼我: 晚辈 / 同辈 / 亲戚"
  end

  return title, revTitle
end

local function refresh_display()
  local chainNames = {}
  for i = 1, #currentChain do
    chainNames[#chainNames + 1] = CODE_TO_NAME[currentChain[i]]
  end

  local chainStr = ""
  if #chainNames > 0 then
    chainStr = "我的 " .. table.concat(chainNames, " 的 ")
  else
    chainStr = "我"
  end

  local gender = state.get("myGender") or "male"
  local title, rev = _calculate_kinship(currentChain, gender)

  state.set("chainText", chainStr)
  state.set("resultTitle", title)
  state.set("resultReverse", rev)
  state.set("hasResult", true)
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

local function add_code(c)
  if #currentChain >= 8 then
    dialog.toast("关系链过长，最多支持 8 级关系")
    return nil
  end
  currentChain[#currentChain + 1] = c
  refresh_display()
  return nil
end

function addFather() return add_code("f") end
function addMother() return add_code("m") end
function addElderBrother() return add_code("ob") end
function addYoungerBrother() return add_code("lb") end
function addElderSister() return add_code("os") end
function addYoungerSister() return add_code("ls") end
function addSon() return add_code("s") end
function addDaughter() return add_code("d") end
function addHusband() return add_code("h") end
function addWife() return add_code("w") end

function backspace()
  if #currentChain > 0 then
    currentChain[#currentChain] = nil
  end
  refresh_display()
  return nil
end

function clearAll()
  currentChain = {}
  state.set("inputText", "")
  refresh_display()
  return nil
end

function queryFromInput()
  local text = state.get("inputText") or ""
  if text == "" then
    clearAll()
    return nil
  end
  local codes = _parse_text_to_codes(text)
  if #codes == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "未能识别到有效的亲属称谓词，例如：爸爸的哥哥")
    return nil
  end
  currentChain = codes
  refresh_display()
  return nil
end

function toggleGender()
  local g = state.get("myGender") or "male"
  if g == "male" then
    state.set("myGender", "female")
    state.set("genderText", "我的性别: 女性")
  else
    state.set("myGender", "male")
    state.set("genderText", "我的性别: 男性")
  end
  refresh_display()
  return nil
end

function copyTitle()
  local t = state.get("resultTitle") or ""
  if t ~= "" then
    clipboard.set(t)
    dialog.toast("已复制称谓")
  end
  return nil
end

function onInit()
  currentChain = { "f", "ob" }
  state.set("myGender", "male")
  state.set("genderText", "我的性别: 男性")
  state.set("inputText", "")
  state.set("hasError", false)
  state.set("errorMsg", "")
  refresh_display()
  return nil
end
