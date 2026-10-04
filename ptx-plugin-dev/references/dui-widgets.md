# DUI 组件与绑定白名单全集

来源：`packages/dui/lib/src/dui_renderer.dart` / `dui_utils.dart` / `dui_event_handler.dart`。
关键认知：**白名单之外的类型/图标/样式不报错**，渲染为空白或默认图标——靠 lint 抓。

## 布局类

| type | 主要 props | 备注 |
|---|---|---|
| Column / Row | `crossAxisAlignment`(start/end/center/stretch), `mainAxisAlignment`(start/end/center/spaceBetween), `mainAxisSize`(max/min) | Row 不换行, 谨防溢出 |
| Stack | alignment 固定 center | 不可配置 |
| Padding | `padding`(数字或 {left,top,right,bottom}) | |
| Center | — | |
| Expanded | `flex` | 只能作 Row/Column 直接子节点 |
| SizedBox | `width`, `height` | |
| SingleChildScrollView | `padding` | 常作根节点; 无 scrollDirection |
| Container | `padding`, `width`, `height`, `borderRadius`, `color`(`#RRGGBB`/`#AARRGGBB`) | color 可作色块预览 |
| Card | `elevation` | |
| ListView | `shrinkWrap`, `padding` | shrinkWrap 内嵌于滚动页 |

## 文本与输入

| type | 主要 props | 事件 |
|---|---|---|
| Text | `text`(支持 `{{state.k}}`), `style`, `maxLines`, `overflow`(仅 ellipsis) | — |
| SelectableText | `text`, `style` | — |
| TextField | `ref`(必填, 双向绑定 state key), `label`, `hint`, `maxLines`, `readOnly` | `onChanged` |

注意：TextField 的显示文本只在**重建时**从 ref 同步（didUpdateWidget 比较后覆盖），
Lua 侧写入同值不触发刷新。事件 `onChanged` 每次输入都会触发（含宿主写回引发的重建输入）。

## 按钮（事件一律 `onPressed`）

| type | props |
|---|---|
| FilledButton | `text`(支持插值), `icon` |
| OutlinedButton | `text`, `icon` |
| IconButton | `icon`, `tooltip` |

## 列表

| type | props | 事件 |
|---|---|---|
| ListView | `shrinkWrap`, `padding` | — |
| ListTile | `title`(插值), `subtitle`(插值), `leading`(仅图标名) | `onTap` |

## 图片

`Image`：`src` 为插件沙箱内相对路径（受路径穿越防御），`width`/`height`。
Lua 无法写文件 → 只能展示打进 .ptx 的静态资源。

## 图标白名单（其余一律降级为默认拼图图标）

code, qr_code, qr_code_scanner, phone_android, arrow_downward, arrow_upward,
swap_vert, content_copy, settings, delete_outline, search, check

## 文本样式白名单

displayLarge/Medium/Small, headlineLarge/Medium/Small, titleLarge/Medium/Small,
bodyLarge/Medium/Small, labelLarge

## 事件 action 白名单

| action | 参数 | 说明 |
|---|---|---|
| callLua | `function`, `args`(静态 JSON 数组) | 调用全局 Lua 函数 |
| setState | `key` | 把事件 payload 写入状态（输入框绑定用） |
| copyToClipboard | `text`(支持 `{{state.k}}` 插值) | 走 DUI 层, 不需要 clipboard 权限 |

## 模板与可见性语法

- 插值：`{{state.key}}`，可嵌入任意字符串属性（仅 Text/SelectableText/按钮 text 等
  渲染期取值的属性；布局 props 不做插值）。
- 可见性：节点级 `visible`，仅支持布尔字面量或**单个** `{{state.key}}`（不支持表达式）。
  key 值按真值判定：bool 原值、非空串为真、非零数字为真。
