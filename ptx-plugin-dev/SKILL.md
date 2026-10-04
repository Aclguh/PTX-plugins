---
name: ptx-plugin-dev
description: 在 plugin-toolbox 仓库开发、调试或打包 .ptx 动态插件（PTX-plugins/ 目录下）时必读的实战经验。涵盖真实插件包格式、宿主 Lua API 真实语义、lua_dardo 沙箱语法坑位、harness 离线测试工作流与"真实解码器 oracle"验证方法。凡涉及 plugin.json / main.lua / ui/main.ui.json 的编写或改错、插件安装失败、宿主 API 调用报错、Lua 脚本在宿主中行为异常（字符串长度、裸 return、0x 字面量、转义崩溃等）的任务，即使用户没有明确说"开发插件"，也应先读本 skill 再动手。
---

# PluginToolbox .ptx 插件开发实战经验

本 skill 蒸馏自 qr_tool（纯 Lua QR 编码器）从零到真机可用的完整开发过程。
所有结论都以"踩坑后验证"为准，而非文档转述。

## 第零条铁律：以生产代码为准，文档会超前

仓库 `README.md` 与 `docs/02-ptx-spec.md` 描述了**尚未实现**的 API 与组件
（如 `codec.jsonEncode`、`app.*`、`util.dateFormat`、`Switch`/`TabLayout` 组件）。
动手前必须先读这三处生产实现，任何文档与代码冲突处一律以代码为准：

- 宿主 Lua API：`packages/lua/lib/src/api/*.dart`
- DUI 渲染器（组件/事件/属性的真实全集）：`packages/dui/lib/src/dui_renderer.dart`
- 事件 action 类型：`packages/dui/lib/src/dui_event_handler.dart`
- 清单字段与权限枚举：`packages/core/lib/src/model/plugin_manifest.dart`

若确需文档承诺但代码缺失的能力（如 system API、Container color 曾缺失），
先补宿主实现 + 测试 + 文档同步（走 AGENTS.md 验证门槛），再写插件。

## 插件包真实格式

```
<plugin_id>/
├── plugin.json        # 清单（不是 README 写的 manifest.json）
├── main.lua           # 入口（宿主启动后自动调用全局 onInit()）
└── ui/main.ui.json    # 声明式 UI 树
```

- 清单必填：`id`（`^[a-z0-9_]{3,50}$` 且与目录名一致）、`name`、`version`、
  `type: "lua"`、`category`（encoding/generator/text/system/calculator/network/other）、
  `permissions`、`entry`、`ui`。同 id 重复安装 = 整目录替换（可当"更新"用）。
- 参考实现：`sample_plugins/base64_tool/`（最小样例）、`PTX-plugins/plugin-source/qr_tool/`（完整实战，
  含纯算法、异步存储、历史槽位、测试钩子）。

## lua_dardo 沙箱语法坑位（最高价值，全部实测复现）

宿主 VM 是 `packages/third_party/lua_dardo` 本地维护分支（Lua 5.1 语义 + 指令数预算）。
以下坑位每一个都曾真实咬人，**写任何 Lua 前先内化**：

1. **禁十六进制字面量**：`0x537` 直接编译错误，写十进制（1335）。
2. **禁对字符串用 `#`**：直接抛 `length error!`（对 table 正常）。长度一律 `string.len(s)`。
3. **禁无值 `return`**：`if cond then return end` 的裸 return 被 VM **静默吞掉**并继续执行
   后续语句——这是最危险的控制流 bug（曾导致 QR 格式区被数据覆盖）。必须写 `return nil`。
4. **禁十进制转义 `\ddd`**：词法器直接崩溃（`String has no instance method '-'`）。
   用 `\u{XXXX}`（如 NBSP `"\u{A0}"`）或常规 `\n` `\t`。
5. **模式匹配全家不可用**：`string.gmatch`（静默 0 匹配或 RangeError）、`string.gsub`
   （静默不替换）、`string.match`（返回 nil）、`string.reverse`（RangeError）、
   `string.find` 带模式（异常/错位）。**只能**用 `string.find(s, sub, init, true)`
   （纯文本）+ `string.sub` 手写字符循环；分割/替换/查找一律自行实现。
6. **禁用 `math.min`**：与 `math.max` 是同一份复制粘贴实现，行为等同于**取大**
   （实测 `min(8,9)` 返回 9）。取小一律手写 `if a < b then ... end` 或三元式。
7. **字符串是"字符"语义**：`string.byte(s,i)` 返回 Unicode 码点（emoji 场景返回 UTF-16
   代理码元），`string.len` 是字符数——**不是 UTF-8 字节**。凡算法需要字节流（QR/哈希/
   Base64 自实现），必须在 Lua 内显式做码点→UTF-8 编码（含代理对重组），见
   `PTX-plugins/plugin-source/qr_tool/main.lua` 的 `strBytes`。
8. **`string.format` 无 `%g`/`%e`**：只有 `c/i/d/o/u/x/X/f/s/q`。有效数字格式化自行实现
   （`%.6f` + 去尾零）。
9. **`os`/`io`/`debug`/`package`/`require` 被置空**：时间用 `util.timestamp/timestampMs`，
   历法换算在插件内自实现（Hinnant days_from_civil 算法）。
10. **函数内多条件 `or` 链会被上下文相关地误编译**：同一条 `if v == nil or v < 0 then`
    在 chunk 顶层/eval 中正常，编译进 main.lua 函数体后可能整链失效（实测复现）。
    多条件守卫一律拆成嵌套 `if`；同理“守卫分支 `return` 后再顶层调用表字段实参”
    （`applyRgb(p.r, p.g, p.b)`）也会坏，改成 `if ok then ... else ... end` 无早退结构。
11. **单次调用 500 万指令预算**：指数级回溯（正则灾难性回溯）、O(n²) 大输入会超限，
   超限以 Lua 执行错误呈现，宿主侧不会崩溃——插件内应自行限制输入规模并给出友好提示。

调试这些坑位的最小复现手法：`PTX-plugins/dev/bin/dbg.dart` 可直跑单个 Lua chunk
（`dart run bin/dbg.dart <file.lua>`），注意它只加载该 chunk、不含插件 main.lua。

## 宿主 API 真实语义（易错点）

- **storage.get / clipboard.get / network.get 全部是异步回调式**，不能同步拿返回值：
  `storage.get(key, function(val) ... end)`。回调登记在栈上按位置取——
  `clipboard.get` 的回调在**第 1 参**（无必选首参），`storage.get` 在第 2 参，别照抄。
- `state.set(key, value)` 仅支持 string/number/boolean/nil。列表用
  `table.concat(t, "\n")` 序列化成字符串。
- 权限未声明时调用对应 API 直接抛 Lua 错误：`clipboard`→读写剪贴板、`storage`→持久化、
  `network`→HTTP。UI 事件里的 `copyToClipboard` action 走 DUI 层，**不需要**权限。
- 完整函数清单与签名见 `references/host-api.md`。

## 静态 UI 树的设计约束

- **没有循环/动态子组件**：ui.json 是静态树，动态条目只能用固定槽位
  （每个槽位 `visible: "{{state.xset}}"` 控制显隐）或整块文本渲染。
- **溢出零容忍**：`Row` 不换行，超宽即 RenderFlex overflow（硬错误）。按钮过多时拆成
  多行（每行 ≤2-3 个短文本按钮）或改用 `ListView`+`ListTile`。
- 组件/图标/文本样式均为**白名单**，未知类型静默渲染为空白（不报错、极难察觉）——
  图标只认 `content_copy`、`qr_code`、`search`、`check` 等固定集合，写错不报错只显示
  默认图标。全集见 `references/dui-widgets.md`，lint 会自动校验。
- 所有 `{{state.key}}` 引用与 `visible` 布尔键必须在 `onInit` 显式初始化，否则首帧
  表现为空串/不可见且无任何报错。

## 开发-验证工作流（离线，不依赖真机）

现成工具在 `PTX-plugins/dev/`（独立 Dart 包，`lua_dardo` 以 path 依赖指向宿主同源 VM）：

```bash
cd PTX-plugins/dev
dart pub get --offline
dart run bin/lint.dart        # 清单/UI AST/Lua 语法/事件↔函数交叉引用全量 lint
dart run bin/test_all.dart    # 插件逻辑断言（写插件时同步扩充此文件）
```

1. **先写 main.lua 的纯逻辑并暴露测试钩子**：以 `_` 前缀导出纯函数（如
   `_qr_matrix(text, ecl)`），harness 直接调用断言；UI 事件函数保持薄封装。
2. **lint 先行**：组件/图标/样式白名单、`visible` 语法、`callLua` 目标函数是否在
   main.lua 中定义、沙箱封禁库检查，全部自动校验。
3. **正确性验证用"真实消费方"当 oracle，而非另一个编码器逐字节比对**。
   qr_tool 的教训：segno 与本实现都是合法 QR，但掩码选择策略、终止符/补位顺序、
   自动编码探测（曾自动选 GBK）不同，逐字节比对永远"失败"；换 zxing 真实解码后
   12/12 通过。凡有真实消费方（解码器/解析器/渲染器），优先端到端验证其输出。
   参考工具链：`dev/bin/qr_dump.dart`（导出产物）+ `dev/decode_qr.py`（oracle 比对）。
4. **异步语义**：harness 桩（`dev/lib/host_stubs.dart`）把异步 API 实现为同步直调回调，
   与宿主契约等价；桩必须与生产绑定逐一同名同参（曾因回调栈位不同导致测试误判）。
   宿主对回调内的 Lua 错误静默吞掉，harness 桩则显式打印 `CALLBACK ERROR`——
   qr_tool 的模式匹配 bug 正是这样暴露的（空串捷径掩盖了 gmatch 路径）。

## 打包与真机

- 打包：`sample_plugins/pack.py` 只认 `sample_plugins/` 下的目录；PTX-plugins 下的插件
  用 `python PTX-plugins/pack.py [plugin_id]`（本地脚本，产物 `<id>.ptx` 与目录同级的
  `dist/`）。`.ptx` = ZIP，安装上限 10MB。
- 安装：宿主"插件管理 → 导入"走 FilePicker，可 `adb push *.ptx /sdcard/Download/` 后
  在真机上选取。真机截图用 `python tool/shots.py <name>`，检查溢出与主题色。
- 宿主改动（新增 API/组件）必须先过 AGENTS.md 验证门槛：`dart analyze` 0 issue、
  `dart run tool/verify.dart` 全过、五包 `flutter test` 全过。

## 参考文件

- `references/host-api.md` — 宿主 Lua API 全集与真实签名（含异步回调栈位）
- `references/dui-widgets.md` — DUI 组件/属性/图标/样式/事件 action 白名单全集
- `references/lua-dardo-quirks.md` — 沙箱坑位的复现记录与最小复现方法
- `PTX-plugins/dev/NOTES.md` — 同源坑位速查（简版）
- `PTX-plugins/plugin-source/qr_tool/` — 完整参考实现（纯算法插件 + 测试钩子模式）
