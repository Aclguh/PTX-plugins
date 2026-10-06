local function is_cjk_punct(cp)
  if cp >= 12288 and cp <= 12351 then
    return true
  end
  if cp >= 65281 and cp <= 65312 then
    return true
  end
  if cp >= 65339 and cp <= 65344 then
    return true
  end
  if cp >= 65371 and cp <= 65374 then
    return true
  end
  if cp == 8220 or cp == 8221 or cp == 8216 or cp == 8217 or cp == 8212 or cp == 8230 then
    return true
  end
  return false
end

local function is_cjk(cp)
  if is_cjk_punct(cp) then
    return false
  end
  if cp >= 19968 and cp <= 40959 then
    return true
  end
  if cp >= 13312 and cp <= 19903 then
    return true
  end
  if cp >= 131072 and cp <= 196607 then
    return true
  end
  if cp >= 12352 and cp <= 12543 then
    return true
  end
  if cp >= 44032 and cp <= 55215 then
    return true
  end
  if cp >= 11904 and cp <= 12255 then
    return true
  end
  if cp >= 63744 and cp <= 64255 then
    return true
  end
  return false
end

local function is_alphanumeric(cp)
  if cp >= 65 and cp <= 90 then
    return true
  end
  if cp >= 97 and cp <= 122 then
    return true
  end
  if cp >= 48 and cp <= 57 then
    return true
  end
  return false
end

local function is_digit(cp)
  return cp >= 48 and cp <= 57
end

local function is_whitespace(cp)
  return cp == 32 or cp == 9 or cp == 10 or cp == 13
end

local function parse_tokens(s)
  local tokens = {}
  local len = string.len(s)
  local i = 1
  while i <= len do
    local b1 = string.byte(s, i)
    if b1 == nil then
      break
    end
    local ch = string.sub(s, i, i)
    local cp = b1
    local step = 1

    if b1 < 128 then
      step = 1
      cp = b1
    elseif b1 >= 192 and b1 <= 223 then
      if i + 1 <= len then
        local b2 = string.byte(s, i + 1)
        cp = ((b1 & 31) << 6) | (b2 & 63)
        ch = string.sub(s, i, i + 1)
        step = 2
      end
    elseif b1 >= 224 and b1 <= 239 then
      if i + 2 <= len then
        local b2 = string.byte(s, i + 1)
        local b3 = string.byte(s, i + 2)
        cp = ((b1 & 15) << 12) | ((b2 & 63) << 6) | (b3 & 63)
        ch = string.sub(s, i, i + 2)
        step = 3
      end
    elseif b1 >= 240 and b1 <= 247 then
      if i + 3 <= len then
        local b2 = string.byte(s, i + 1)
        local b3 = string.byte(s, i + 2)
        local b4 = string.byte(s, i + 3)
        cp = ((b1 & 7) << 18) | ((b2 & 63) << 12) | ((b3 & 63) << 6) | (b4 & 63)
        ch = string.sub(s, i, i + 3)
        step = 4
      end
    end

    tokens[#tokens + 1] = { char = ch, cp = cp }
    i = i + step
  end
  return tokens
end

local function format_pangu(text)
  local tokens = parse_tokens(text)
  local num_tokens = #tokens
  if num_tokens == 0 then
    return ""
  end

  local res = {}
  for i = 1, num_tokens do
    res[#res + 1] = tokens[i].char
    if i < num_tokens then
      local c1 = tokens[i]
      local c2 = tokens[i + 1]

      if not is_whitespace(c1.cp) and not is_whitespace(c2.cp) then
        local need_space = false

        if is_cjk(c1.cp) and is_alphanumeric(c2.cp) then
          need_space = true
        elseif is_alphanumeric(c1.cp) and is_cjk(c2.cp) then
          need_space = true
        elseif is_cjk(c1.cp) and c2.cp == 36 and (i + 2 <= num_tokens and is_alphanumeric(tokens[i + 2].cp)) then
          need_space = true
        elseif c1.cp == 37 and (i >= 2 and is_digit(tokens[i - 1].cp)) and is_cjk(c2.cp) then
          need_space = true
        end

        if need_space then
          res[#res + 1] = " "
        end
      end
    end
  end

  return table.concat(res, "")
end

local function halfwidth_to_fullwidth(text)
  local tokens = parse_tokens(text)
  local num_tokens = #tokens
  local res = {}

  for i = 1, num_tokens do
    local tok = tokens[i]
    local cp = tok.cp
    local converted = nil

    if cp == 44 then
      local is_num = false
      if i > 1 and i < num_tokens and is_digit(tokens[i - 1].cp) and is_digit(tokens[i + 1].cp) then
        is_num = true
      end
      if not is_num then
        converted = "，"
      end
    elseif cp == 58 then
      local is_time = false
      if i > 1 and i < num_tokens and is_digit(tokens[i - 1].cp) and is_digit(tokens[i + 1].cp) then
        is_time = true
      end
      if not is_time then
        converted = "："
      end
    elseif cp == 59 then
      converted = "；"
    elseif cp == 33 then
      converted = "！"
    elseif cp == 63 then
      converted = "？"
    elseif cp == 40 then
      converted = "（"
    elseif cp == 41 then
      converted = "）"
    end

    if converted ~= nil then
      res[#res + 1] = converted
    else
      res[#res + 1] = tok.char
    end
  end

  return table.concat(res, "")
end

local function fullwidth_to_halfwidth(text)
  local tokens = parse_tokens(text)
  local num_tokens = #tokens
  local res = {}

  for i = 1, num_tokens do
    local tok = tokens[i]
    local cp = tok.cp
    local converted = nil

    if cp == 65292 then
      converted = ", "
    elseif cp == 12290 then
      converted = ". "
    elseif cp == 65306 then
      converted = ": "
    elseif cp == 65307 then
      converted = "; "
    elseif cp == 65281 then
      converted = "! "
    elseif cp == 65311 then
      converted = "? "
    elseif cp == 65288 then
      converted = "("
    elseif cp == 65289 then
      converted = ")"
    elseif cp == 12304 then
      converted = "["
    elseif cp == 12305 then
      converted = "]"
    end

    if converted ~= nil then
      res[#res + 1] = converted
    else
      res[#res + 1] = tok.char
    end
  end

  return table.concat(res, "")
end

local function clean_extra_spaces(text)
  local tokens = parse_tokens(text)
  local num_tokens = #tokens
  local res = {}
  local prev_was_space = false

  for i = 1, num_tokens do
    local tok = tokens[i]
    if tok.cp == 32 or tok.cp == 9 then
      if not prev_was_space then
        res[#res + 1] = " "
        prev_was_space = true
      end
    else
      prev_was_space = false
      res[#res + 1] = tok.char
    end
  end

  return table.concat(res, "")
end

local function update_result(out_str)
  local input = state.get("input") or ""
  local in_len = string.len(input)
  local out_len = string.len(out_str)
  local diff = out_len - in_len
  local diff_str = ""
  if diff >= 0 then
    diff_str = "+" .. tostring(diff)
  else
    diff_str = tostring(diff)
  end

  state.set("output", out_str)
  state.set("hasResult", (out_len > 0))
  state.set("stats", "原字符数: " .. tostring(in_len) .. " | 结果字符数: " .. tostring(out_len) .. " (变化: " .. diff_str .. " 字节)")
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function formatSpacing()
  local input = state.get("input") or ""
  if input == "" then
    state.set("output", "")
    state.set("hasResult", false)
    state.set("stats", "字符数: 0")
    return nil
  end
  local res = format_pangu(input)
  update_result(res)
  return nil
end

function toFullwidth()
  local input = state.get("input") or ""
  if input == "" then
    return nil
  end
  local res = halfwidth_to_fullwidth(input)
  update_result(res)
  return nil
end

function toHalfwidth()
  local input = state.get("input") or ""
  if input == "" then
    return nil
  end
  local res = fullwidth_to_halfwidth(input)
  update_result(res)
  return nil
end

function cleanSpaces()
  local input = state.get("input") or ""
  if input == "" then
    return nil
  end
  local res = clean_extra_spaces(input)
  update_result(res)
  return nil
end

function formatAll()
  local input = state.get("input") or ""
  if input == "" then
    return nil
  end
  local res = format_pangu(input)
  res = halfwidth_to_fullwidth(res)
  update_result(res)
  return nil
end

function copyResult()
  local out = state.get("output") or ""
  if out ~= "" then
    clipboard.set(out)
    dialog.toast("已复制到剪贴板")
  end
  return nil
end

function pasteInput()
  clipboard.get(function(text)
    if text ~= nil and text ~= "" then
      state.set("input", text)
      formatSpacing()
      dialog.toast("已粘贴并完成排版")
    end
    return nil
  end)
  return nil
end

function clearAll()
  state.set("input", "")
  state.set("output", "")
  state.set("hasResult", false)
  state.set("stats", "字符数: 0")
  state.set("hasError", false)
  state.set("errorMsg", "")
  return nil
end

function onInit()
  state.set("input", "为什么Apple的产品这么贵？今天有100个人在GitHub上参与了讨论，完成度达到95%左右。")
  state.set("output", "")
  state.set("hasResult", false)
  state.set("stats", "字符数: 0")
  state.set("hasError", false)
  state.set("errorMsg", "")
  formatSpacing()
  return nil
end
