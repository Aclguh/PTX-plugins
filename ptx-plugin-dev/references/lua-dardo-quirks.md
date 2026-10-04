# lua_dardo 沙箱坑位复现记录

宿主 VM：`packages/third_party/lua_dardo`（上游 lua_dardo 0.0.5 的本地维护分支，
为指令数预算防护而 fork）。语义为 Lua 5.1，但存在以下**非标准行为**。
每条均给出最小复现方法；复现工具：`PTX-plugins/dev/bin/dbg.dart`。

## 复现工具

```bash
cd PTX-plugins/dev
dart run bin/dbg.dart <chunk.lua>   # 直跑单个 Lua chunk（不含插件 main.lua）
```

注意两点：
- dbg.dart 只加载目标 chunk 本身，chunk 里引用插件内 local 函数会得到
  `not function!` / `Null, not a table!` —— 这类报错先检查是不是"没加载 main.lua"。
- 进程异常退出时 Lua print 输出可能因缓冲丢失，dbg.dart 已用 try/catch 兜底打印错误。

## 坑位清单

### 1. 十六进制字面量不可用

```lua
local x = 0x537   -- 编译错误: syntax error near 'x537'
local x = 1335    -- 正确
```
Lua 5.1 本就不支持 `0x`（5.2 起引入），本分支忠实 5.1。

### 2. 对字符串用 `#` 直接抛错

```lua
local n = #s      -- 抛 Exception: length error!  (s 为 string)
local n = string.len(s)   -- 正确; 返回【字符数】而非字节数
```
生产实现（lua_state_impl.luaLen）对 String 分支 pushInteger 后未 return，
继续走 metamethod/table 分支最终 throw。对 table 用 `#` 正常。

### 3. 无值 return 被静默吞掉（最危险）

```lua
local function f(r)
  if r < 0 then return end      -- BUG: 不返回, 继续执行后续语句
  return "in"
end
```

实测：`g(-1)` 继续执行并返回 "in"。带值 return 正常：

```lua
if r < 0 then return nil end    -- 正确写法
```

推论：守卫子句、循环内提前退出、空回调一律 `return nil`（或返回具体值）。
qr_tool 曾因 setFn 守卫失效导致 QR 格式区被数据位覆盖。

### 4. 十进制字符串转义使词法器崩溃

```lua
local NBSP = "\194\160"   -- 编译期 Dart 崩溃: String has no instance method '-'
local NBSP = "\u{A0}"     -- 正确
```
lexer 的 `\ddd` 分支存在 `chunk.current - '0'` 的类型错误（String 相减）。

### 5. 模式匹配全家不可用（隐蔽度最高）

```lua
string.gmatch("a,b", "([^,]+)")   -- RangeError; 换些输入则静默返回 0 次迭代
string.gsub("a-b", "-", "+")      -- 静默不替换, 原样返回 "a-b" (最阴险)
string.match("key=val", "(%w+)")  -- 返回 nil
string.find("abc", "%a+")         -- 异常或错位
string.reverse("abc")             -- RangeError (index)
```

根因在 fork 的 `string_lib.dart`：`_strGmatch` 每次迭代都从头 match 且推进逻辑错误，
模式编译器对字符类整体失效。**唯一可靠的查找方式**：

```lua
local pos = string.find(s, "
", 1, true)  -- 纯文本模式, 第 4 参必须 true
```

分割/替换/提取一律用 `find(plain) + sub` 手写字符循环，参考
`PTX-plugins/plugin-source/qr_tool/main.lua` 的 `splitLines`。`dev/bin/lint.dart` 已把
gmatch/gsub/match/reverse 列为禁用项并粗检 find 的 plain 标志。

### 6. 字符串库可用性速查

| 可用 | 不可用 |
|---|---|
| `string.len`（字符数） | `string.gmatch` / `string.gsub` / `string.match` |
| `string.byte`（码点） | `string.reverse` |
| `string.sub` / `string.char` / `string.rep` | `#` 取字符串长度 |
| `string.upper` / `string.lower` | 十进制转义 `\ddd` |
| `string.find`（仅纯文本模式） | `string.format` 的 `%g` / `%e` |
| `math.max` / `math.floor` / `math.abs` 等 | `math.min`（等同取大） |

### 7. math.min 行为等同于 max（复制粘贴 bug）

```lua
math.min(8, 9)  -- 返回 9 (期望 8)
math.min(9, 8)  -- 返回 9
math.max(4, 2)  -- 返回 4 (正常)
```

`math_lib.dart` 中 `_min` 与 `_max` 为同一份实现 (都用 `luaOpLt` 找最大值)。
取最小值必须手写: `if a < b then v = a else v = b end`。
lint 已将 `math.min` 列为禁用项。

### 8. 字符串为"字符/码元"语义（影响所有字节级算法）

```lua
string.len("你")          -- 1        (不是 UTF-8 的 3 字节)
string.byte("你", 1)      -- 20320    (0x4F60 码点, 不是 E4 B8 AD)
string.len("\u{1F600}")   -- 2        (emoji = UTF-16 代理对两个码元)
string.byte("\u{1F600}",1)-- 55357    (0xD83D 高代理)
```

推论：
- 需要 UTF-8 字节流的算法（QR Byte 模式、自行实现哈希/压缩）必须在 Lua 内做
  码点→UTF-8 编码，含代理对重组（0xD800-0xDBFF + 0xDC00-0xDFFF → 4 字节）与
  孤立代理替换（U+FFFD），参考 `PTX-plugins/plugin-source/qr_tool/main.lua` 的 `strBytes`。
- 宿主 `codec`/`hash` API 不受影响（Dart 侧 utf8.encode）。
- 按字符截断（如历史列表 `string.sub(s,1,28)`）反而是字符语义，恰好符合 UI 预期。

### 9. string.format 无 %g / %e

仅支持 `c i d o u x X f s q`。数值展示用 `%.Nf` 后去尾零，或自行实现有效数字格式化。

### 10. 沙箱封禁与替代

`os` / `io` / `debug` / `package` / `require` / `dofile` / `loadfile` 全局置 nil。
- 时间：`util.timestamp()` / `util.timestampMs()`（UTC epoch，无本地时区；
  时区换算让用户输入偏移分钟数或插件内置换算表）。
- 历法：days_from_civil / civil_from_days（Hinnant 整数算法）纯算术可实现，
  注意 1900 非闰年、2000 闰年等边界。

### 11. 指令数预算

单次 Lua 调用（含回调再入）预算 500 万指令（宿主 `LuaEngine.defaultInstructionBudget`）。
超限抛 Lua 执行错误，宿主捕获后 SnackBar 提示，不崩溃宿主。
设计插件时：限制输入规模（如 diff 每侧 ≤400 行）、避免无界回溯（正则引擎注意
`(a+)+b` 类灾难模式），并给出友好错误提示。

### 12. 函数内 or 条件链与守卫后置调用的误编译

复现 (timestamp_tool 实测):
```lua
-- 该守卫在 chunk 顶层与 eval 中正常, 编译进 main.lua 函数体后整链失效,
-- 条件永假继续往下执行, 最终在 nil 上取字段报 "Null, not a table"
function tsToDate()
  local v = tonumber(raw)
  if v == nil or v < 0 or v ~= math.floor(v) then
    setError("时间戳必须是正整数")
    return            -- 裸 return 还会被吞 (见坑 3)
  end
  ...
end
```
规避模式 (已被 11 个插件采用):
- 多条件守卫拆嵌套 `if`, 每个分支 `return nil`
- 不写"守卫分支 return 后紧跟顶层调用表字段实参"的形态, 用
  `if ok then call(t.a, t.b) else ... end` 无早退结构

### 13. 表索引与数字键

float 整数值键与 int 键视为同一键（`t[1.0]` 读 `t[1]`，实测一致）；
`64/2` 产生的 32.0 作循环上限与索引均安全。仍建议对算术派生的索引用
`math.floor` 显式取整，防语义漂移。
