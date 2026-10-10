-- sudoku_solver_tool: 数独求解与练习台

local sampleEasy = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
local sampleMedium = "000000010400000000020000000000050407008000300001090000300400200050100000000806000"
local sampleHard = "800000000003600000070090200050007000000045700000100030001000068008500010090000400"

local function formatBoard(grid)
  local res = "+-------+-------+-------+\n"
  local r = 0
  while r < 9 do
    local line = "| "
    local c = 0
    while c < 9 do
      local val = grid[(r * 9) + c + 1]
      local ch = "."
      if val > 0 then
        ch = tostring(val)
      end
      line = line .. ch .. " "
      if (c % 3) == 2 then
        line = line .. "| "
      end
      c = c + 1
    end
    res = res .. line .. "\n"
    if (r % 3) == 2 then
      res = res .. "+-------+-------+-------+\n"
    end
    r = r + 1
  end
  return res
end

local function parseInput(raw)
  local grid = {}
  local len = string.len(raw)
  local i = 1
  while i <= len do
    local b = string.byte(raw, i)
    if b >= 49 and b <= 57 then
      grid[#grid + 1] = b - 48
    elseif b == 48 or b == 46 or b == 32 or b == 95 then
      grid[#grid + 1] = 0
    end
    i = i + 1
  end
  while #grid < 81 do
    grid[#grid + 1] = 0
  end
  return grid
end

local function isValidPlacement(grid, row, col, num)
  -- 行检查
  local c = 0
  while c < 9 do
    if grid[(row * 9) + c + 1] == num then
      return false
    end
    c = c + 1
  end
  -- 列检查
  local r = 0
  while r < 9 do
    if grid[(r * 9) + col + 1] == num then
      return false
    end
    r = r + 1
  end
  -- 3x3 宫格检查
  local boxRow = math.floor(row / 3) * 3
  local boxCol = math.floor(col / 3) * 3
  local dr = 0
  while dr < 3 do
    local dc = 0
    while dc < 3 do
      if grid[((boxRow + dr) * 9) + boxCol + dc + 1] == num then
        return false
      end
      dc = dc + 1
    end
    dr = dr + 1
  end
  return true
end

local function solveSudoku(grid)
  local steps = 0
  local maxSteps = 100000

  local function backtrack()
    steps = steps + 1
    if steps > maxSteps then
      return false
    end

    -- MRV 启发式选择候选最少的位置
    local bestIdx = -1
    local minCandidates = 10
    local i = 1
    while i <= 81 do
      if grid[i] == 0 then
        local r = math.floor((i - 1) / 9)
        local c = (i - 1) % 9
        local count = 0
        local n = 1
        while n <= 9 do
          if isValidPlacement(grid, r, c, n) then
            count = count + 1
          end
          n = n + 1
        end
        if count < minCandidates then
          minCandidates = count
          bestIdx = i
          if count <= 1 then
            break
          end
        end
      end
      i = i + 1
    end

    if bestIdx == -1 then
      return true -- 全部已填满
    end
    if minCandidates == 0 then
      return false -- 无合法数字可填
    end

    local row = math.floor((bestIdx - 1) / 9)
    local col = (bestIdx - 1) % 9
    local num = 1
    while num <= 9 do
      if isValidPlacement(grid, row, col, num) then
        grid[bestIdx] = num
        if backtrack() then
          return true
        end
        grid[bestIdx] = 0
      end
      num = num + 1
    end
    return false
  end

  local ok = backtrack()
  return ok, steps
end

function onInit()
  state.set("inputPuzzle", sampleEasy)
  state.set("boardDisplay", "")
  state.set("solveStatus", "未求解")
  state.set("stepsTaken", 0)
  state.set("hasResult", false)
  state.set("hasError", false)
  state.set("errorMsg", "")
  local grid = parseInput(sampleEasy)
  state.set("boardDisplay", formatBoard(grid))
  return nil
end

function solve()
  local raw = state.get("inputPuzzle")
  if raw == nil or string.len(raw) == 0 then
    state.set("hasError", true)
    state.set("errorMsg", "请输入至少 81 个字符表示数独盘面")
    return nil
  end

  local grid = parseInput(raw)
  -- 预检初始盘面合法性
  local i = 1
  while i <= 81 do
    local v = grid[i]
    if v > 0 then
      grid[i] = 0
      local r = math.floor((i - 1) / 9)
      local c = (i - 1) % 9
      if not isValidPlacement(grid, r, c, v) then
        state.set("hasError", true)
        state.set("errorMsg", "初始题目存在冲突，数字不合法: 位置 (" .. tostring(r + 1) .. "," .. tostring(c + 1) .. ")")
        state.set("hasResult", false)
        return nil
      end
      grid[i] = v
    end
    i = i + 1
  end

  state.set("hasError", false)
  state.set("errorMsg", "")

  local solved, steps = solveSudoku(grid)
  if solved then
    state.set("hasResult", true)
    state.set("solveStatus", "求解成功！")
    state.set("stepsTaken", steps)
    state.set("boardDisplay", formatBoard(grid))

    -- 构造 81 位解串
    local s = ""
    local k = 1
    while k <= 81 do
      s = s .. tostring(grid[k])
      k = k + 1
    end
    state.set("solvedString", s)
  else
    state.set("hasResult", false)
    state.set("hasError", true)
    state.set("errorMsg", "无解或搜索步数超过预算 (" .. tostring(steps) .. " 步)")
  end
  return nil
end

function setSample(level)
  local p = sampleEasy
  if level == "medium" then
    p = sampleMedium
  elseif level == "hard" then
    p = sampleHard
  end
  state.set("inputPuzzle", p)
  local grid = parseInput(p)
  state.set("boardDisplay", formatBoard(grid))
  state.set("hasResult", false)
  state.set("solveStatus", "已加载 " .. level .. " 预设题目")
  return nil
end

function copySolution()
  local board = state.get("boardDisplay")
  if board ~= nil then
    clipboard.set(board)
    dialog.toast("已复制盘面字符画")
  end
  return nil
end

function clearAll()
  state.set("inputPuzzle", "")
  local grid = parseInput("")
  state.set("boardDisplay", formatBoard(grid))
  state.set("hasResult", false)
  state.set("solveStatus", "已清空")
  return nil
end
