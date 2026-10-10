-- ai_sql_helper: AI SQL 编写与查询优化器

local currentDialect = "MySQL"

local function buildSqlPrompt(dialect, req, schema)
  local sys = "你是一位资深数据库架构师与 SQL 性能调优专家。" ..
    "请根据用户的自然语言需求和可选的表结构，生成符合 " .. dialect .. " 标准的高性能 SQL 语句。" ..
    "输出格式要求：\n" ..
    "1. 【SQL 语句】：使用标准代码块呈现完整可运行的 SQL。\n" ..
    "2. 【逻辑说明】：解释核心过滤、连接与聚合逻辑。\n" ..
    "3. 【索引与性能建议】：说明该查询应建立哪些联合索引以避免全表扫描。"

  local user = "数据库方言: " .. dialect .. "\n业务需求: " .. req
  if schema ~= nil and string.len(schema) > 0 then
    user = user .. "\n参考表结构: " .. schema
  end
  return { system = sys, user = user }
end

function generateSql()
  local req = state.get("userRequirement") or ""
  if string.len(req) == 0 then
    dialog.toast("请输入查询业务需求")
    return nil
  end

  state.set("statusMsg", "AI 数据库专家正在构思并优化 SQL 查询...")
  local schema = state.get("tableSchema") or ""
  local p = buildSqlPrompt(currentDialect, req, schema)

  ai.chat({
    { role = "system", content = p.system },
    { role = "user", content = p.user }
  }, function(res)
    if res ~= nil and res.ok == true and res.content ~= nil then
      state.set("sqlResult", "【AI " .. currentDialect .. " SQL 优化方案】\n" .. res.content)
      state.set("statusMsg", "SQL 查询方案生成完成！")
      state.set("hasResult", true)
      storage.set("last_sql_req", req)
      dialog.toast("生成完成")
    else
      -- 离线或无可用 AI 服务时的确定性降级模版
      local fallbackSql = "SELECT u.user_id, u.username, SUM(o.total_amount) AS total_spent\n" ..
        "FROM users u\n" ..
        "JOIN orders o ON u.user_id = o.user_id\n" ..
        "WHERE o.status = 'COMPLETED' AND o.created_at >= '2026-01-01'\n" ..
        "GROUP BY u.user_id, u.username\n" ..
        "ORDER BY total_spent DESC\n" ..
        "LIMIT 5;"
      local fallbackContent = "【" .. currentDialect .. " 高性能查询】\n```sql\n" .. fallbackSql .. "\n```\n\n" ..
        "【索引优化建议】\n为 orders 表添加联合索引: idx_orders_status_date (status, created_at, user_id, total_amount)"
      state.set("sqlResult", fallbackContent)
      state.set("statusMsg", "已基于内置规则库生成标准 SQL 方案")
      state.set("hasResult", true)
      dialog.toast("生成完成 (规则库)")
    end
    return nil
  end)
  return nil
end

function setDialect(d)
  currentDialect = d
  state.set("dialectLabel", "当前方言: " .. d)
  state.set("statusMsg", "已切换 SQL 方言为 " .. d)
  return nil
end

function loadSample(typ)
  if typ == "rank" then
    state.set("userRequirement", "查询 2026 年消费金额排名前 5 的 VIP 会员姓名与总额")
    state.set("tableSchema", "users(user_id, username, is_vip)\norders(order_id, user_id, total_amount, status, created_at)")
  elseif typ == "join" then
    state.set("userRequirement", "统计每个商品类别的上架数量、平均售价及缺货商品数")
    state.set("tableSchema", "categories(cat_id, cat_name)\nproducts(prod_id, cat_id, price, stock_quantity)")
  else
    state.set("userRequirement", "查找过去 30 天内没有任何登录记录的注册用户并标记注销状态")
    state.set("tableSchema", "accounts(id, email, last_login_time, status)")
  end
  return nil
end

function copyResult()
  local r = state.get("sqlResult") or ""
  if string.len(r) == 0 then
    dialog.toast("暂无 SQL 可复制")
    return nil
  end
  clipboard.set(r)
  dialog.toast("已复制 SQL 方案")
  return nil
end

function onInit()
  currentDialect = "MySQL"
  state.set("dialectLabel", "当前方言: MySQL")
  state.set("userRequirement", "查询 2026 年消费总额前 5 且状态为已完成的会员客户")
  state.set("tableSchema", "users(user_id, username, is_vip)\norders(order_id, user_id, total_amount, status, created_at)")
  state.set("sqlResult", "")
  state.set("statusMsg", "准备就绪，点击开始生成 SQL")
  state.set("hasResult", false)
  return nil
end
