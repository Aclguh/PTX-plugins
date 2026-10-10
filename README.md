# PTX-plugins — 本地动态插件开发空间

plugin-toolbox 宿主应用的本地 `.ptx` 插件开发目录，覆盖插件的编写、离线测试、打包与真机验证全流程。

**本目录已在主仓库 `.gitignore` 中排除**，属本地独立开发空间：不随宿主仓库分发，也不作为宿主版本的交付物。宿主仓库的 `sample_plugins/` 仅保留 `base64_tool`、`hash_tool` 两个官方基准样例，后续所有新增功能与生态插件一律开发在本目录。

---

## 目录结构

```
PTX-plugins/
├── plugin-source/          # 插件源码，每个子目录一个插件
│   └── <plugin_id>/
│       ├── plugin.json     # 插件清单（不是 manifest.json）
│       ├── main.lua        # 入口脚本（宿主加载后自动调用全局 onInit()）
│       └── ui/main.ui.json # 声明式 UI 树
├── dist/                   # pack.py 产物：<plugin_id>.ptx（ZIP，Deflate 压缩）
├── dev/                    # 离线测试 harness（独立 Dart 包）
│   ├── bin/
│   │   ├── lint.dart       # 静态 lint：清单 / UI AST 白名单 / 事件交叉引用 / Lua 语法
│   │   ├── test_all.dart   # 插件逻辑断言套件
│   │   ├── dbg.dart        # 单个 Lua chunk 直跑（复现沙箱坑位最小工具）
│   │   └── qr_dump.dart    # 导出 qr_tool 编码矩阵，供真实解码器 oracle 比对
│   └── lib/
│       ├── runner.dart     # PluginEnv 加载器 + 断言器 Checks
│       └── host_stubs.dart # 宿主 API 的同步直调桩（与生产绑定同语义）
├── ptx-plugin-dev/         # 插件开发实战 skill 与参考文档
│   ├── SKILL.md            # 开发前必读的实战经验
│   └── references/         # host-api.md / dui-widgets.md / lua-dardo-quirks.md
├── pack.py                 # 打包脚本
└── README.md
```

harness 以 path 依赖指向宿主同源的 Lua VM（`packages/third_party/lua_dardo`），与宿主运行环境完全一致；`crypto` 依赖仅用于复刻宿主 hash API 的语义。`dev/lib/host_stubs.dart` 与生产绑定逐一同名同参，含 `json` 编解码与 `network.post` 的同步直调镜像（网络响应经 `cannedResponses` / `cannedPosts` 预设）。

> **独立检出说明**：本仓库可单独克隆浏览插件源码与 `dist/` 产物；但 `dev/` 测试 harness 依赖宿主仓库 [plugin-toolbox](https://github.com/Aclguh/plugin-toolbox) 的 Lua VM（path 依赖指向其同级目录 `../../packages/third_party/lua_dardo`）。要在本地跑 lint / 逻辑断言，请将两个仓库并排检出（`plugin-toolbox` 与 `PTX-plugins` 位于同一父目录）。

---

## 插件清单

| 插件 | ID | 版本 | 分类 | 权限 |
|---|---|---|---|---|
| AI 代码审查与复杂度分析器 | `ai_code_reviewer_tool` | 1.0.0 | text | ai, clipboard |
| AI 技术求职面试官与陪练 | `ai_interviewer_tool` | 1.0.0 | text | ai, clipboard, storage |
| AI 思维导图与知识大纲生成器 | `ai_mindmap_tool` | 1.0.0 | text | ai, clipboard, storage |
| AI 发票票据识别与智能记账助手 | `ai_receipt_ocr_tool` | 1.0.0 | text | ai, clipboard, storage |
| AI 正则表达与解析大师 | `ai_regex_tool` | 1.0.0 | text | ai, clipboard |
| AI SQL 编写与优化器 | `ai_sql_helper` | 1.0.0 | text | ai, clipboard, storage |
| AI 多语言地道翻译对比 | `ai_translator_tool` | 1.0.0 | text | ai, clipboard |
| AI 随身助手与润色工具 | `ai_writer_tool` | 1.0.0 | text | ai, clipboard |
| 一维条形码生成器 | `barcode_tool` | 1.0.0 | generator | clipboard, storage |
| Base58 / Base32 编解码 | `base58_tool` | 1.0.0 | encoding | clipboard |
| Base64 编解码 | `base64_tool` | 1.1.0 | encoding | clipboard |
| BLE 蓝牙设备嗅探器 | `ble_scanner_tool` | 1.0.0 | network | bluetooth, clipboard |
| BMI 与体脂健康计算器 | `bmi_tool` | 1.0.0 | calculator | clipboard |
| 变量命名风格转换 | `case_convert_tool` | 1.0.0 | text | clipboard |
| 子网掩码与 CIDR 计算器 | `cidr_tool` | 1.0.0 | network | clipboard |
| 文本加密 | `cipher_tool` | 1.0.0 | encoding | clipboard |
| 人民币大写 | `cny_tool` | 1.0.0 | calculator | 无 |
| 色彩对比度与无障碍检测 | `color_contrast_tool` | 1.0.0 | calculator | clipboard |
| 颜色拾取器 | `color_picker_tool` | 1.0.0 | calculator | clipboard |
| 电子罗盘与水平仪 | `compass_level_tool` | 1.0.0 | system | sensor |
| 复利与定投计算器 | `compound_tool` | 1.0.0 | calculator | clipboard |
| CRC32 校验 | `crc32_tool` | 1.0.0 | encoding | 无 |
| Cron 表达式解析 | `cron_tool` | 1.0.0 | text | clipboard |
| CSS 样式与阴影生成器 | `css_tool` | 1.0.0 | generator | clipboard |
| CSV 与 JSON 互转 | `csv_tool` | 1.0.0 | text | clipboard |
| cURL 解析与代码转换 | `curl_tool` | 1.0.0 | network | clipboard |
| 日期计算器 | `date_tool` | 1.0.0 | calculator | 无 |
| 纪念日追踪 | `day_tool` | 1.0.0 | calculator | storage |
| 环境噪音分贝计 | `decibel_meter_tool` | 1.0.0 | system | microphone, storage, clipboard |
| 设备信息查看 | `device_info` | 1.0.0 | system | network |
| 随机骰子与决策 | `dice_tool` | 1.0.0 | other | 无 |
| 文本差异对比 | `diff_tool` | 1.0.0 | text | 无 |
| 量纲分析与单位计算器 | `dimension_calc_tool` | 1.0.0 | calculator | clipboard |
| DNS 查询 | `dns_tool` | 1.0.0 | network | network |
| 照片 EXIF 隐私检测与擦除 | `exif_cleaner_tool` | 1.0.0 | system | photo_library, storage, clipboard |
| 文件哈希校验 | `file_hash_tool` | 1.0.0 | calculator | storage, clipboard |
| 间隔重复记忆闪卡 | `flashcard_tool` | 1.0.0 | other | database, clipboard |
| 多功能手电与补光灯 | `flashlight_tool` | 1.0.0 | system | torch, screen |
| 汇率换算 | `fx_tool` | 1.0.0 | calculator | network, storage |
| Git 提交规范生成器 | `git_commit_tool` | 1.0.0 | generator | clipboard |
| 习惯养成与打卡追踪器 | `habit_tracker_tool` | 1.0.0 | other | database, clipboard |
| 哈希计算器 | `hash_tool` | 1.1.0 | encoding | clipboard |
| HMAC 签名计算 | `hmac_tool` | 1.0.0 | encoding | clipboard |
| HTML 实体编解码 | `html_entity_tool` | 1.0.0 | encoding | clipboard |
| HTTP 状态码与 MIME 词典 | `http_status_tool` | 1.0.0 | network | clipboard |
| HTTP 请求调试 | `http_tool` | 1.0.0 | network | network |
| 车载 HUD 抬头数字测速仪与超速预警 | `hud_speedometer_tool` | 1.0.0 | system | location, screen, sensor, clipboard |
| 证件照尺寸与排版助手 | `id_photo_helper` | 1.0.0 | calculator | clipboard |
| 图片压缩与属性查看器 | `image_compress_tool` | 1.0.0 | system | photo_library, storage, clipboard |
| 倾角与水平仪量角器 | `inclinometer_tool` | 1.0.0 | system | sensor, clipboard |
| IP 归属地查询 | `ip_tool` | 1.0.0 | network | network |
| JSON 工具 | `json_tool` | 1.0.0 | text | clipboard |
| JWT 解析 | `jwt_tool` | 1.0.0 | text | 无 |
| 亲戚称谓换算 | `kinship_tool` | 1.0.0 | calculator | clipboard |
| 局域网探测与端口扫描器 | `lan_scanner_tool` | 1.0.0 | network | network, clipboard, storage |
| 极简 SQLite 记账本 | `ledger_tool` | 1.0.0 | calculator | database, storage, clipboard |
| 行文本处理 | `line_tool` | 1.0.0 | text | clipboard |
| Linux 常用命令速查 | `linux_cheat_tool` | 1.0.0 | other | clipboard |
| 贷款计算器 | `loan_tool` | 1.0.0 | calculator | 无 |
| 环境光照度计与摄影测光 EV 助手 | `lux_meter_tool` | 1.0.0 | calculator | sensor, clipboard, storage |
| Markdown 表格格式化 | `md_table_tool` | 1.0.0 | text | clipboard |
| 备忘录 | `memo_tool` | 1.0.0 | other | storage |
| 磁力计金属探测与磁场强度计 | `metal_detector_tool` | 1.0.0 | system | sensor, clipboard, storage |
| 节拍器与节奏训练器 | `metronome_tool` | 1.0.0 | system | screen |
| 模拟测试数据生成器 | `mock_data_tool` | 1.0.0 | generator | clipboard |
| 摩斯电码光信号发射器 | `morse_light_tool` | 1.0.0 | system | torch, clipboard |
| 摩尔斯电码 | `morse_tool` | 1.0.0 | encoding | 无 |
| MQTT 与物联网长连接调试器 | `mqtt_debugger_tool` | 1.0.0 | network | network, clipboard |
| NFC 电子名片与快捷写入器 | `nfc_smart_tag` | 1.0.0 | system | nfc, clipboard |
| NFC 标签读写多功能箱 | `nfc_toolbox` | 1.0.0 | system | nfc, clipboard |
| 离线 OCR 文字识别 | `ocr_tool` | 1.0.0 | system | camera, photo_library, storage, clipboard |
| 调色板与配色方案生成器 | `palette_generator_tool` | 1.0.0 | generator | clipboard |
| 中英排版美化 (盘古之白) | `pangu_tool` | 1.0.0 | text | clipboard |
| 密码与安全凭证备忘本 | `pass_vault_tool` | 1.0.0 | system | biometrics, database, clipboard |
| 随机密码生成 | `password_tool` | 1.0.0 | generator | 无 |
| 朋友圈九宫格切图与长图拼接助手 | `photo_grid_tool` | 1.0.0 | generator | clipboard, storage, camera, photo_library |
| 番茄时钟 (专注计时) | `pomodoro_tool` | 1.0.0 | other | storage |
| Protobuf 二进制逆向解析器 | `protobuf_decoder_tool` | 1.0.0 | encoding | clipboard |
| 扫码识别 | `qr_scanner_tool` | 1.0.0 | system | camera, storage, clipboard |
| 二维码生成 | `qr_tool` | 1.1.0 | generator | clipboard, storage |
| 进制转换器 | `radix_tool` | 1.0.0 | calculator | 无 |
| 正则测试 | `regex_tool` | 1.0.0 | text | clipboard |
| 屏幕坏点与漏光检测器 | `screen_tester_tool` | 1.0.0 | system | screen |
| 生物认证隐私保险箱 | `secret_vault_tool` | 1.0.0 | system | biometrics, storage, clipboard |
| 微震动监测仪与微型地震记录仪 | `seismograph_tool` | 1.0.0 | system | sensor, clipboard, storage |
| 摇一摇抽签决策箱 | `shake_draw_tool` | 1.0.0 | other | sensor, clipboard |
| 手写签名板 | `signature_tool` | 1.0.0 | other | storage, clipboard |
| 聚餐分摊 (AA记账) | `split_bill_tool` | 1.0.0 | calculator | clipboard |
| SQL 交互演练台与查询器 | `sql_playground_tool` | 1.0.0 | other | database, clipboard |
| SSL证书查询与过期监控 | `ssl_cert_tool` | 1.0.0 | network | network, storage, clipboard |
| 数独求解与练习台 | `sudoku_solver_tool` | 1.0.0 | other | clipboard |
| 个税计算器 | `tax_tool` | 1.0.0 | calculator | 无 |
| 宏量营养素与 TDEE 饮食规划 | `tdee_tool` | 1.0.0 | calculator | clipboard |
| 文本统计 | `text_stats_tool` | 1.0.0 | text | 无 |
| 时间戳转换 | `timestamp_tool` | 1.0.0 | calculator | clipboard |
| 音频频率发生器与调音器 | `tone_generator_tool` | 1.0.0 | system | 无 |
| 2FA 动态令牌 | `totp_tool` | 1.0.0 | generator | storage, clipboard |
| 命题逻辑与真值表生成器 | `truth_table_tool` | 1.0.0 | calculator | clipboard |
| User-Agent 解析 | `ua_tool` | 1.0.0 | text | clipboard |
| Unicode 码点查询 | `unicode_tool` | 1.0.0 | text | 无 |
| 单位换算 | `unit_tool` | 1.0.0 | calculator | 无 |
| URL 解析器 | `url_tool` | 1.0.0 | text | clipboard |
| UUID 生成器 | `uuid_tool` | 1.0.0 | generator | 无 |
| 证件隐私防盗水印与全屏文字盖印 | `watermark_tool` | 1.0.0 | text | clipboard, storage, camera, photo_library |
| 实时天气查询 | `weather_tool` | 1.0.0 | network | network, storage, clipboard |
| 助眠白噪音与多频段混音发生器 | `white_noise_tool` | 1.0.0 | other | clipboard, storage, notification |
| 域名 WHOIS 查询 | `whois_tool` | 1.0.0 | network | network, clipboard |
| 世界时钟与时区换算 | `world_clock_tool` | 1.0.0 | calculator | clipboard |
| WebSocket 实时调试终端 | `ws_debugger_tool` | 1.0.0 | network | network, clipboard |
| 零宽字符隐写 | `zero_width_tool` | 1.0.0 | encoding | clipboard |

参考实现：`base64_tool` 为最小样例；`qr_tool` / `barcode_tool` 为纯算法条码图形实战参考；`fx_tool` / `ssl_cert_tool` / `lan_scanner_tool` 为联网、证书及局域网嗅探实战；`jwt_tool` / `protobuf_decoder_tool` 为协议与二进制解码参考；`ocr_tool` / `ai_receipt_ocr_tool` 为机器视觉与智能票据识别实战；`decibel_meter_tool` / `white_noise_tool` / `tone_generator_tool` 为音频感知与合成实战；`compass_level_tool` / `inclinometer_tool` / `hud_speedometer_tool` / `metal_detector_tool` / `seismograph_tool` / `lux_meter_tool` 为车载导航、磁力、加速度计及环境光学传感器实战；`ledger_tool` / `sql_playground_tool` / `flashcard_tool` 为独立 SQLite 关系型数据库实战；`ble_scanner_tool` 为低功耗蓝牙嗅探实战；`nfc_toolbox` / `nfc_smart_tag` 为近场通信 NDEF 读写实战；`secret_vault_tool` / `pass_vault_tool` 为生物认证硬件级隐私防护实战；`ws_debugger_tool` / `mqtt_debugger_tool` 为全双工长连接实战；`ai_writer_tool` / `ai_regex_tool` / `ai_translator_tool` / `ai_code_reviewer_tool` / `ai_sql_helper` / `ai_interviewer_tool` / `ai_mindmap_tool` 为大语言模型 AI 网关实战；`truth_table_tool` / `sudoku_solver_tool` / `dimension_calc_tool` / `color_contrast_tool` 为形式逻辑、高精度物理量纲与算法回溯实战；`photo_grid_tool` / `watermark_tool` 为社交拼图与隐私安全防盗盖印实战。

---

## 开发工作流

开发任何插件前，先读 `ptx-plugin-dev/SKILL.md`——其中记录了宿主 Lua API 的真实语义与 lua_dardo 沙箱的全部坑位，均来自实测复现而非文档转述。

**1. 编写插件源码**：在 `plugin-source/<plugin_id>/` 下按包结构创建 `plugin.json`、`main.lua`、`ui/main.ui.json`。清单 `id` 必须与目录名一致（正则 `^[a-z0-9_]{3,50}$`）。

**2. 静态 lint**（清单合规、UI 组件/图标/样式白名单、`callLua` 目标函数交叉引用、沙箱封禁库检查）：

```bash
cd PTX-plugins/dev
dart pub get --offline   # 首次
dart run bin/lint.dart
```

**3. 逻辑断言**（模拟 UI 事件调用，断言插件状态输出；新增插件时在 `test_all.dart` 追加 group）：

```bash
cd PTX-plugins/dev
dart run bin/test_all.dart
```

**4. 单点调试**（直跑单个 Lua chunk，复现沙箱坑位）：

```bash
cd PTX-plugins/dev
dart run bin/dbg.dart ../plugin-source/<plugin_id>/main.lua
```

**5. 打包**（产物输出到 `dist/`，`.ptx` 即 ZIP，安装上限 10MB）：

```bash
python PTX-plugins/pack.py            # 打包全部
python PTX-plugins/pack.py qr_tool    # 打包指定插件
```

**6. 真机安装与验证**：

```bash
adb push PTX-plugins/dist/*.ptx /sdcard/Download/   # 推送到设备
# 宿主「插件管理 → 导入」经 FilePicker 选取安装
python tool/shots.py <name>                          # 仓库根目录执行，真机截图校验
```

真机检查项：严禁布局溢出（`RenderFlex overflowed`）、主背景 `#26366A`、主字体色 `#B4C9FF`。

---

## lua_dardo 沙箱要点

宿主 VM 为 Lua 5.1 语义 + 单次调用 500 万指令预算。以下条目每个都曾真实引发 bug，写 Lua 前务必内化（完整复现记录见 `ptx-plugin-dev/references/lua-dardo-quirks.md`，速查见 `dev/NOTES.md`）：

- **禁十六进制字面量**（`0x537`），写十进制。
- **禁对字符串用 `#`**（抛 `length error!`），长度一律 `string.len`。
- **禁无值 `return`**（裸 return 被 VM 静默吞掉，最危险的控制流陷阱），必须 `return nil`。
- **模式匹配全家不可用**（`gmatch`/`gsub`/`match`/`reverse` 静默失效或 RangeError），只能用 `string.find(s, sub, init, true)` 纯文本模式 + `string.sub` 手写循环。
- **禁用 `math.min`**（与 `math.max` 为同一份实现，行为等同于取大），取小手写。
- **字符串是字符语义而非字节**：`string.byte` 返回码点，需要字节流的算法（QR/哈希/Base64 自实现）必须显式做码点到 UTF-8 的编码。
- **`os`/`io`/`debug`/`package`/`require` 被置空**：时间用 `util.timestamp`/`util.timestampMs`，历法换算在插件内自实现。
- **UI 是静态 JSON 树**：没有循环或动态子组件，动态条目用固定槽位 + `visible` 绑定或整块文本渲染；未知组件类型静默渲染为空白，写错不报错。

宿主 API（`state`/`dialog`/`clipboard`/`storage`/`network`/`codec`/`hash`/`util`/`system`）的真实签名与异步回调栈位见 `ptx-plugin-dev/references/host-api.md`；DUI 组件、图标、样式与事件 action 的白名单全集见 `ptx-plugin-dev/references/dui-widgets.md`。

---

## 注意事项

- **测试边界**：插件业务逻辑的正确性由本空间的 `dev/` 套件保障；宿主仓库（`packages/*`、`app`）的测试严禁断言任何插件的具体业务结果，两者严格解耦（见主仓库 `AGENTS.md` 测试规范）。
- **以生产代码为准**：宿主 Lua API、DUI 渲染器、清单字段的任何文档描述若与生产实现冲突，一律以 `packages/lua/lib/src/api/*.dart`、`packages/dui/lib/src/dui_renderer.dart`、`packages/core/lib/src/model/plugin_manifest.dart` 为准。
- **宿主改动门槛**：为插件新增宿主 API 或组件时，必须先补宿主实现并通过主仓库验证门槛（`dart analyze` 0 issue、`dart run tool/verify.dart` 全过、五包 `flutter test` 全过），再回来写插件。
- **正确性验证优先用真实消费方当 oracle**：qr_tool 的教训是逐字节比对两个合法编码器永远无法收敛（掩码策略、终止符顺序、自动编码探测均可能不同），应换真实解码器端到端验证（参考 `dev/bin/qr_dump.dart` + `dev/decode_qr.py`）。
- **同 id 重复安装等于整目录替换**，可当作插件的"更新"通道使用。
