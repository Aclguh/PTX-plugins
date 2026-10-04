-- ============================================================
-- qr_tool — 二维码生成
-- 纯 Lua QR 编码器: Byte 模式 / 版本 1-5 / 纠错级别 M(默认) 与 L(回退)
-- 宿主沙箱为 Lua 5.1 语义 (无位运算、无 os/io 库), 所有位操作以纯算术实现
-- ============================================================

local function bitxor(a, b)
  local r, bitv = 0, 1
  while a > 0 or b > 0 do
    local ab, bb = a % 2, b % 2
    if ab ~= bb then r = r + bitv end
    a = (a - ab) / 2
    b = (b - bb) / 2
    bitv = bitv * 2
  end
  return r
end

-- GF(256) 有限域, 本原多项式 0x11D
local GF_EXP, GF_LOG = {}, {}
do
  local v = 1
  for i = 0, 254 do
    GF_EXP[i] = v
    GF_LOG[v] = i
    v = v * 2
    if v > 255 then v = bitxor(v, 285) end
  end
  for i = 255, 511 do GF_EXP[i] = GF_EXP[i - 255] end
end

local function gfMul(a, b)
  if a == 0 or b == 0 then return 0 end
  return GF_EXP[GF_LOG[a] + GF_LOG[b]]
end

-- 生成 RS 生成多项式 (系数降幂排列, 首项恒为 1)
local function rsGenerator(degree)
  local poly = { [1] = 1 }
  for i = 0, degree - 1 do
    local a = GF_EXP[i]
    local nextp = {}
    for k = 1, #poly + 1 do
      local cur = poly[k] or 0
      local prev = poly[k - 1] or 0
      nextp[k] = bitxor(cur, gfMul(prev, a))
    end
    poly = nextp
  end
  return poly
end

-- 计算数据码字的 RS 纠错码字
local function rsRemainder(data, ecLen)
  local gen = rsGenerator(ecLen)
  local buf = {}
  for i = 1, #data do buf[i] = data[i] end
  for i = 1, #data do
    local factor = buf[i]
    if factor ~= 0 then
      for k = 2, ecLen + 1 do
        local idx = i + k - 1
        buf[idx] = bitxor(buf[idx] or 0, gfMul(gen[k], factor))
      end
    end
  end
  local rem = {}
  for i = 1, ecLen do rem[i] = buf[#data + i] or 0 end
  return rem
end

local function pushBits(bits, val, n)
  for i = n - 1, 0, -1 do
    bits[#bits + 1] = math.floor(val / (2 ^ i)) % 2
  end
end

-- lua_dardo 字符串为 UTF-16 码元序列: string.byte 返回码点/代理对而非 UTF-8 字节,
-- QR Byte 模式要求标准 UTF-8 字节流, 故在此显式编码 (含代理对重组与孤立代理替换)
local function strBytes(s)
  local out = {}
  local n = string.len(s)
  local i = 1
  while i <= n do
    local c = string.byte(s, i)
    if c >= 55296 and c <= 56319 and i + 1 <= n then
      -- 高代理: 尝试与低位代理重组为增补码点
      local d = string.byte(s, i + 1)
      if d >= 56320 and d <= 57343 then
        local cp = 65536 + (c - 55296) * 1024 + (d - 56320)
        out[#out + 1] = 240 + math.floor(cp / 262144)
        out[#out + 1] = 128 + math.floor(cp / 4096) % 64
        out[#out + 1] = 128 + math.floor(cp / 64) % 64
        out[#out + 1] = 128 + cp % 64
        i = i + 2
      else
        out[#out + 1] = 239
        out[#out + 1] = 191
        out[#out + 1] = 189
        i = i + 1
      end
    elseif (c >= 55296 and c <= 57343) then
      -- 孤立代理: 以 U+FFFD 替代, 不产出非法 UTF-8
      out[#out + 1] = 239
      out[#out + 1] = 191
      out[#out + 1] = 189
      i = i + 1
    elseif c < 128 then
      out[#out + 1] = c
      i = i + 1
    elseif c < 2048 then
      out[#out + 1] = 192 + math.floor(c / 64)
      out[#out + 1] = 128 + c % 64
      i = i + 1
    else
      out[#out + 1] = 224 + math.floor(c / 4096)
      out[#out + 1] = 128 + math.floor(c / 64) % 64
      out[#out + 1] = 128 + c % 64
      i = i + 1
    end
  end
  return out
end

-- 版本 1-5 的容量表 (数据码字数), Byte 模式头部占 12 bit (4 模式 + 8 计数)
local EC = {
  M = { data = { 16, 28, 44, 64, 86 }, ec = { 10, 16, 26, 18, 24 }, blocks = { 1, 1, 1, 2, 2 }, fmt = 0 },
  L = { data = { 19, 34, 55, 80, 108 }, ec = { 7, 10, 15, 20, 26 }, blocks = { 1, 1, 1, 1, 1 }, fmt = 1 },
}
local ALIGN = { {}, { 6, 18 }, { 6, 22 }, { 6, 26 }, { 6, 30 } }

local QR = {}

-- 编码返回 matrix(0/1 二维数组, 含 0 起始索引), version, size; 失败返回 nil, 错误信息
function QR.encode(text, eclName)
  local ecl = EC[eclName] or EC.M
  local bytes = strBytes(text)
  local version = 0
  for v = 1, 5 do
    if #bytes <= ecl.data[v] - 2 then
      version = v
      break
    end
  end
  if version == 0 then
    return nil, "内容过长: 当前级别最多约 " .. (ecl.data[5] - 2) .. " 字节"
  end

  -- 1. 位流: 模式指示符 + 字符计数 + 数据 + 终止符 + 补位码字
  local bits = {}
  pushBits(bits, 4, 4) -- Byte 模式指示符 0100
  pushBits(bits, #bytes, 8)
  for _, b in ipairs(bytes) do pushBits(bits, b, 8) end
  local capBits = ecl.data[version] * 8
  local term = 4
  if #bits + term > capBits then term = capBits - #bits end
  if term > 0 then pushBits(bits, 0, term) end
  while #bits % 8 ~= 0 do bits[#bits + 1] = 0 end

  local dataCw = {}
  for i = 1, #bits, 8 do
    local v = 0
    for j = 0, 7 do v = v * 2 + bits[i + j] end
    dataCw[#dataCw + 1] = v
  end
  local pad = { 236, 17 }
  local padCount = 0
  while #dataCw < ecl.data[version] do
    padCount = padCount + 1
    dataCw[#dataCw + 1] = pad[(padCount - 1) % 2 + 1]
  end

  -- 2. 分块计算纠错码字并按规范"逐列交错" (非拼接): 先按列交错数据块, 再交错纠错块
  local nBlocks = ecl.blocks[version]
  local ecLen = ecl.ec[version]
  local per = ecl.data[version] / nBlocks
  local blockData, blockEcc = {}, {}
  for b = 0, nBlocks - 1 do
    local blk = {}
    for i = 1, per do blk[i] = dataCw[b * per + i] end
    blockData[b] = blk
    blockEcc[b] = rsRemainder(blk, ecLen)
  end
  local finalCw = {}
  for i = 1, per do
    for b = 0, nBlocks - 1 do
      finalCw[#finalCw + 1] = blockData[b][i]
    end
  end
  for i = 1, ecLen do
    for b = 0, nBlocks - 1 do
      finalCw[#finalCw + 1] = blockEcc[b][i]
    end
  end

  -- 3. 矩阵与功能图形
  local size = 17 + 4 * version
  local modules, reserved = {}, {}
  for r = 0, size - 1 do
    modules[r], reserved[r] = {}, {}
    for c = 0, size - 1 do
      modules[r][c] = false
      reserved[r][c] = false
    end
  end

  local function setFn(r, c, dark)
    if r < 0 or r >= size or c < 0 or c >= size then return nil end
    modules[r][c] = dark == true
    reserved[r][c] = true
  end

  local function drawFinder(r0, c0)
    for dr = -1, 7 do
      for dc = -1, 7 do
        local dark = (dr >= 0 and dr <= 6 and (dc == 0 or dc == 6))
            or (dc >= 0 and dc <= 6 and (dr == 0 or dr == 6))
            or (dr >= 2 and dr <= 4 and dc >= 2 and dc <= 4)
        setFn(r0 + dr, c0 + dc, dark)
      end
    end
  end
  drawFinder(0, 0)
  drawFinder(0, size - 7)
  drawFinder(size - 7, 0)

  for i = 8, size - 9 do
    local dark = (i % 2 == 0)
    setFn(6, i, dark)
    setFn(i, 6, dark)
  end

  local function nearFinder(r, c)
    return (r <= 8 and c <= 8)
        or (r <= 8 and c >= size - 9)
        or (r >= size - 9 and c <= 8)
  end
  local centers = ALIGN[version]
  for _, ar in ipairs(centers) do
    for _, ac in ipairs(centers) do
      if not nearFinder(ar, ac) then
        for dr = -2, 2 do
          for dc = -2, 2 do
            local dark = math.max(math.abs(dr), math.abs(dc)) ~= 1
            setFn(ar + dr, ac + dc, dark)
          end
        end
      end
    end
  end

  local function formatInfoBits(m)
    local data = ecl.fmt * 8 + m
    local rem = data
    for _ = 1, 10 do
      if rem >= 512 then
        rem = bitxor(rem * 2, 1335)
      else
        rem = rem * 2
      end
    end
    return bitxor(data * 1024 + rem, 21522)
  end

  local function getBit(x, i)
    return math.floor(x / (2 ^ i)) % 2 == 1
  end

  local function drawFormatBits(m)
    local bits = formatInfoBits(m)
    -- 坐标约定 setFn(row, col); 参考实现 setFunctionModule(x=col, y=row)
    -- 第一份: 竖条(列 8, 行 0-8) + 横条(行 8, 列 0-5)
    for i = 0, 5 do setFn(i, 8, getBit(bits, i)) end
    setFn(7, 8, getBit(bits, 6))
    setFn(8, 8, getBit(bits, 7))
    setFn(8, 7, getBit(bits, 8))
    for i = 9, 14 do setFn(8, 14 - i, getBit(bits, i)) end
    -- 第二份: 横条(行 8, 靠右) + 竖条(列 8, 靠下)
    for i = 0, 7 do setFn(8, size - 1 - i, getBit(bits, i)) end
    for i = 8, 14 do setFn(size - 15 + i, 8, getBit(bits, i)) end
    setFn(size - 8, 8, true) -- 固定暗模块
  end

  -- 先以占位掩码写入格式信息, 确保格式区在码字布点前被标记为保留
  drawFormatBits(0)

  -- 5. 码字按之字形布点
  local bitIdx, totalBits = 0, #finalCw * 8
  local right = size - 1
  while right >= 1 do
    if right == 6 then right = 5 end
    local upward = math.floor((right + 1) / 2) % 2 == 0
    for vert = 0, size - 1 do
      for j = 0, 1 do
        local c = right - j
        local r = upward and (size - 1 - vert) or vert
        if not reserved[r][c] and bitIdx < totalBits then
          local byte = finalCw[math.floor(bitIdx / 8) + 1]
          local bit = math.floor(byte / (2 ^ (7 - bitIdx % 8))) % 2
          modules[r][c] = (bit == 1)
          bitIdx = bitIdx + 1
        end
      end
    end
    right = right - 2
  end

  -- 6. 掩码评估 (N3 采用简化图案判定; 掩码选择只影响冗余度, 不影响可解码性)
  local function maskHit(m, r, c)
    if m == 0 then return (r + c) % 2 == 0 end
    if m == 1 then return r % 2 == 0 end
    if m == 2 then return c % 3 == 0 end
    if m == 3 then return (r + c) % 3 == 0 end
    if m == 4 then return (math.floor(r / 2) + math.floor(c / 3)) % 2 == 0 end
    if m == 5 then return (r * c) % 2 + (r * c) % 3 == 0 end
    if m == 6 then return ((r * c) % 2 + (r * c) % 3) % 2 == 0 end
    return ((r + c) % 2 + (r * c) % 3) % 2 == 0
  end

  local function applyMask(m)
    for r = 0, size - 1 do
      for c = 0, size - 1 do
        if not reserved[r][c] and maskHit(m, r, c) then
          modules[r][c] = not modules[r][c]
        end
      end
    end
  end

  local function penaltyScore()
    local score = 0
    -- N1: 行/列连续同色 + N3: 类定位图形 1:1:3:1:1
    for dir = 0, 1 do
      for line = 0, size - 1 do
        local runs, colors = {}, {}
        local runLen, runDark = 0, false
        for i = 0, size - 1 do
          local v = (dir == 0) and modules[line][i] or modules[i][line]
          if v == runDark then
            runLen = runLen + 1
          else
            runs[#runs + 1] = runLen
            colors[#colors + 1] = runDark
            runDark, runLen = v, 1
          end
        end
        runs[#runs + 1] = runLen
        colors[#colors + 1] = runDark
        -- 隐含留白按 4 个亮模块计
        runs[#runs + 1] = 4
        colors[#colors + 1] = false
        for k = 1, #runs do
          if runs[k] >= 5 then
            score = score + 3 + (runs[k] - 5)
          end
          -- 以暗段为中心检查 暗亮暗暗暗亮暗 (两侧亮段 >= 1)
          if colors[k] and runs[k] == 3
              and k >= 2 and k + 2 <= #runs
              and colors[k - 1] == false and colors[k + 1] == false
              and colors[k - 2] == true and colors[k + 2] == true
              and runs[k - 1] == 1 and runs[k + 1] == 1
              and runs[k - 2] == 1 and runs[k + 2] == 1 then
            score = score + 40
          end
        end
      end
    end
    -- N2: 2x2 同色块
    for r = 0, size - 2 do
      for c = 0, size - 2 do
        local v = modules[r][c]
        if modules[r][c + 1] == v and modules[r + 1][c] == v and modules[r + 1][c + 1] == v then
          score = score + 3
        end
      end
    end
    -- N4: 明暗平衡
    local dark = 0
    for r = 0, size - 1 do
      for c = 0, size - 1 do
        if modules[r][c] then dark = dark + 1 end
      end
    end
    local total = size * size
    local k = math.abs(dark * 20 - total * 10) / total
    score = score + (math.ceil(k) - 2) * 10
    return score
  end

  local bestMask, bestScore = 0, math.huge
  for m = 0, 7 do
    applyMask(m)
    drawFormatBits(m)
    local p = penaltyScore()
    if p < bestScore then
      bestScore, bestMask = p, m
    end
    applyMask(m) -- 掩码以取反实现, 再次应用即撤销
  end
  applyMask(bestMask) -- 应用最终选定的掩码
  drawFormatBits(bestMask)

  return { matrix = modules, version = version, size = size, mask = bestMask, ecl = eclName or "M" }
end

-- 渲染为含规范静区 (4 模块) 的行主序 0/1 位图串, 交由宿主 PixelGrid 组件逐格填充
local QUIET_ZONE = 4

local function renderPixels(res)
  local m, size = res.matrix, res.size
  local total = size + QUIET_ZONE * 2
  local rows = {}
  local quietRow = string.rep("0", total)
  for _ = 1, QUIET_ZONE do
    rows[#rows + 1] = quietRow
  end
  for r = 0, size - 1 do
    local row = {}
    for _ = 1, QUIET_ZONE do row[#row + 1] = "0" end
    for c = 0, size - 1 do
      row[#row + 1] = m[r][c] and "1" or "0"
    end
    for _ = 1, QUIET_ZONE do row[#row + 1] = "0" end
    rows[#rows + 1] = table.concat(row)
  end
  for _ = 1, QUIET_ZONE do
    rows[#rows + 1] = quietRow
  end
  -- 自适应单格尺寸: 目标宽约 300 逻辑像素, 限 4-8 保证像素边缘清晰
  -- (宿主 VM 的取小函数行为等同于取大, 限幅必须手写)
  local cell = math.floor(300 / total)
  if cell > 8 then cell = 8 end
  if cell < 4 then cell = 4 end
  return {
    pixels = table.concat(rows),
    cols = total,
    cell = cell,
  }
end

-- ---------------- 测试钩子 (harness 专用, 不参与 UI 流程) ----------------
function _qr_matrix(text, ecl)
  return QR.encode(text, ecl)
end

function _qr_pixels(text)
  local res, err = QR.encode(text, "M")
  if not res then
    res, err = QR.encode(text, "L")
  end
  if not res then
    return nil, err
  end
  return renderPixels(res)
end

-- ---------------- 插件状态与交互 ----------------
local HISTORY_KEY = "history_v1"
local HISTORY_MAX = 3

local function setError(msg)
  state.set("hasError", true)
  state.set("errorMsg", msg)
end

local function clearError()
  state.set("hasError", false)
  state.set("errorMsg", "")
end

-- lua_dardo 的模式匹配全家 (gmatch/gsub/match/带模式 find) 不可用:
-- gmatch 静默返回 0 匹配或 RangeError, gsub 静默不替换。字符串分割一律手写。
local function splitLines(s)
  local out = {}
  local start = 1
  while true do
    local pos = string.find(s, "\n", start, true)
    if pos == nil then
      out[#out + 1] = string.sub(s, start)
      break
    end
    out[#out + 1] = string.sub(s, start, pos - 1)
    start = pos + 1
  end
  return out
end

local function decodeHistory(raw)
  local items = {}
  if raw and raw ~= "" then
    for _, encoded in ipairs(splitLines(raw)) do
      if encoded ~= "" then
        local ok, decoded = pcall(codec.urlDecode, encoded)
        if ok and decoded then items[#items + 1] = decoded end
      end
    end
  end
  return items
end

local function refreshHistoryState(items)
  for i = 1, HISTORY_MAX do
    local item = items[i]
    state.set("h" .. i .. "set", item ~= nil)
    if item then
      local shown = item
      if string.len(shown) > 28 then shown = string.sub(shown, 1, 28) .. "..." end
      state.set("h" .. i, shown)
    else
      state.set("h" .. i, "")
    end
  end
end

function onInit()
  state.set("qrText", "")
  state.set("qrPixels", "")
  state.set("qrCols", 0)
  state.set("qrCell", 6)
  state.set("qrInfo", "")
  state.set("hasResult", false)
  clearError()
  state.set("hasHistory", false)
  refreshHistoryState({})
  storage.get(HISTORY_KEY, function(raw)
    local items = decodeHistory(raw)
    refreshHistoryState(items)
    state.set("hasHistory", #items > 0)
  end)
end

local function build(text)
  local res, err = QR.encode(text, "M")
  if not res then
    res, err = QR.encode(text, "L")
  end
  return res, err
end

function generateQr()
  local text = state.get("qrText") or ""
  if text == "" then
    clearError()
    state.set("hasResult", false)
    state.set("qrPixels", "")
    setError("请输入要生成二维码的文本或链接")
    return nil
  end
  local res, err = build(text)
  if not res then
    clearError()
    state.set("hasResult", false)
    state.set("qrPixels", "")
    setError(err)
    return nil
  end
  clearError()
  local art = renderPixels(res)
  state.set("qrPixels", art.pixels)
  state.set("qrCols", art.cols)
  state.set("qrCell", art.cell)
  state.set("qrInfo", "版本 " .. res.version .. " (" .. res.size .. "x" .. res.size
      .. ") · 级别 " .. res.ecl .. " · 内容 " .. string.len(text) .. " 字符")
  state.set("hasResult", true)
end

function pasteInput()
  clipboard.get(function(val)
    if val and val ~= "" then
      state.set("qrText", val)
      dialog.toast("已从剪贴板粘贴")
    else
      dialog.toast("剪贴板为空")
    end
  end)
end

local function saveHistory(text)
  storage.get(HISTORY_KEY, function(raw)
    local items = decodeHistory(raw)
    for i = 1, #items do
      if items[i] == text then
        table.remove(items, i)
        break
      end
    end
    table.insert(items, 1, text)
    while #items > HISTORY_MAX do table.remove(items) end
    local encoded = {}
    for i, item in ipairs(items) do
      encoded[#encoded + 1] = codec.urlEncode(item)
    end
    storage.set(HISTORY_KEY, table.concat(encoded, "\n"))
    refreshHistoryState(items)
    state.set("hasHistory", #items > 0)
  end)
end

function saveCurrentToHistory()
  local text = state.get("qrText") or ""
  if text == "" then
    dialog.toast("当前没有可保存的内容")
    return nil
  end
  saveHistory(text)
  dialog.toast("已保存到历史")
end

function loadHistoryItem(idx)
  storage.get(HISTORY_KEY, function(raw)
    local items = decodeHistory(raw)
    local item = items[math.floor(tonumber(idx) or 0)]
    if item then
      state.set("qrText", item)
      generateQr()
    end
  end)
end

function clearHistory()
  dialog.confirm("清空历史", "确定清空全部生成历史吗？", function(ok)
    if ok then
      storage.remove(HISTORY_KEY)
      refreshHistoryState({})
      state.set("hasHistory", false)
      dialog.toast("历史已清空")
    end
  end)
end
