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

宿主 API 语义以 `packages/lua/lib/src/api/*.dart` 生产实现为准（storage.get /
clipboard.get / network.get 均为异步回调式）。
