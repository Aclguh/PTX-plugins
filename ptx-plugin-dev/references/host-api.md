# 宿主 Lua API 真实清单

来源：`packages/lua/lib/src/api/*.dart`（生产绑定）。宿主启动插件时按此注入全局表，
沙箱同时将 `os` / `io` / `debug` / `package` / `require` / `dofile` / `loadfile` 置 nil；
保留 `base` / `table` / `string` / `math` 标准库（Lua 5.1 语义）。

## state — UI 状态（无权限门槛）

```lua
state.get(key)          -- 读取（未设置返回 nil）
state.set(key, value)   -- 仅接受 string / number / boolean / nil；触发 UI 刷新
                        -- 注意: 值与旧值相同则不通知, 重复 set 同值不会触发重渲染
```

## dialog — 对话框（无权限门槛）

```lua
dialog.toast(message)
dialog.alert(title, message)
dialog.confirm(title, message, function(ok) ... end)  -- 异步, 回调携带 boolean
```

## clipboard — 剪贴板（需 permissions 声明 "clipboard"）

```lua
clipboard.set(text)
clipboard.get(function(text) ... end)  -- 异步; 回调在【第 1 参】; 无内容时 text 为 nil
                                       -- 未传回调时结果写入状态 __clipboard_value
```

## storage — 持久化（需 "storage"；插件沙箱隔离）

```lua
storage.set(key, value)                  -- value 仅 string（内部走 SharedPreferences）
storage.get(key, function(val) ... end)  -- 异步; 回调在【第 2 参】
storage.remove(key)
```

## network — HTTP（需 "network"）

```lua
network.get(url)
-- 异步: 结果回调全局函数 onNetworkResponse(status, body)
-- 失败回调 onNetworkError(message)；同时镜像写入状态 __http_status / __http_body / __http_error
```

## codec — 编解码（同步纯函数）

```lua
codec.base64Encode(text)   -- UTF-8 字节级 Base64
codec.base64Decode(text)   -- 非法输入抛错, 调用侧用 pcall 兜底
codec.urlEncode(text)
codec.urlDecode(text)
```

## hash — 哈希（同步纯函数，UTF-8 字节级）

```lua
hash.md5(text) ; hash.sha1(text) ; hash.sha256(text)
```

## util — 通用工具（同步）

```lua
util.uuid()          -- UUID v4
util.timestamp()     -- 当前 Unix 秒
util.timestampMs()   -- 当前 Unix 毫秒
-- 注意: 文档中的 util.dateFormat/dateParse 并不存在, 历法换算需插件自实现
```

## system — 设备与环境（只读，无权限门槛）

```lua
system.platform()      -- 如 "android"
system.osVersion()     -- 系统版本描述
system.hostname()      -- 可能为空串（离线设备降级）
system.cores()         -- CPU 逻辑核心数
system.locale()        -- 如 "zh_CN"
system.screenWidth()   -- 物理像素; 无可用视图时 0
system.screenHeight()
system.pixelRatio()
system.brightness()    -- "dark" | "light"
```

## UI 事件 → Lua 的调用契约

- UI 事件 `{"action": "callLua", "function": "fn", "args": [...]}` 调用全局函数 `fn`；
  `args` 是 JSON 静态值（数字/字符串），不是状态插值。
- `onInit()` 在脚本加载完成后被宿主自动调用一次；`onDispose()` 在页面销毁时调用（可缺省）。
- 函数未定义时宿主静默跳过；函数内部抛错由宿主捕获并以 SnackBar 提示"执行错误"。
