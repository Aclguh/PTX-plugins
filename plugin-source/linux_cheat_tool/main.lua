-- linux_cheat_tool — Linux 常用命令速查

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

local ITEMS = {
  {
    cat = "file",
    title = "递归查找并清理旧文件",
    cmd = "find . -name '*.log' -mtime +7 -delete",
    desc = "-name 匹配文件名通配符；-mtime +7 匹配修改时间超过7天；-delete 直接删除找到的文件"
  },
  {
    cat = "file",
    title = "递归搜索文本及所在行号",
    cmd = "grep -rn 'TODO' ./src",
    desc = "-r 递归遍历子目录；-n 显示匹配行的行号；-i 可用于忽略大小写"
  },
  {
    cat = "file",
    title = "打包并 Gzip 压缩目录",
    cmd = "tar -czvf backup.tar.gz ./data",
    desc = "-c 创建新归档；-z 使用 gzip 压缩；-v 显示处理详情；-f 指定产物文件名"
  },
  {
    cat = "file",
    title = "解压归档到指定目录",
    cmd = "tar -xzvf archive.tar.gz -C /opt/app",
    desc = "-x 解压归档；-z 使用 gzip；-C 切换解压目标目录"
  },
  {
    cat = "file",
    title = "跨目录/网络高效同步",
    cmd = "rsync -avz --progress ./src/ ./dest/",
    desc = "-a 归档模式保持权限软链；-v 详细输出；-z 传输压缩；--progress 显示实时进度"
  },
  {
    cat = "net",
    title = "查看特定端口监听进程",
    cmd = "ss -tulpn | grep :8080",
    desc = "-t TCP；-u UDP；-l 仅监听中；-p 显示进程 PID；-n 数字显示端口而非服务名"
  },
  {
    cat = "net",
    title = "查询打开端口的文件与进程",
    cmd = "lsof -i :8080",
    desc = "列出占用 8080 端口的所有进程 ID、用户名、文件描述符状态"
  },
  {
    cat = "net",
    title = "测试 HTTP 连接与打印响应头",
    cmd = "curl -Iv https://api.example.com",
    desc = "-I 仅发送 HEAD 请求获取响应头；-v 打印 TLS 握手与完整通信过程"
  },
  {
    cat = "net",
    title = "跟踪 DNS 完整递归解析链路",
    cmd = "dig +trace github.com",
    desc = "+trace 从根域名服务器向下逐级追踪权威 DNS 查询应答"
  },
  {
    cat = "sys",
    title = "查看内存占用前 10 的进程",
    cmd = "ps aux --sort=-%mem | head -n 11",
    desc = "ps aux 罗列所有进程；--sort=-%mem 按内存降序；head 取前 10 项加表头"
  },
  {
    cat = "sys",
    title = "查看磁盘分区挂载与剩余空间",
    cmd = "df -h",
    desc = "-h 人类可读格式 (GB / MB) 展示文件系统挂载点与剩余空间"
  },
  {
    cat = "sys",
    title = "查找当前目录下最大文件/目录",
    cmd = "du -sh * | sort -hr | head -n 10",
    desc = "du -sh 统计一级条目总大小；sort -hr 人类易读数字倒序；head 取前 10 项"
  },
  {
    cat = "sys",
    title = "跟踪服务实时 systemd 日志",
    cmd = "journalctl -u nginx -n 100 -f",
    desc = "-u 指定服务单元；-n 100 先输出末尾100行；-f 持续流式跟踪新日志"
  },
  {
    cat = "perm",
    title = "递归设置目录标准安全权限",
    cmd = "chmod -R 755 /var/www/html",
    desc = "-R 递归生效；755 代表所有者 rwx (可读写执行)，组与其他用户 r-x (只读执行)"
  },
  {
    cat = "perm",
    title = "递归变更文件属主与属组",
    cmd = "chown -R www-data:www-data /var/www",
    desc = "-R 递归设置；所有者与用户组同步指定为 www-data"
  },
  {
    cat = "perm",
    title = "将已有用户加入 sudo 特权组",
    cmd = "usermod -aG sudo developer",
    desc = "-a 追加模式（严禁遗漏，否则覆盖已有组）；-G 目标附加组"
  }
}

function _search_items(query, cat)
  local q = string.lower(trim(query or ""))
  local c = cat or "all"
  local matched = {}

  for i = 1, #ITEMS do
    local it = ITEMS[i]
    local passCat = (c == "all" or it.cat == c)
    if passCat then
      if q == "" then
        matched[#matched + 1] = it
      else
        local inCmd = (string.find(string.lower(it.cmd), q, 1, true) ~= nil)
        local inTitle = (string.find(string.lower(it.title), q, 1, true) ~= nil)
        local inDesc = (string.find(string.lower(it.desc), q, 1, true) ~= nil)
        if inCmd or inTitle or inDesc then
          matched[#matched + 1] = it
        end
      end
    end
  end
  return matched
end

local currentMatched = {}
local pageIdx = 1
local PAGE_SIZE = 4

function updateSlots()
  local total = #currentMatched
  local maxPages = math.floor((total + PAGE_SIZE - 1) / PAGE_SIZE)
  if maxPages < 1 then maxPages = 1 end
  if pageIdx > maxPages then pageIdx = maxPages end
  if pageIdx < 1 then pageIdx = 1 end

  local startIdx = (pageIdx - 1) * PAGE_SIZE

  for slot = 1, 4 do
    local itemIdx = startIdx + slot
    if itemIdx <= total then
      local it = currentMatched[itemIdx]
      state.set("slot" .. slot .. "_show", true)
      state.set("slot" .. slot .. "_title", it.title)
      state.set("slot" .. slot .. "_cmd", it.cmd)
    else
      state.set("slot" .. slot .. "_show", false)
      state.set("slot" .. slot .. "_title", "")
      state.set("slot" .. slot .. "_cmd", "")
    end
  end

  state.set("pageInfo", "第 " .. tostring(pageIdx) .. " / " .. tostring(maxPages) .. " 页 (共 " .. tostring(total) .. " 条命令)")
  return nil
end

function doSearch()
  local q = state.get("searchKeyword") or ""
  local c = state.get("curCat") or "all"
  currentMatched = _search_items(q, c)
  pageIdx = 1
  updateSlots()

  if #currentMatched > 0 then
    selectSlot(1)
  else
    state.set("selTitle", "未找到匹配命令")
    state.set("selCmd", "")
    state.set("selDesc", "请更换搜索词或切换分类")
  end
  return nil
end

function setCat(c)
  state.set("curCat", c)
  doSearch()
  return nil
end

function nextPage()
  local total = #currentMatched
  local maxPages = math.floor((total + PAGE_SIZE - 1) / PAGE_SIZE)
  if pageIdx < maxPages then
    pageIdx = pageIdx + 1
    updateSlots()
  end
  return nil
end

function prevPage()
  if pageIdx > 1 then
    pageIdx = pageIdx - 1
    updateSlots()
  end
  return nil
end

function selectSlot(slotNum)
  local itemIdx = (pageIdx - 1) * PAGE_SIZE + slotNum
  if itemIdx <= #currentMatched then
    local it = currentMatched[itemIdx]
    state.set("selTitle", it.title)
    state.set("selCmd", it.cmd)
    state.set("selDesc", it.desc)
  end
  return nil
end

function copyCmd(slotNum)
  local itemIdx = (pageIdx - 1) * PAGE_SIZE + slotNum
  if itemIdx <= #currentMatched then
    local it = currentMatched[itemIdx]
    if clipboard and clipboard.set then
      clipboard.set(it.cmd)
    end
    if dialog and dialog.toast then
      dialog.toast("已复制: " .. it.cmd)
    end
  end
  return nil
end

function copySelected()
  local cmd = state.get("selCmd") or ""
  if cmd ~= "" and clipboard and clipboard.set then
    clipboard.set(cmd)
  end
  if dialog and dialog.toast then
    dialog.toast("已复制所选命令")
  end
  return nil
end

function onInit()
  state.set("searchKeyword", "")
  state.set("curCat", "all")
  state.set("pageInfo", "")
  state.set("selTitle", "")
  state.set("selCmd", "")
  state.set("selDesc", "")

  for s = 1, 4 do
    state.set("slot" .. s .. "_show", false)
    state.set("slot" .. s .. "_title", "")
    state.set("slot" .. s .. "_cmd", "")
  end

  doSearch()
  return nil
end
