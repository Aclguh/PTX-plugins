# PTX-plugins 开发注意事项（lua_dardo 沙箱坑位清单 · 简版速查）

详细复现记录见 `../ptx-plugin-dev/references/lua-dardo-quirks.md`（skill 参考文件）。

1. **禁十六进制字面量**：`0x537` 编译报错，写十进制。
2. **禁对字符串用 `#`**：抛 `length error!`。长度用 `string.len`（字符数）。
3. **函数内多条件 `or` 守卫会被误编译** (chunk 顶层正常、函数体内整链失效):
   多条件拆嵌套 `if`, 且别写"守卫 return 后紧跟顶层调用表字段实参"。
4. **禁无值 `return`**：`then return end` 会被静默吞掉继续执行。必须 `return nil`。
5. **禁十进制转义 `\ddd`**：词法器崩溃。用 `\u{XXXX}`。
6. **模式匹配全家不可用**：`gmatch`/`gsub`/`match`/`reverse` 静默失效或 RangeError；
   `string.find` 只能纯文本模式（第 4 参 `true`）。分割/替换手写 `find+sub` 循环。
7. **禁用 `math.min`**：与 `math.max` 为同一份实现，行为等同于取大（min(8,9) 返回 9）。取小手写。
8. **字符串是字符语义**：`string.byte` 返回码点（emoji 为代理码元）。
   需要字节流的算法在 Lua 内显式做码点→UTF-8 编码（见 `../plugin-source/qr_tool/main.lua` 的 `strBytes`）。
9. **`string.format` 无 `%g`/`%e`**：只有 `c/i/d/o/u/x/X/f/s/q`。
10. **`os`/`io`/`debug`/`package`/`require` 被沙箱置空**：时间用 `util.timestamp*`。
11. **`state.set` 仅支持 string/number/boolean/nil**：列表用 `table.concat(.., "\n")` 序列化。
12. **UI 是静态 JSON 树，无循环/动态子组件**：动态条目用固定槽位（`visible` 绑定）
    或整块文本渲染。
13. **`/` 除法产生浮点，字符串索引函数拒绝浮点**（即使整值也抛
    `number has no integer representation`）：除法结果用作 `string.sub`/table 索引前
    必须 `math.floor`（floor 返回整数类型）。循环计数器与 `string.find` 返回值是整数，安全。
14. **`string.char` 仅接受 0..255**：码点建字符不可用 `string.char`，
    借 `json.decode('"\\uXXXX"')` 的 JSON 转义构造（增补平面拆代理对，见 unicode_tool）。
15. **回调内深嵌套块中的 `return` 有静默穿透风险**（实测 fx_tool 缓存分支：
    `return nil` 后仍继续执行了后续语句）：异步回调里避免早退结构，
    用 `used` 标志变量 + `if not used then` 收尾。
16. **多值接收变量数必须与失败路径的返回数对齐**：`local y, m, d, err = f(s)`
    若 `f` 失败只返回 `(nil, msg)` 两个值，则 msg 落在 `m`、`err` 恒为 nil。
17. **`tonumber` 非法串返回 nil**（不抛错），可放心用于输入校验；
    但 `tonumber("0x10")` 类进制前缀行为依实现，十进制校验用自写逐位检查更稳。

宿主 API 语义以 `packages/lua/lib/src/api/*.dart` 生产实现为准（storage.get /
clipboard.get / network.get 均为异步回调式）。
