import 'dart:convert';

import 'dart:io';

import 'package:ptx_dev_harness/runner.dart';

/// PTX-plugins 插件逻辑断言套件。
/// 新增插件时在此追加 group：加载 PluginEnv、模拟 UI 事件调用、断言状态输出。
/// 业务断言允许且应当写在这里（宿主 packages/* 测试才禁止插件业务断言）。
void main() {
  // ============================================================
  // qr_tool
  // ============================================================
  final qr = PluginEnv.load('../plugin-source/qr_tool');
  Checks.group('qr_tool 生成与状态流');
  qr.host.stateValues['qrText'] = 'https://plugin.toolbox';
  qr.call('generateQr');
  Checks.check(qr.host.stateValues['hasResult'] == true, 'qr: 正常内容生成成功');
  final pixels = qr.host.stateValues['qrPixels'] as String? ?? '';
  final cols = qr.host.stateValues['qrCols'] as int? ?? 0;
  Checks.check(cols > 0 && pixels.length == cols * cols, 'qr: 位图长度与列数平方一致');
  final cell = qr.host.stateValues['qrCell'];
  Checks.check(cell is int && cell >= 4 && cell <= 8, 'qr: 单格尺寸为 4-8 的整数');
  Checks.check(!pixels.substring(0, cols).contains('1'), 'qr: 顶部静区全为亮模块');
  Checks.check(pixels.substring(7 * cols + 7, 7 * cols + 8) == '1',
      'qr: 左上定位图形中心为暗模块');
  qr.host.stateValues['qrText'] = '';
  qr.call('generateQr');
  Checks.check(qr.host.stateValues['hasError'] == true, 'qr: 空输入进入错误态');
  qr.host.stateValues['qrText'] = 'y' * 500;
  qr.call('generateQr');
  Checks.check(qr.host.stateValues['hasError'] == true, 'qr: 超长输入进入错误态');
  qr.host.stateValues['qrText'] = 'https://plugin.toolbox/history-test';
  qr.call('generateQr');
  qr.call('saveCurrentToHistory');
  Checks.check(qr.host.storageBox.containsKey('history_v1'), 'qr: 历史写入沙箱存储');
  final qr2 = PluginEnv.load('../plugin-source/qr_tool');
  qr2.host.storageBox['history_v1'] = qr.host.storageBox['history_v1']!;
  qr2.call('onInit');
  Checks.check(qr2.host.stateValues['hasHistory'] == true, 'qr: onInit 恢复历史');

  // ============================================================
  // base64_tool
  // ============================================================
  final b64 = PluginEnv.load('../plugin-source/base64_tool');
  Checks.group('base64_tool 编解码');
  b64.host.stateValues['inputText'] = '你好';
  b64.call('encode');
  Checks.check(b64.host.stateValues['resultText'] == '5L2g5aW9', 'b64: 中文编码');
  b64.host.stateValues['inputText'] = '5L2g5aW9';
  b64.call('decode');
  Checks.check(b64.host.stateValues['resultText'] == '你好', 'b64: 中文解码');
  b64.host.stateValues['inputText'] = '!!!not-base64!!!';
  b64.call('decode');
  Checks.check(b64.host.stateValues['hasError'] == true, 'b64: 非法输入进入错误态');
  b64.host.stateValues['inputText'] = 'a b&c=1';
  b64.call('urlEncode');
  Checks.check(b64.host.stateValues['resultText'] == 'a%20b%26c%3D1',
      'b64: URL 编码');
  b64.host.stateValues['inputText'] = 'a%20b%26c%3D1';
  b64.call('urlDecode');
  Checks.check(b64.host.stateValues['resultText'] == 'a b&c=1', 'b64: URL 解码');
  b64.host.clipboardText = '粘贴内容';
  b64.call('pasteInput');
  Checks.check(b64.host.stateValues['inputText'] == '粘贴内容', 'b64: 剪贴板粘贴');
  b64.host.stateValues['inputText'] = 'A';
  b64.host.stateValues['resultText'] = 'B';
  b64.call('swapText');
  Checks.check(b64.host.stateValues['inputText'] == 'B', 'b64: 内容对调');

  // ============================================================
  // hash_tool
  // ============================================================
  final hashEnv = PluginEnv.load('../plugin-source/hash_tool');
  Checks.group('hash_tool 哈希计算');
  hashEnv.host.stateValues['input'] = 'abc';
  hashEnv.call('calculate');
  Checks.check(hashEnv.host.stateValues['md5Val'] == '900150983cd24fb0d6963f7d28e17f72',
      'hash: md5(abc) 小写');
  hashEnv.call('toggleCase');
  Checks.check(hashEnv.host.stateValues['md5Val'] == '900150983CD24FB0D6963F7D28E17F72',
      'hash: 大写切换后重算');
  hashEnv.host.clipboardText = 'hello';
  hashEnv.call('pasteInput');
  Checks.check(hashEnv.host.stateValues['input'] == 'hello', 'hash: 剪贴板粘贴');

  // ============================================================
  // uuid_tool
  // ============================================================
  final uuid = PluginEnv.load('../plugin-source/uuid_tool');
  Checks.group('uuid_tool 生成与格式');
  uuid.host.stateValues['genCount'] = '5';
  uuid.call('generate');
  final display = uuid.host.stateValues['uuidDisplay'] as String? ?? '';
  Checks.check(display.split('\n').length == 5, 'uuid: 批量生成 5 条');
  // ignore: avoid_print
  print('UUIDDBG [${display.split('\n').first}]');
  Checks.check(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
          .hasMatch(display.split('\n').first), 'uuid: v4 格式与版本位');
  final up = uuid.eval('return _uuidFormat("aB12-CD", "upper")');
  Checks.check(up == 'AB12-CD', 'uuid: 大写格式');
  final nodash = uuid.eval('return _uuidFormat("aB12-CD", "nodash")');
  Checks.check(nodash == 'aB12CD', 'uuid: 无连字符格式');
  final brace = uuid.eval('return _uuidFormat("ab12", "brace")');
  Checks.check(brace == '{AB12}', 'uuid: 花括号格式');
  uuid.host.stateValues['genCount'] = '500';
  uuid.call('generate');
  Checks.check((uuid.host.stateValues['uuidDisplay'] as String).split('\n').length == 100,
      'uuid: 批量上限 100');

  // ============================================================
  // unit_tool
  // ============================================================
  final unit = PluginEnv.load('../plugin-source/unit_tool');
  Checks.group('unit_tool 单位换算');
  final km = unit.eval(
      'return _convert("length", 3, 4, 1)') as Map<String, dynamic>;
  Checks.check(km['text'] == '0.001', 'unit: 米转千米');
  final f = unit.eval('return _convert("temp", 1, 2, 100)') as Map<String, dynamic>;
  Checks.check((f['v'] as num).toDouble() == 212.0, 'unit: 摄氏 100 度转华氏 212 度');
  final jin = unit.eval(
      'return _convert("weight", 3, 7, 2)') as Map<String, dynamic>;
  Checks.check(((jin['v'] as num) - 4).abs() < 1e-9, 'unit: 2 千克转 4 斤');
  final tb = unit.eval('return _convert("data", 2, 6, 1)') as Map<String, dynamic>;
  Checks.check(tb['text'] == '9.0949e-13', 'unit: 1 字节转 TB 科学计数');
  Checks.check(unit.host.stateValues['catLabel'] != null, 'unit: 默认分类已加载');
  unit.host.stateValues['inputValue'] = '5';
  unit.call('selectCategory');
  unit.host.stateValues['inputValue'] = '2';
  unit.call('tapFrom');
  Checks.check(unit.host.stateValues['resultText'] != null, 'unit: 换算状态输出');

  // ============================================================
  // timestamp_tool
  // ============================================================
  final ts = PluginEnv.load('../plugin-source/timestamp_tool');
  Checks.group('timestamp_tool 时间戳转换');
  Checks.check(ts.eval('return _formatEpoch(0, 0)') == '1970-01-01 00:00:00 星期四',
      'ts: 纪元起点与星期');
  Checks.check(ts.eval('return _formatEpoch(1000000000, 0)') == '2001-09-09 01:46:40 星期日',
      'ts: 十亿秒');
  Checks.check(ts.eval('return _formatEpoch(1727654400, 480)') == '2024-09-30 08:00:00 星期一',
      'ts: 时区偏移 UTC+8');
  Checks.check(ts.eval('return _dateToEpoch(2024, 2, 29, 0, 0, 0)') == 1709164800,
      'ts: 闰年 2 月 29 日');
  Checks.check(ts.eval('return _dateToEpoch(1970, 1, 1, 0, 0, 0)') == 0,
      'ts: UTC 纪元起点');
  Checks.check(ts.eval('return _dateToEpoch(1970, 1, 1, 8, 0, 0)') == 28800,
      'ts: 当日八时');
  ts.host.stateValues['tsInput'] = '1709164800000';
  ts.call('tsToDate');
  Checks.check(ts.host.stateValues['hasTsResult'] == true, 'ts: 毫秒识别成功');
  Checks.check((ts.host.stateValues['tsResult'] as String).contains('毫秒'),
      'ts: 毫秒标注');
  ts.host.stateValues['tsInput'] = 'abc';
  ts.call('tsToDate');
  Checks.check(ts.host.stateValues['hasError'] == true, 'ts: 非法输入报错');
  ts.host.stateValues['dY'] = '2023';
  ts.host.stateValues['dMo'] = '2';
  ts.host.stateValues['dD'] = '29';
  ts.call('dateToTs');
  Checks.check(ts.host.stateValues['hasError'] == true, 'ts: 平年 2 月 29 日被拒');

  // ============================================================
  // diff_tool
  // ============================================================
  final diff = PluginEnv.load('../plugin-source/diff_tool');
  Checks.group('diff_tool 文本差异');
  final d1 = diff.eval('return _diffLines("a\\nb\\nc", "a\\nc\\nd")')
      as Map<String, dynamic>;
  Checks.check(d1['added'] == 1 && d1['removed'] == 1 && d1['same'] == 2,
      'diff: 基础增删统计');
  final d2 = diff.eval('return _diffLines("x\\ny", "x\\ny")') as Map<String, dynamic>;
  Checks.check(d2['added'] == 0 && d2['removed'] == 0 && d2['same'] == 2, 'diff: 相同文本');
  final d3 = diff.eval('return _diffLines("", "a")') as Map<String, dynamic>;
  Checks.check(d3['added'] == 1 && d3['removed'] == 0 && d3['same'] == 0, 'diff: 空侧全为新增');
  final d4 = diff.eval('return _diffLines("中文一\\n中文二", "中文一\\n中文三")')
      as Map<String, dynamic>;
  Checks.check(d4['added'] == 1 && d4['removed'] == 1, 'diff: 中文行级对比');
  final long1 = List.generate(500, (i) => 'l$i').join('\n');
  final d5 = diff.eval('return _diffLines(${json.encode(long1)}, "a")');
  Checks.check(d5 == null, 'diff: 超限拒绝');

  // ============================================================
  // color_picker_tool
  // ============================================================
  final color = PluginEnv.load('../plugin-source/color_picker_tool');
  Checks.group('color_picker_tool 颜色换算');
  // Lua 表在 Dart 侧统一呈现为字符串键 Map
  final c1 = color.eval('return _parseHex("#26366A")') as Map<String, dynamic>;
  Checks.check(c1['r'] == 38 && c1['g'] == 54 && c1['b'] == 106 && c1['a'] == 255,
      'color: HEX 解析 RGB 与 Alpha');
  final c2 = color.eval('return _parseHex("#F0A")') as Map<String, dynamic>;
  Checks.check(c2['r'] == 255 && c2['g'] == 0 && c2['b'] == 170, 'color: #RGB 短格式展开');
  final badHex = color.eval('return _parseHex("#GGG")') as Map<String, dynamic>;
  Checks.check(badHex['ok'] == false, 'color: 非法输入拒绝');
  Checks.check(color.eval('return _luminance(255, 255, 255)') == 1.0, 'color: 白色亮度 1');
  Checks.check(color.eval('return _luminance(0, 0, 0)') == 0.0, 'color: 黑色亮度 0');
  Checks.check((color.eval('return _contrast(1, 0)') as num).round() == 21,
      'color: 黑白对比度 21:1');
  final hsl = color.eval('return {_rgbToHsl(255, 0, 0)}') as Map<String, dynamic>;
  Checks.check(hsl['1'] == 0 && hsl['3'] == 50.0, 'color: 红色 HSL');
  color.host.stateValues['hexInput'] = '#26366A';
  color.call('applyHex');
  Checks.check(color.host.stateValues['swatchHex'] == '#26366A', 'color: 色块状态写入');
  Checks.check((color.host.stateValues['adviceText'] as String).contains('白'),
      'color: 深色建议白字');
  color.host.stateValues['hexInput'] = 'oops';
  color.call('applyHex');
  Checks.check(color.host.stateValues['hasError'] == true, 'color: 非法色值报错');

  // ============================================================
  // device_info
  // ============================================================
  final dev = PluginEnv.load('../plugin-source/device_info');
  Checks.group('device_info 设备信息');
  Checks.check(dev.host.stateValues['platform'] == 'android', 'dev: 平台读取');
  Checks.check(dev.host.stateValues['cores'] == '8 核', 'dev: 核数读取');
  Checks.check((dev.host.stateValues['screenText'] as String).contains('1080 x 2400'),
      'dev: 屏幕信息读取');
  Checks.check((dev.host.stateValues['brightnessText'] as String) == '深色', 'dev: 外观读取');
  final ip = dev.eval('return _extractField(\'{"query":"1.2.3.4","isp":"电信"}\', "query")');
  Checks.check(ip == '1.2.3.4', 'dev: 扁平 JSON 字段提取');
  dev.host.cannedResponses['http://ip-api.com/json/?lang=zh-CN&fields=query,country,regionName,city,isp,timezone'] =
      {'status': '200', 'body': '{"query":"9.9.9.9","country":"中国","city":"深圳","isp":"电信","timezone":"Asia/Shanghai"}'};
  dev.call('queryIp');
  Checks.check((dev.host.stateValues['ipInfo'] as String).contains('9.9.9.9'),
      'dev: 网络查询回调链路');

  // ============================================================
  // json_tool
  // ============================================================
  final js = PluginEnv.load('../plugin-source/json_tool');
  Checks.group('json_tool 格式化与校验');
  final prettyOut = js.eval(
      'return _jsonFormat(\'{"a":[1,2],"b":"x"}\', 2)') as String?;
  Checks.check(prettyOut ==
      '{\n  "a": [\n    1,\n    2\n  ],\n  "b": "x"\n}', 'json: 标准缩进格式化');
  final mini = js.eval(
      'return _jsonMinify(\'{ "a" : [ 1 , 2 ] , "b" : "x" }\')') as String?;
  Checks.check(mini == '{"a":[1,2],"b":"x"}', 'json: 压缩去空白');
  final miniRound = js.eval(
      'local formatted = _jsonFormat(\'{"k":[3,{"n":null}]}\', 4) return _jsonMinify(formatted)') as String?;
  Checks.check(miniRound == '{"k":[3,{"n":null}]}', 'json: 格式化压缩往返一致');
  final bad1 = js.eval('return _jsonFormat(\'{"a":}\', 2)');
  Checks.check(bad1 == null, 'json: 非法值拒绝');
  final bad2 = js.eval('return _jsonFormat(\'{"a":1}垃圾\', 2)');
  Checks.check(bad2 == null, 'json: 尾部多余内容拒绝');
  final bad3 = js.eval('return _jsonFormat(\'{"a":"\\\\u00zz"}\', 2)');
  Checks.check(bad3 == null, 'json: 非法 unicode 转义拒绝');
  final uni = js.eval(
      'return _jsonMinify(\'{"e":"\\\\u4F60"}\')') as String?;
  Checks.check(uni == '{"e":"\\u4F60"}', 'json: unicode 转义原样保留');
  // 状态流
  js.host.stateValues['jsonInput'] = '{"x":1}';
  js.call('formatJson');
  Checks.check(js.host.stateValues['hasOutput'] == true, 'json: 状态流输出');
  Checks.check((js.host.stateValues['jsonInfo'] as String).contains('object'),
      'json: 统计信息');

  // ============================================================
  // regex_tool
  // ============================================================
  final rx = PluginEnv.load('../plugin-source/regex_tool');
  Checks.group('regex_tool 迷你正则引擎');
  rx.host.stateValues['patternStr'] = r'\d+';
  rx.host.stateValues['subjectStr'] = 'a12b345';
  rx.call('findAll');
  Checks.check((rx.host.stateValues['allResult'] as String).contains('共 2 处匹配'),
      'rx: 数字序列查找');
  rx.host.stateValues['patternStr'] = r'(\w+)@(\w+)\.com';
  rx.host.stateValues['subjectStr'] = 'hi: tom@site.com';
  rx.call('findAll');
  final mail = rx.host.stateValues['allResult'] as String;
  Checks.check(mail.contains('tom@site.com'), 'rx: 邮箱整体匹配');
  Checks.check(mail.contains(r'$1=tom'), 'rx: 捕获组 1');
  Checks.check(mail.contains(r'$2=site'), 'rx: 捕获组 2');
  rx.host.stateValues['patternStr'] = '中+';
  rx.host.stateValues['subjectStr'] = 'A中中中B';
  rx.call('findAll');
  Checks.check((rx.host.stateValues['allResult'] as String).contains('中中中'),
      'rx: 中文按码点匹配');
  rx.host.stateValues['patternStr'] = r'^abc$';
  rx.host.stateValues['subjectStr'] = 'abc';
  rx.call('testMatch');
  Checks.check((rx.host.stateValues['matchResult'] as String).contains('匹配'),
      'rx: 锚点匹配');
  rx.host.stateValues['subjectStr'] = 'xabc';
  rx.call('testMatch');
  Checks.check((rx.host.stateValues['matchResult'] as String).contains('未匹配'),
      'rx: 锚点拒绝');
  rx.host.stateValues['patternStr'] = r'<.+>';
  rx.host.stateValues['subjectStr'] = '<a><b>';
  rx.call('findAll');
  Checks.check((rx.host.stateValues['allResult'] as String).contains('1. [1-6] <a><b>'),
      'rx: 贪婪量词');
  rx.host.stateValues['patternStr'] = r'<.+?>';
  rx.call('findAll');
  Checks.check((rx.host.stateValues['allResult'] as String).contains('<a>') &&
      (rx.host.stateValues['allResult'] as String).contains('<b>'),
      'rx: 懒惰量词');
  rx.host.stateValues['patternStr'] = 'cat|dog';
  rx.host.stateValues['subjectStr'] = 'a dog and 2 cats';
  rx.call('findAll');
  Checks.check((rx.host.stateValues['allResult'] as String).contains('共 2 处匹配'),
      'rx: 或分支');
  rx.host.stateValues['patternStr'] = r'\bword\b';
  rx.host.stateValues['subjectStr'] = 'a word here, keywords';
  rx.call('findAll');
  Checks.check((rx.host.stateValues['allResult'] as String).contains('共 1 处匹配'),
      'rx: 词边界');
  rx.host.stateValues['patternStr'] = '[a-c]+';
  rx.host.stateValues['subjectStr'] = 'xxabcabyy';
  rx.call('findAll');
  Checks.check((rx.host.stateValues['allResult'] as String).contains('abcab'),
      'rx: 字符类范围');
  rx.host.stateValues['patternStr'] = r'[^0-9]+';
  rx.host.stateValues['subjectStr'] = '12ab34';
  rx.call('findAll');
  Checks.check((rx.host.stateValues['allResult'] as String).contains('ab'),
      'rx: 否定字符类');
  rx.host.stateValues['patternStr'] = 'hello';
  rx.host.stateValues['subjectStr'] = 'SAY HELLO';
  rx.host.stateValues['caseOn'] = true;
  rx.call('findAll');
  Checks.check((rx.host.stateValues['allResult'] as String).contains('HELLO'),
      'rx: 忽略大小写');
  rx.host.stateValues['caseOn'] = false;
  // 替换
  rx.host.stateValues['patternStr'] = r'(\d{4})-(\d{2})-(\d{2})';
  rx.host.stateValues['subjectStr'] = '日期: 2024-09-30 结束';
  rx.host.stateValues['replaceStr'] = r'$3/$2/$1';
  rx.call('replacePreview');
  Checks.check((rx.host.stateValues['replaceResult'] as String).contains('30/09/2024'),
      'rx: 替换捕获组重排');
  // 非法模式
  rx.host.stateValues['patternStr'] = '(a';
  rx.call('findAll');
  Checks.check(rx.host.stateValues['hasError'] == true, 'rx: 括号未闭合报错');
  rx.host.stateValues['patternStr'] = '*a';
  rx.call('findAll');
  Checks.check(rx.host.stateValues['hasError'] == true, 'rx: 量词无主体报错');

  // ============================================================
  // radix_tool
  // ============================================================
  final radix = PluginEnv.load('../plugin-source/radix_tool');
  Checks.group('radix_tool 进制转换');
  Checks.check(radix.eval('return _toBase(255, 2)') == '11111111', 'radix: 255 -> 二进制');
  Checks.check(radix.eval('return _toBase(255, 16)') == 'FF', 'radix: 255 -> 十六进制');
  Checks.check(radix.eval('return _toBase(0, 8)') == '0', 'radix: 零处理');
  Checks.check(radix.eval('return _toBase(8, 8)') == '10', 'radix: 8 -> 八进制');
  Checks.check(radix.eval('return _fromBase("FF", 16)') == 255, 'radix: FF -> 十进制');
  Checks.check(radix.eval('return _fromBase("ZZ", 36)') == 1295, 'radix: 36 进制');
  Checks.check(radix.eval('return _fromBase("G", 16)') == null, 'radix: 非法字符拒绝');
  Checks.check(radix.eval('return _fromBase("", 16)') == null, 'radix: 空串拒绝');
  Checks.check(radix.eval('return _parseSigned("-FF", 16)') == -255, 'radix: 负数解析');
  radix.host.stateValues['decInput'] = '255';
  radix.call('decToAll');
  Checks.check(radix.host.stateValues['decBin'] == '11111111', 'radix: 状态流二进制');
  Checks.check(radix.host.stateValues['decOct'] == '377', 'radix: 状态流八进制');
  Checks.check(radix.host.stateValues['decHex'] == 'FF', 'radix: 状态流十六进制');
  radix.host.stateValues['decInput'] = '-42';
  radix.call('decToAll');
  Checks.check(radix.host.stateValues['decBin'] == '-101010', 'radix: 负数二进制');
  radix.host.stateValues['decInput'] = 'abc';
  radix.call('decToAll');
  Checks.check(radix.host.stateValues['hasError'] == true, 'radix: 非法十进制报错');
  radix.host.stateValues['srcInput'] = '2a';
  radix.call('fromHex');
  Checks.check(radix.host.stateValues['srcDec'] == '42', 'radix: 十六进制转回');
  radix.host.stateValues['srcInput'] = '101010';
  radix.call('fromBin');
  Checks.check(radix.host.stateValues['srcDec'] == '42', 'radix: 二进制转回');
  radix.host.stateValues['srcInput'] = '52';
  radix.call('fromOct');
  Checks.check(radix.host.stateValues['srcDec'] == '42', 'radix: 八进制转回');

  // ============================================================
  // unicode_tool
  // ============================================================
  final uctx = PluginEnv.load('../plugin-source/unicode_tool');
  Checks.group('unicode_tool 码点查询');
  final u8 = uctx.eval('return _cpUtf8(20320)') as Map<String, dynamic>;
  Checks.check(u8['1'] == 228 && u8['2'] == 189 && u8['3'] == 160,
      'unicode: 你 的 UTF-8 字节');
  Checks.check(uctx.eval('return _cpChar(20320)') == '你', 'unicode: 码点转字符');
  Checks.check(uctx.eval('return _cpChar(65)') == 'A', 'unicode: ASCII 码点');
  Checks.check(uctx.eval(r'return _cpChar(128512)') == '\u{1F600}',
      'unicode: 增补平面代理对重组');
  final cps = uctx.eval('return _codepoints("你a")') as Map<String, dynamic>;
  Checks.check(cps['1'] == 20320 && cps['2'] == 97, 'unicode: 码点拆分');
  Checks.check(uctx.eval(r'return _codepoints("\u{1F600}")[1]') == 128512,
      'unicode: emoji 单码点');
  Checks.check(uctx.eval('return _parseCps("4F60 597D")[2]') == 22909,
      'unicode: 空格分隔解析');
  Checks.check(uctx.eval('return _parseCps("U+4F60")[1]') == 20320,
      'unicode: U+ 前缀解析');
  Checks.check(uctx.eval('return _parseCps("GG")') == null, 'unicode: 非法码点拒绝');
  Checks.check(uctx.eval('return _bytesHex({228, 189, 160})') == 'E4 BD A0',
      'unicode: 字节十六进制展示');
  uctx.host.stateValues['uInput'] = '你';
  uctx.call('analyze');
  Checks.check(uctx.host.stateValues['hasAnalysis'] == true, 'unicode: 分析状态流');
  Checks.check((uctx.host.stateValues['uSummary'] as String).contains('1 个字符'),
      'unicode: 汇总统计');
  Checks.check((uctx.host.stateValues['uDetail'] as String).contains('U+4F60') &&
      (uctx.host.stateValues['uDetail'] as String).contains('E4 BD A0'),
      'unicode: 明细行');
  uctx.host.stateValues['cpInput'] = '4F60 597D';
  uctx.call('buildFromCps');
  Checks.check(uctx.host.stateValues['charOut'] == '你好', 'unicode: 码点生成字符');
  Checks.check((uctx.host.stateValues['charBytes'] as String).contains('E4 BD A0'),
      'unicode: 生成结果字节');
  uctx.host.stateValues['cpInput'] = '110000';
  uctx.call('buildFromCps');
  Checks.check(uctx.host.stateValues['hasError'] == true, 'unicode: 超范围码点报错');

  // ============================================================
  // text_stats_tool
  // ============================================================
  final stats = PluginEnv.load('../plugin-source/text_stats_tool');
  Checks.group('text_stats_tool 文本统计');
  final s1 = stats.eval(r'return _stats("你好 world 123\n第二行\n\n第三段")')
      as Map<String, dynamic>;
  Checks.check(s1['chars'] == 21, 'stats: 码点字符数');
  Checks.check(s1['bytes'] == 37, 'stats: UTF-8 字节数');
  Checks.check(s1['lines'] == 4 && s1['nonEmpty'] == 3, 'stats: 行数统计');
  Checks.check(s1['paras'] == 2, 'stats: 段落统计');
  Checks.check(s1['words'] == 10, 'stats: 单词数 (CJK 逐字)');
  Checks.check(s1['spaces'] == 5 && s1['digits'] == 3, 'stats: 空白与数字');
  final s2 = stats.eval(r'return _stats("\u{1F600}")') as Map<String, dynamic>;
  Checks.check(s2['chars'] == 1 && s2['bytes'] == 4, 'stats: emoji 单字符四字节');
  final s3 = stats.eval('return _stats("")') as Map<String, dynamic>;
  Checks.check(s3['chars'] == 0 && s3['lines'] == 1 && s3['paras'] == 0,
      'stats: 空文本边界');
  stats.host.stateValues['statsInput'] = 'hello';
  stats.call('computeStats');
  Checks.check(stats.host.stateValues['hasStats'] == true, 'stats: 状态流输出');
  stats.host.stateValues['statsInput'] = '';
  stats.call('computeStats');
  Checks.check(stats.host.stateValues['hasError'] == true, 'stats: 空输入报错');

  // ============================================================
  // password_tool
  // ============================================================
  final pw = PluginEnv.load('../plugin-source/password_tool');
  Checks.group('password_tool 密码生成');
  pw.host.stateValues['pwLen'] = '16';
  pw.call('generate');
  var generated = pw.host.stateValues['pwResult'] as String? ?? '';
  Checks.check(generated.length == 16, 'pw: 默认长度 16');
  bool inPool(String c, String pool) => pool.contains(c);
  const pwPool = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  var allIn = true;
  for (final c in generated.split('')) {
    if (!inPool(c, pwPool)) allIn = false;
  }
  Checks.check(allIn, 'pw: 字符均在所选字符集内');
  pw.host.stateValues['useSymbol'] = true;
  pw.host.stateValues['symbolLbl'] = '符号: 已选';
  var seenSymbol = false;
  for (var i = 0; i < 30 && !seenSymbol; i++) {
    pw.call('generate');
    generated = pw.host.stateValues['pwResult'] as String? ?? '';
    if (generated.contains(RegExp(r'[!@#$%^&*()\-\_=+\[\]{};:,.?]'))) {
      seenSymbol = true;
    }
  }
  Checks.check(seenSymbol, 'pw: 开启符号后可产出符号字符');
  pw.host.stateValues['pwLen'] = '3';
  pw.call('generate');
  Checks.check(pw.host.stateValues['hasError'] == true, 'pw: 过短长度报错');
  pw.host.stateValues['pwLen'] = '200';
  pw.call('generate');
  Checks.check(pw.host.stateValues['hasError'] == true, 'pw: 过长长度报错');
  pw.host.stateValues['pwLen'] = '16';
  pw.host.stateValues['useUpper'] = false;
  pw.host.stateValues['useLower'] = false;
  pw.host.stateValues['useDigit'] = false;
  pw.host.stateValues['useSymbol'] = false;
  pw.call('generate');
  Checks.check(pw.host.stateValues['hasError'] == true, 'pw: 全关字符集报错');
  pw.call('toggleSymbol');
  Checks.check((pw.host.stateValues['symbolLbl'] as String).contains('已选'),
      'pw: 开关切换标签');

  // ============================================================
  // cny_tool
  // ============================================================
  final cny = PluginEnv.load('../plugin-source/cny_tool');
  Checks.group('cny_tool 人民币大写');
  Checks.check(cny.eval('return _toCny("0")') == '零元整', 'cny: 零元');
  Checks.check(cny.eval('return _toCny("1")') == '壹元整', 'cny: 壹元');
  Checks.check(cny.eval('return _toCny("10")') == '壹拾元整', 'cny: 壹拾');
  Checks.check(cny.eval('return _toCny("110")') == '壹佰壹拾元整', 'cny: 壹佰壹拾');
  Checks.check(cny.eval('return _toCny("1234.56")') == '壹仟贰佰叁拾肆元伍角陆分',
      'cny: 标准金额');
  Checks.check(cny.eval('return _toCny("1005.03")') == '壹仟零伍元零叁分',
      'cny: 跨级零');
  Checks.check(cny.eval('return _toCny("0.05")') == '伍分', 'cny: 纯分');
  Checks.check(cny.eval('return _toCny("1.5")') == '壹元伍角', 'cny: 角无整');
  Checks.check(cny.eval('return _toCny("1000001")') == '壹佰万零壹元整',
      'cny: 百万零一');
  Checks.check(cny.eval('return _toCny("100000500")') == '壹亿零伍佰元整',
      'cny: 亿级跨组零');
  Checks.check(
      cny.eval('return _toCny("1234567890.12")') ==
          '壹拾贰亿叁仟肆佰伍拾陆万柒仟捌佰玖拾元壹角贰分',
      'cny: 十二位大数');
  Checks.check(cny.eval('return _toCny("999.999")') == '壹仟元整',
      'cny: 第三位进位到千元');
  Checks.check(cny.eval('return _toCny("-3.14")') == '负叁元壹角肆分', 'cny: 负数');
  Checks.check(cny.eval('return _toCny("abc")') == null, 'cny: 非法格式拒绝');
  Checks.check(cny.eval('return _toCny("1234567890123")') == null,
      'cny: 超十二位拒绝');
  Checks.check(cny.eval('return _groupToCny("0010")') == '零壹拾',
      'cny: 组内前导零保留');
  Checks.check(cny.eval('return _intToCny("0010")') == '壹拾', 'cny: 整体剥离前导零');
  Checks.check(cny.eval('return _intToCny("0")') == '', 'cny: 整数零为空段');

  // ============================================================
  // date_tool
  // ============================================================
  final date = PluginEnv.load('../plugin-source/date_tool');
  Checks.group('date_tool 日期计算');
  Checks.check(date.eval('return _daysFromCivil(1970, 1, 1)') == 0,
      'date: 纪元起点');
  Checks.check(date.eval('return _parseDate("2024-02-29")') == 2024,
      'date: 闰年 2 月 29 日');
  Checks.check(date.eval('return _parseDate("2023-02-29")') == null,
      'date: 平年 2 月 29 日拒绝');
  Checks.check(date.eval('return _daysBetween("2024-12-31", "2024-01-01")') == 365,
      'date: 全年间隔 (a-b)');
  Checks.check(date.eval('return _daysBetween("2024-03-01", "2024-02-28")') == 2,
      'date: 闰年二月间隔');
  Checks.check(date.eval('return _addDays("2024-02-28", 2)') == '2024-03-01 星期五',
      'date: 闰年月末推算');
  Checks.check(date.eval('return _addDays("2024-01-01", -1)') == '2023-12-31 星期日',
      'date: 负偏移跨年');
  Checks.check(date.eval('return _addDays("2024-01-01", 366)') == '2025-01-01 星期三',
      'date: 闰年 366 天推算');
  Checks.check(
      date.eval('return _describe("2024-09-30")') ==
          '2024-09-30 星期一 (年内第 274 天)',
      'date: 描述与年内天数');
  Checks.check(date.eval('return _addDays("2024-01-01", "abc")') == null,
      'date: 非整数偏移拒绝');
  date.host.stateValues['dateA'] = '2024-01-01';
  date.host.stateValues['dateB'] = '2025-01-01';
  date.call('computeInterval');
  Checks.check((date.host.stateValues['intervalResult'] as String).contains('366 天'),
      'date: 间隔状态流');
  date.host.stateValues['baseDate'] = '2024-01-01';
  date.host.stateValues['offsetDays'] = '7';
  date.call('computeAdd');
  Checks.check(date.host.stateValues['addResult'] == '2024-01-08 星期一',
      'date: 推算状态流');
  date.host.stateValues['dateA'] = '2024-13-01';
  date.call('computeInterval');
  Checks.check(date.host.stateValues['hasError'] == true, 'date: 非法月份报错');

  // ============================================================
  // morse_tool
  // ============================================================
  final morse = PluginEnv.load('../plugin-source/morse_tool');
  Checks.group('morse_tool 摩尔斯电码');
  Checks.check(morse.eval('return _encode("SOS")') == '... --- ...', 'morse: SOS');
  Checks.check(morse.eval('return _decode("... --- ...")') == 'SOS', 'morse: 反向 SOS');
  Checks.check(morse.eval('return _encode("HI YOU")') == '.... .. / -.-- --- ..-',
      'morse: 词间分隔');
  Checks.check(morse.eval('return _encode("2026")') == '..--- ----- ..--- -....',
      'morse: 数字编码');
  Checks.check(morse.eval('return _decode("-....- ....-")') == '-4',
      'morse: 符号与数字解码');
  Checks.check(morse.eval('return _decode("x")') == '?', 'morse: 未知码组');
  morse.host.stateValues['morseInput'] = 'sos';
  morse.call('encodeText');
  Checks.check(morse.host.stateValues['morseResult'] == '... --- ...',
      'morse: 小写输入状态流');
  morse.host.stateValues['morseInput'] = '';
  morse.call('encodeText');
  Checks.check(morse.host.stateValues['hasError'] == true, 'morse: 空输入报错');

  // ============================================================
  // crc32_tool
  // ============================================================
  final crc = PluginEnv.load('../plugin-source/crc32_tool');
  Checks.group('crc32_tool CRC32 校验');
  Checks.check(crc.eval('return _crc32("")') == 0, 'crc: 空串为零');
  Checks.check(crc.eval('return _crc32("123456789")') == 3421780262,
      'crc: 标准校验值 123456789');
  Checks.check(crc.eval('return _crc32("hello")') == 907060870, 'crc: hello');
  Checks.check(crc.eval('return _crc32("你好")') == 1352841281, 'crc: 中文 UTF-8 字节');
  Checks.check(crc.eval('return _byteCount("你好")') == 6, 'crc: 字节数统计');
  crc.host.stateValues['crcInput'] = '123456789';
  crc.call('computeCrc');
  Checks.check(crc.host.stateValues['crcHex'] == 'CBF43926', 'crc: 十六进制输出');
  Checks.check(crc.host.stateValues['crcDec'] == '3421780262', 'crc: 十进制输出');
  crc.host.stateValues['crcInput'] = '';
  crc.call('computeCrc');
  Checks.check(crc.host.stateValues['hasError'] == true, 'crc: 空输入报错');

  // ============================================================
  // jwt_tool
  // ============================================================
  String b64urlUnpadded(String s) =>
      base64Url.encode(utf8.encode(s)).replaceAll('=', '');
  final jwtHeader = b64urlUnpadded('{"alg":"HS256","typ":"JWT"}');
  final jwtPayload = b64urlUnpadded(
      '{"sub":"123","name":"你好","exp":1727654400,"iat":1700000000}');
  final jwt = PluginEnv.load('../plugin-source/jwt_tool');
  Checks.group('jwt_tool JWT 解析');
  Checks.check(jwt.eval('return _b64urlToStd("ab-cd_ef")') == 'ab+cd/ef',
      'jwt: base64url 字母表还原');
  Checks.check(jwt.eval('return _b64urlToStd("abcde")') == 'abcde===',
      'jwt: 填充补齐');
  jwt.host.stateValues['jwtInput'] = '$jwtHeader.$jwtPayload.c2ln';
  jwt.call('parseJwt');
  Checks.check(jwt.host.stateValues['hasResult'] == true, 'jwt: 正常解析');
  Checks.check(
      (jwt.host.stateValues['headerOut'] as String).contains('"alg": "HS256"'),
      'jwt: header 美化输出');
  Checks.check(
      (jwt.host.stateValues['payloadOut'] as String).contains('"name": "你好"'),
      'jwt: payload 中文');
  Checks.check(
      (jwt.host.stateValues['claimsOut'] as String)
          .contains('exp: 2024-09-30 00:00:00 星期一 (UTC)'),
      'jwt: exp 时间格式化');
  Checks.check(
      (jwt.host.stateValues['claimsOut'] as String).contains('exp 状态: 有效'),
      'jwt: exp 有效判定');
  Checks.check((jwt.host.stateValues['sigOut'] as String).contains('未验证'),
      'jwt: 签名未验证标注');
  jwt.host.stateValues['jwtInput'] = 'onlytwo.parts';
  jwt.call('parseJwt');
  Checks.check(jwt.host.stateValues['hasError'] == true, 'jwt: 段数错误报错');
  jwt.host.stateValues['jwtInput'] = '!!!.e30.c2ln';
  jwt.call('parseJwt');
  Checks.check(jwt.host.stateValues['hasError'] == true, 'jwt: 非法 base64 报错');

  // ============================================================
  // memo_tool
  // ============================================================
  final memo = PluginEnv.load('../plugin-source/memo_tool');
  Checks.group('memo_tool 备忘录');
  memo.host.stateValues['noteTitle'] = '标题一';
  memo.host.stateValues['noteBody'] = '第一行\n第二行';
  memo.call('saveCurrent');
  Checks.check(memo.host.storageBox.containsKey('memo_slots_v1'),
      'memo: 写入沙箱存储');
  Checks.check(memo.host.stateValues['s1set'] == true, 'memo: 槽位点亮');
  memo.host.stateValues['noteTitle'] = '';
  memo.host.stateValues['noteBody'] = '';
  memo.call('saveCurrent');
  Checks.check(memo.host.stateValues['hasError'] == true, 'memo: 全空拒绝');
  memo.call('selectSlot', [1]);
  Checks.check(memo.host.stateValues['noteTitle'] == '标题一', 'memo: 载入标题');
  Checks.check(memo.host.stateValues['noteBody'] == '第一行\n第二行',
      'memo: 载入多行内容');
  memo.call('newMemo');
  Checks.check((memo.host.stateValues['selSlotText'] as String).contains('2'),
      'memo: 新建跳到首个空槽位');
  memo.host.stateValues['noteTitle'] = 'a|b';
  memo.host.stateValues['noteBody'] = 'x';
  memo.call('saveCurrent');
  final memo2 = PluginEnv.load('../plugin-source/memo_tool');
  memo2.host.storageBox['memo_slots_v1'] = memo.host.storageBox['memo_slots_v1']!;
  memo2.call('onInit');
  Checks.check(memo2.host.stateValues['hasMemo'] == true, 'memo: 重载恢复');
  memo2.call('selectSlot', [1]);
  Checks.check(memo2.host.stateValues['noteTitle'] == '标题一', 'memo: 重载槽位一');
  memo2.call('selectSlot', [2]);
  Checks.check(memo2.host.stateValues['noteTitle'] == 'a|b',
      'memo: 竖线字符转义往返');
  memo2.call('deleteSlot');
  Checks.check(memo2.host.stateValues['s2set'] == false, 'memo: 删除当前槽位');

  // ============================================================
  // ip_tool
  // ============================================================
  final iptool = PluginEnv.load('../plugin-source/ip_tool');
  Checks.group('ip_tool IP 归属地');
  Checks.check(iptool.eval('return _validIpv4("8.8.8.8")') == true, 'iptool: 合法 IPv4');
  Checks.check(iptool.eval('return _validIpv4("256.1.1.1")') == false, 'iptool: 越界段');
  Checks.check(iptool.eval('return _validIpv4("1.2.3")') == false, 'iptool: 段数不足');
  Checks.check(iptool.eval('return _validIpv4("01.2.3.4")') == false, 'iptool: 前导零');
  iptool.host.cannedResponses['https://ipwho.is/'] = {
    'status': '200',
    'body':
        '{"ip":"9.9.9.9","success":true,"country":"美国","region":"California",'
        '"city":"洛杉矶","latitude":34.05,"longitude":-118.24,'
        '"connection":{"isp":"Cloudflare","org":"CF"},'
        '"timezone":{"id":"America/Los_Angeles"}}',
  };
  iptool.call('queryIp');
  Checks.check(iptool.host.networkGets.isNotEmpty && iptool.host.networkGets.first == 'https://ipwho.is/',
      'iptool: 空输入查询本机');
  Checks.check(iptool.host.stateValues['ipOut'] == '9.9.9.9', 'iptool: 解析嵌套 JSON');
  Checks.check((iptool.host.stateValues['locOut'] as String).contains('美国'),
      'iptool: 归属地展示');
  Checks.check(iptool.host.stateValues['ispOut'] == 'Cloudflare / CF', 'iptool: 运营商合并');
  Checks.check(iptool.host.stateValues['tzOut'] == 'America/Los_Angeles', 'iptool: 时区');
  iptool.host.cannedResponses['https://ipwho.is/8.8.8.8'] = {
    'status': '200',
    'body': '{"ip":"8.8.8.8","success":true,"country":"美国"}',
  };
  iptool.host.stateValues['ipInput'] = '8.8.8.8';
  iptool.call('queryIp');
  Checks.check(iptool.host.stateValues['ipOut'] == '8.8.8.8', 'iptool: 指定 IP 查询');
  iptool.host.cannedResponses['https://ipwho.is/192.0.2.55'] = {
    'status': '200',
    'body': '{"success":false,"message":"Invalid IP"}',
  };
  iptool.host.stateValues['ipInput'] = '192.0.2.55';
  iptool.call('queryIp');
  Checks.check((iptool.host.stateValues['errorMsg'] as String).contains('Invalid IP'),
      'iptool: 服务端失败透传');
  iptool.host.stateValues['ipInput'] = '999.1.1.1';
  iptool.call('queryIp');
  Checks.check(iptool.host.stateValues['hasError'] == true, 'iptool: 本地格式校验拦截');
  iptool.host.stateValues['ipInput'] = '1.1.1.1';
  iptool.call('queryIp');
  Checks.check(iptool.host.stateValues['hasError'] == true, 'iptool: 网络错误回调');
  iptool.host.cannedResponses['https://ipwho.is/9.9.9.9'] = {
    'status': '500',
    'body': 'server error',
  };
  iptool.host.stateValues['ipInput'] = '9.9.9.9';
  iptool.call('queryIp');
  Checks.check((iptool.host.stateValues['errorMsg'] as String).contains('500'),
      'iptool: 非 200 状态报错');

  // ============================================================
  // fx_tool
  // ============================================================
  const fxApi = 'https://open.er-api.com/v6/latest/USD';
  final fx = PluginEnv.load('../plugin-source/fx_tool');
  Checks.group('fx_tool 汇率换算');
  fx.host.cannedResponses[fxApi] = {
    'status': '200',
    'body':
        '{"result":"success","base_code":"USD","rates":{"USD":1,"CNY":7.2,'
        '"EUR":0.9,"JPY":155,"HKD":7.8,"KRW":1300,"AUD":1.5,"GBP":0.79}}',
  };
  fx.call('onInit');
  Checks.check(fx.host.networkGets.contains(fxApi), 'fx: 首次进入拉取汇率');
  Checks.check((fx.host.stateValues['fxInfo'] as String).contains('已更新'),
      'fx: 拉取成功提示');
  Checks.check(fx.host.storageBox.containsKey('fx_cache_v1'), 'fx: 缓存写入');
  Checks.check(fx.eval('return _fmtAmount(720)') == '720', 'fx: 整数去尾零');
  Checks.check(fx.eval('return _fmtAmount(0.5)') == '0.5', 'fx: 小额格式');
  Checks.check(fx.eval('return _fmtAmount(1.23456)') == '1.2346', 'fx: 四位舍入');
  Checks.check(fx.eval('return _convertWith({CNY = 7.2, USD = 1}, 100, "USD", "CNY")')
      == 720, 'fx: 交叉汇率计算');
  fx.host.stateValues['amount'] = '100';
  fx.call('convert');
  Checks.check(fx.host.stateValues['convResult'] == '720 CNY', 'fx: USD->CNY 换算');
  fx.call('cycleTo');
  Checks.check(fx.host.stateValues['convResult'] == '90 EUR',
      'fx: 循环切换目标货币 (CNY->EUR)');
  fx.host.stateValues['amount'] = 'abc';
  fx.call('convert');
  Checks.check(fx.host.stateValues['hasResult'] == false, 'fx: 非法金额不产出');
  final fx2 = PluginEnv.load('../plugin-source/fx_tool');
  // load() 内部的首次 onInit 已在空存储下联网拉取一次, 清空记录后
  // 单独验证第二次 onInit 走缓存路径
  fx2.host.networkGets.clear();
  fx2.host.storageBox['fx_cache_v1'] = fx.host.storageBox['fx_cache_v1']!;
  fx2.call('onInit');
  Checks.check(fx2.host.networkGets.isEmpty, 'fx: 缓存有效期内不再请求');
  Checks.check(fx2.host.stateValues['convResult'] == '7.2 CNY', 'fx: 缓存汇率换算');

  // ============================================================
  // http_tool
  // ============================================================
  final http = PluginEnv.load('../plugin-source/http_tool');
  Checks.group('http_tool 请求调试');
  http.host.cannedResponses['https://example.com/api'] = {
    'status': '200',
    'body': '{"ok":true}',
  };
  http.host.stateValues['reqUrl'] = 'https://example.com/api';
  http.call('sendRequest');
  Checks.check(http.host.stateValues['hasResp'] == true, 'http: GET 响应回调');
  Checks.check(http.host.stateValues['respStatus'] == '200 成功', 'http: 状态语义');
  Checks.check((http.host.stateValues['respShow'] as String).contains('ok'),
      'http: 响应体展示');
  http.call('toggleMethod');
  Checks.check(http.host.stateValues['isPost'] == true, 'http: 方法切换');
  http.host.stateValues['reqBody'] = '{"a":1}';
  http.call('sendRequest');
  Checks.check(http.host.networkPosts.isNotEmpty &&
      http.host.networkPosts.first.contains('{"a":1}'), 'http: POST 请求体下发');
  http.host.stateValues['reqUrl'] = 'ftp://example.com';
  http.call('sendRequest');
  Checks.check(http.host.stateValues['hasError'] == true, 'http: 协议前缀校验');
  http.host.stateValues['reqUrl'] = 'https://example.com/none';
  http.call('sendRequest');
  Checks.check(http.host.stateValues['hasError'] == true, 'http: 网络错误回调');
  Checks.check(http.eval('return _truncate("a")') == 'a', 'http: 短文本不截断');
  final longBody = 'x' * 5000;
  final truncated = http.eval('return _truncate(${json.encode(longBody)})') as String;
  Checks.check(truncated.contains('已截断') && truncated.length < 5000,
      'http: 超长响应截断');
  http.host.cannedResponses['https://example.com/404'] = {
    'status': '404',
    'body': 'not found',
  };
  http.call('toggleMethod'); // 切回 GET
  http.host.stateValues['reqUrl'] = 'https://example.com/404';
  http.call('sendRequest');
  Checks.check(http.host.stateValues['respStatus'] == '404 客户端错误',
      'http: 4xx 状态语义');

  // ============================================================
  // case_convert_tool
  // ============================================================
  final cc = PluginEnv.load('../plugin-source/case_convert_tool');
  Checks.group('case_convert_tool 命名转换');
  cc.host.stateValues['input'] = 'user_first_name';
  cc.call('convert');
  Checks.check(cc.host.stateValues['camelCase'] == 'userFirstName', 'cc: camelCase');
  Checks.check(cc.host.stateValues['pascalCase'] == 'UserFirstName', 'cc: pascalCase');
  Checks.check(cc.host.stateValues['snakeCase'] == 'user_first_name', 'cc: snakeCase');
  Checks.check(cc.host.stateValues['kebabCase'] == 'user-first-name', 'cc: kebabCase');
  Checks.check(cc.host.stateValues['constantCase'] == 'USER_FIRST_NAME', 'cc: constantCase');
  Checks.check(cc.host.stateValues['titleCase'] == 'User First Name', 'cc: titleCase');
  Checks.check(cc.host.stateValues['hasResult'] == true, 'cc: hasResult');
  cc.host.stateValues['input'] = 'XMLParser';
  cc.call('convert');
  Checks.check(cc.host.stateValues['camelCase'] == 'xmlParser', 'cc: XMLParser -> xmlParser');
  Checks.check(cc.host.stateValues['snakeCase'] == 'xml_parser', 'cc: XMLParser -> xml_parser');
  cc.host.clipboardText = 'helloWorld';
  cc.call('pasteInput');
  Checks.check(cc.host.stateValues['kebabCase'] == 'hello-world', 'cc: paste and convert');
  cc.call('clearAll');
  Checks.check(cc.host.stateValues['input'] == '', 'cc: clear input');
  Checks.check(cc.host.stateValues['hasResult'] == false, 'cc: clear result');

  // ============================================================
  // hmac_tool
  // ============================================================
  final hmac = PluginEnv.load('../plugin-source/hmac_tool');
  Checks.group('hmac_tool 消息认证码计算');
  Checks.check(hmac.eval('return _hmac_sha256("Jefe", "what do ya want for nothing?")')
      == '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
      'hmac: RFC 4231 SHA256 向量');
  Checks.check(hmac.eval('return _hmac_sha1("key", "The quick brown fox jumps over the lazy dog")')
      == 'de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9',
      'hmac: RFC 2202 SHA1 向量');
  hmac.host.stateValues['key'] = 'Jefe';
  hmac.host.stateValues['message'] = 'what do ya want for nothing?';
  hmac.call('calculate');
  Checks.check(hmac.host.stateValues['result'] ==
      '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
      'hmac: 状态流 SHA256 小写结果');
  hmac.call('cycleFormat');
  Checks.check(hmac.host.stateValues['result'] ==
      '5BDCC146BF60754E6A042426089575C75A003F089D2739839DEC58B964EC3843',
      'hmac: 切换为大写 Hex');
  hmac.call('cycleFormat');
  Checks.check(hmac.host.stateValues['result'] ==
      'W9zBRr9gdU5qBCQmCJV1x1oAPwidJzmDnexYuWTsOEM=',
      'hmac: 切换为 Base64');
  hmac.call('cycleAlgo');
  Checks.check(hmac.host.stateValues['algo'] == 'SHA1', 'hmac: 切换为 SHA1');
  hmac.host.stateValues['key'] = '';
  hmac.call('calculate');
  Checks.check(hmac.host.stateValues['hasError'] == true, 'hmac: 空密钥错误校验');
  hmac.call('clearAll');
  Checks.check(hmac.host.stateValues['hasResult'] == false, 'hmac: 清空状态');

  // ============================================================
  // cron_tool
  // ============================================================
  final cron = PluginEnv.load('../plugin-source/cron_tool');
  Checks.group('cron_tool 表达式解析');
  Checks.check(cron.eval('local s = _parse_cron_field("*/15", 0, 59); return s[0] == true and s[15] == true and s[1] == nil') == true,
      'cron: 步长字段解析');
  final expl = cron.eval('return _explain_cron("0 9 * * 1-5")') as String;
  Checks.check(expl.contains('工作日') && expl.contains('09:00'), 'cron: 中文释义');
  final runs = (cron.eval('return table.concat(_next_runs("0 9 * * 1-5", 1727654400, 3, 480), "\\n")') as String).split('\n');
  Checks.check(runs.length == 3, 'cron: 未来 3 次运行时间');
  Checks.check(runs.first.contains('2024-09-30 09:00:00 (周一)'), 'cron: 首次命中计算');
  cron.call('setPreset5m');
  Checks.check(cron.host.stateValues['cronExpr'] == '*/5 * * * *', 'cron: 预设表达式切换');
  cron.host.stateValues['cronExpr'] = 'invalid cron';
  cron.call('parseCron');
  Checks.check(cron.host.stateValues['hasError'] == true, 'cron: 异常表达式拦截');
  cron.call('clearAll');
  Checks.check(cron.host.stateValues['cronExpr'] == '', 'cron: 清空表达式');

  // ============================================================
  // totp_tool
  // ============================================================
  final totp = PluginEnv.load('../plugin-source/totp_tool');
  Checks.group('totp_tool 动态令牌');
  Checks.check(totp.eval('return _totp_code("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", 59)') == '287082',
      'totp: RFC 6238 向量 (T=59)');
  Checks.check(totp.eval('return _totp_code("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", 1111111109)') == '081804',
      'totp: RFC 6238 向量 (T=1111111109)');
  Checks.check(totp.eval('return _totp_code("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", 1234567890)') == '005924',
      'totp: RFC 6238 向量 (T=1234567890)');
  Checks.check(totp.eval('return _totp_code("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", 2000000000)') == '279037',
      'totp: RFC 6238 向量 (T=2000000000)');
  final code = totp.host.stateValues['otpCode'] as String? ?? '';
  Checks.check(code.length == 6 && int.tryParse(code) != null, 'totp: 6位数字格式');
  totp.host.stateValues['secret'] = 'JBSWY3DPEHPK3PXP';
  totp.host.stateValues['accountName'] = 'Test GitHub';
  totp.call('saveAccount');
  Checks.check(totp.host.storageBox.containsKey('totp_accounts_v1'), 'totp: 账号存储');
  totp.call('clearAccounts');
  final cleared = totp.host.storageBox['totp_accounts_v1'] ?? '';
  Checks.check(cleared == '[]' || cleared == '{}', 'totp: 清空已存账号');
  // ============================================================
  // ua_tool
  // ============================================================
  final ua = PluginEnv.load('../plugin-source/ua_tool');
  Checks.group('ua_tool 标识解析');
  const winUa = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  final info1 = ua.eval('return _parse_ua(${json.encode(winUa)})') as Map;
  Checks.check(info1['os'] == 'Windows' && info1['browser'] == 'Google Chrome', 'ua: Win10 Chrome 解析');
  Checks.check(info1['browserVer'] == '120.0.0.0', 'ua: Chrome 版本提取');
  Checks.check(info1['deviceType'] == '桌面端 (Desktop)', 'ua: 桌面端判定');
  const iosUa = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1';
  final info2 = ua.eval('return _parse_ua(${json.encode(iosUa)})') as Map;
  Checks.check(info2['os'] == 'iOS' && info2['browser'] == 'Apple Safari', 'ua: iOS Safari 解析');
  Checks.check(info2['deviceType'] == '移动端 (Mobile)', 'ua: 移动端判定');
  const wxUa = 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 MicroMessenger/8.0.47';
  final info3 = ua.eval('return _parse_ua(${json.encode(wxUa)})') as Map;
  Checks.check(info3['browser'] == '微信内置浏览器', 'ua: 微信浏览器识别');
  ua.call('setPresetIos');
  Checks.check((ua.host.stateValues['osDesc'] as String).contains('iOS'), 'ua: iOS 预设切换');
  ua.host.stateValues['uaInput'] = '';
  ua.call('parse');
  Checks.check(ua.host.stateValues['hasError'] == true, 'ua: 空输入拦截');
  ua.call('clearAll');
  Checks.check(ua.host.stateValues['uaInput'] == '', 'ua: 清空');

  // ============================================================
  // pangu_tool
  // ============================================================
  final pangu = PluginEnv.load('../plugin-source/pangu_tool');
  Checks.group('pangu_tool 排版规范化');
  final panguRes = pangu.host.stateValues['output'] as String;
  Checks.check(panguRes.contains('Apple 的产品') && panguRes.contains(' 100 个人'), 'pangu: 初始化排版');
  pangu.host.stateValues['input'] = 'Hello世界';
  pangu.call('formatSpacing');
  Checks.check(pangu.host.stateValues['output'] == 'Hello 世界', 'pangu: 英中空格');
  pangu.host.stateValues['input'] = '售价为\$100美元，完成度达到95%左右';
  pangu.call('formatSpacing');
  Checks.check(pangu.host.stateValues['output'] == '售价为 \$100 美元，完成度达到 95% 左右', 'pangu: 符号与百分比空格');
  pangu.host.stateValues['input'] = '你好,世界!这是真的吗?';
  pangu.call('toFullwidth');
  Checks.check(pangu.host.stateValues['output'] == '你好，世界！这是真的吗？', 'pangu: 半角标点转全角');
  pangu.host.stateValues['input'] = '你好，世界！';
  pangu.call('toHalfwidth');
  Checks.check(pangu.host.stateValues['output'] == '你好, 世界! ', 'pangu: 全角标点转半角');
  pangu.host.stateValues['input'] = 'a    b  c';
  pangu.call('cleanSpaces');
  Checks.check(pangu.host.stateValues['output'] == 'a b c', 'pangu: 清理多余空格');
  pangu.call('clearAll');
  Checks.check(pangu.host.stateValues['hasResult'] == false, 'pangu: 清空');

  // ============================================================
  // html_entity_tool
  // ============================================================
  final html = PluginEnv.load('../plugin-source/html_entity_tool');
  Checks.group('html_entity_tool 实体编解码');
  final initHtml = html.host.stateValues['output'] as String;
  Checks.check(initHtml.contains('© 2026 PTX 中文 ™'), 'html: 初始化多实体混合解码');
  Checks.check(html.eval('return _encode_standard("<a href=\'#\'>&</a>")')
      == '&lt;a href=&#39;#&#39;&gt;&amp;&lt;/a&gt;', 'html: 基础安全转义');
  Checks.check(html.eval('return _encode_named("© & ™")') == '&copy; &amp; &trade;',
      'html: 命名实体编码');
  Checks.check(html.eval('return _encode_decimal("中文")') == '&#20013;&#25991;',
      'html: 十进制实体编码');
  Checks.check(html.eval('return _encode_hex("中文")') == '&#x4e2d;&#x6587;',
      'html: 十六进制实体编码');
  Checks.check(html.eval('return _decode_entities("&copy; &lt;tag&gt; &#20013;&#x6587;")')
      == '© <tag> 中文', 'html: 全能混合解码');
  html.host.stateValues['input'] = '<hello>';
  html.call('encodeStandard');
  Checks.check(html.host.stateValues['output'] == '&lt;hello&gt;', 'html: 状态流基础编码');
  html.host.stateValues['input'] = '';
  html.call('decodeAll');
  Checks.check(html.host.stateValues['hasError'] == true, 'html: 空输入拦截');
  html.call('clearAll');
  Checks.check(html.host.stateValues['hasResult'] == false, 'html: 清空');

  // ============================================================
  // base58_tool
  // ============================================================
  final b58 = PluginEnv.load('../plugin-source/base58_tool');
  Checks.group('base58_tool 编解码');
  final initB58 = b58.host.stateValues['output'] as String;
  Checks.check(initB58 == 'JxF12TrwUP45BMd', 'b58: Hello World 标准 Base58');
  Checks.check(b58.eval('return _b58_encode({104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100})')
      == 'StV1DL6CwTryKyV', 'b58: hello world 标准向量');
  b58.host.stateValues['input'] = 'JxF12TrwUP45BMd';
  b58.call('decodeBase58');
  Checks.check(b58.host.stateValues['output'] == 'Hello World', 'b58: 状态流解码');
  b58.host.stateValues['input'] = 'foobar';
  b58.call('encodeBase32');
  Checks.check(b58.host.stateValues['output'] == 'MZXW6YTBOI======', 'b58: RFC 4648 Base32 编码 (foobar)');
  b58.host.stateValues['input'] = 'MZXW6YTBOI======';
  b58.call('decodeBase32');
  Checks.check(b58.host.stateValues['output'] == 'foobar', 'b58: Base32 解码');
  b58.host.stateValues['input'] = '0OIl'; // 4 banned chars in Base58
  b58.call('decodeBase58');
  Checks.check(b58.host.stateValues['hasError'] == true, 'b58: 非法字符拦截');
  b58.call('clearAll');
  Checks.check(b58.host.stateValues['hasResult'] == false, 'b58: 清空');

  // ============================================================
  // kinship_tool
  // ============================================================
  final kin = PluginEnv.load('../plugin-source/kinship_tool');
  Checks.group('kinship_tool 亲戚称谓换算');
  Checks.check((kin.host.stateValues['resultTitle'] as String).contains('伯父'),
      'kinship: 初始化爸爸的哥哥为伯父');
  kin.call('clearAll');
  kin.call('addFather');
  kin.call('addFather');
  Checks.check((kin.host.stateValues['resultTitle'] as String).contains('爷爷'),
      'kinship: 爸爸的爸爸为爷爷');
  Checks.check((kin.host.stateValues['resultReverse'] as String).contains('孙子'),
      'kinship: 对方称呼我 (男性)');
  kin.call('toggleGender');
  Checks.check((kin.host.stateValues['resultReverse'] as String).contains('孙女'),
      'kinship: 对方称呼我 (女性)');
  kin.host.stateValues['inputText'] = '妈妈的弟弟的儿子';
  kin.call('queryFromInput');
  Checks.check((kin.host.stateValues['resultTitle'] as String).contains('表兄'),
      'kinship: 文本查称谓 (舅表兄弟)');
  kin.host.stateValues['inputText'] = '外星人朋友';
  kin.call('queryFromInput');
  Checks.check(kin.host.stateValues['hasError'] == true, 'kinship: 非法称谓拦截');
  kin.call('clearAll');
  Checks.check((kin.host.stateValues['chainText'] as String) == '我', 'kinship: 清空重置');

  // ============================================================
  // split_bill_tool
  // ============================================================
  final bill = PluginEnv.load('../plugin-source/split_bill_tool');
  Checks.group('split_bill_tool 聚餐分摊 AA');
  final billOut = bill.host.stateValues['output'] as String;
  Checks.check(billOut.contains('总支出: ¥480.00') && billOut.contains('最优转账平账方案 (2 笔)'),
      'bill: 4人聚餐初始化平账');
  Checks.check(billOut.contains('王五  ->  张三  ¥120.00'), 'bill: 最优平账转账匹配');
  bill.call('setPresetRoommates');
  final roomOut = bill.host.stateValues['output'] as String;
  Checks.check(roomOut.contains('总支出: ¥540.00') && roomOut.contains('优惠减免: ¥20.00'),
      'bill: 室友水电带优惠分摊');
  bill.host.stateValues['inputText'] = '';
  bill.call('calculateBill');
  Checks.check(bill.host.stateValues['hasError'] == true, 'bill: 空输入拦截');
  bill.call('clearAll');
  Checks.check(bill.host.stateValues['hasResult'] == false, 'bill: 清空');

  // ============================================================
  // bmi_tool
  // ============================================================
  final bmi = PluginEnv.load('../plugin-source/bmi_tool');
  Checks.group('bmi_tool 健康代谢计算');
  final bmiInit = bmi.host.stateValues['bmiLevel'] as String;
  Checks.check(bmiInit.contains('22.86') && bmiInit.contains('正常健康'),
      'bmi: 初始化 175cm/70kg 正常体型');
  Checks.check(bmi.eval('return _compute_bmi(170, 80)') == 27.68, 'bmi: 170cm/80kg 超重');
  Checks.check(bmi.eval('return _get_bmi_category(15.4)') == '偏瘦 (体重过轻)', 'bmi: 偏瘦区间');
  bmi.call('toggleGender');
  final femaleBmr = bmi.host.stateValues['bmrVal'] as String;
  Checks.check(femaleBmr.contains('1508'), 'bmi: 女性基础代谢修正 (-161)');
  bmi.call('cycleActivity');
  final actTdee = bmi.host.stateValues['tdeeVal'] as String;
  Checks.check(actTdee.contains('2074'), 'bmi: 轻度活动总消耗 (1.375 倍率)');
  bmi.host.stateValues['height'] = '-5';
  bmi.call('calculate');
  Checks.check(bmi.host.stateValues['hasError'] == true, 'bmi: 负数身高校验');
  bmi.call('resetDefault');
  Checks.check((bmi.host.stateValues['bmiVal'] as String) == '22.86', 'bmi: 重置默认');

  // ============================================================
  // pomodoro_tool
  // ============================================================
  final pomo = PluginEnv.load('../plugin-source/pomodoro_tool');
  Checks.group('pomodoro_tool 番茄时钟');
  Checks.check((pomo.host.stateValues['displayTime'] as String) == '25:00',
      'pomo: 初始 25:00 深度专注');
  pomo.call('startTimer');
  Checks.check(pomo.host.stateValues['isRunning'] == true, 'pomo: 启动计时状态');
  pomo.host.fixedTimestampSec += 300; // 走过 5 分钟
  pomo.call('refreshTimer');
  Checks.check((pomo.host.stateValues['displayTime'] as String) == '20:00',
      'pomo: 经过5分钟倒计时同步 (20:00)');
  pomo.call('pauseTimer');
  Checks.check(pomo.host.stateValues['isPaused'] == true, 'pomo: 暂停状态');
  pomo.call('setBreak5');
  Checks.check((pomo.host.stateValues['displayTime'] as String) == '05:00',
      'pomo: 切换短休息 5 分钟');
  pomo.call('finishSession');
  Checks.check(pomo.host.stateValues['statusDesc'] == '恭喜！本轮已达成！',
      'pomo: 达成完成状态');
  pomo.call('setFocus25');
  pomo.call('finishSession'); // 达成一个专注番茄钟
  final statsDesc = pomo.host.stateValues['statsDesc'] as String;
  Checks.check(statsDesc.contains('累计达成番茄钟: 1 个'), 'pomo: 专注统计累加存储');
  pomo.call('clearHistory');
  final clearedStats = pomo.host.stateValues['statsDesc'] as String;
  Checks.check(clearedStats.contains('累计达成番茄钟: 0 个'), 'pomo: 清空统计');

  // ============================================================
  // weather_tool
  // ============================================================
  const bjWeatherApi = 'https://api.open-meteo.com/v1/forecast?latitude=39.9042&longitude=116.4074&current_weather=true';
  final weather = PluginEnv.load('../plugin-source/weather_tool');
  Checks.group('weather_tool 气象查询');
  weather.host.cannedResponses[bjWeatherApi] = {
    'status': '200',
    'body': '{"latitude":39.9,"longitude":116.4,"current_weather":{"temperature":21.5,"windspeed":10.5,"winddirection":180,"weathercode":0,"time":"2026-10-06T12:00"}}',
  };
  weather.call('onInit');
  Checks.check(weather.host.networkGets.contains(bjWeatherApi), 'weather: 发起气象接口请求');
  Checks.check(weather.host.stateValues['tempStr'] == '21.5 °C', 'weather: 气温解析');
  Checks.check((weather.host.stateValues['weatherDesc'] as String).contains('晴朗'), 'weather: WMO 天气代码判定 (晴朗)');
  Checks.check(weather.host.storageBox.containsKey('weather_cache_v1_39.9042_116.4074'), 'weather: 气象数据本地缓存');
  weather.call('cycleCity');
  Checks.check(weather.host.stateValues['cityName'] == '上海', 'weather: 切换城市为上海');

  // ============================================================
  // http_status_tool
  // ============================================================
  final httpStatus = PluginEnv.load('../plugin-source/http_status_tool');
  Checks.group('http_status_tool 状态码与 MIME 词典');
  final hs404 = httpStatus.host.stateValues['output'] as String;
  Checks.check(hs404.contains('404 Not Found') && hs404.contains('未找到资源'),
      'httpStatus: 初始 404 查询');
  httpStatus.host.stateValues['inputText'] = 'teapot';
  httpStatus.call('searchQuery');
  Checks.check((httpStatus.host.stateValues['output'] as String).contains('418 I\'m a teapot'),
      'httpStatus: 愚人节彩蛋 418 查询');
  httpStatus.host.stateValues['inputText'] = '限流';
  httpStatus.call('searchQuery');
  Checks.check((httpStatus.host.stateValues['output'] as String).contains('429 Too Many Requests'),
      'httpStatus: 中文关键词 429 限流匹配');
  httpStatus.call('filterMime');
  Checks.check((httpStatus.host.stateValues['output'] as String).contains('application/json'),
      'httpStatus: MIME 类型词典查询 (application/json)');
  httpStatus.call('filter5xx');
  final s5xx = httpStatus.host.stateValues['output'] as String;
  Checks.check(s5xx.contains('502 Bad Gateway') && s5xx.contains('504 Gateway Timeout'),
      'httpStatus: 5xx 服务端错误分类');
  httpStatus.call('clearAll');
  Checks.check((httpStatus.host.stateValues['resultCount'] as String).contains('个状态码'),
      'httpStatus: 清空后展示完整状态码列表');

  // ============================================================
  // qr_scanner_tool
  // ============================================================
  final qrScanner = PluginEnv.load('../plugin-source/qr_scanner_tool');
  Checks.group('qr_scanner_tool 扫码识别与条码解析');
  Checks.check(qrScanner.eval('return _detectType("https://github.com")') == '网址链接',
      'qr_scanner: URL 链接识别');
  Checks.check(qrScanner.eval('return _detectType("mailto:test@plugintoolbox.dev")') == '电子邮件',
      'qr_scanner: 电子邮件识别');
  Checks.check(qrScanner.eval('return _detectType("tel:10086")') == '电话号码',
      'qr_scanner: 电话号码识别');
  Checks.check(qrScanner.eval('return _detectType("WIFI:S:MyWiFi;P:123456;;")') == 'WiFi 配置',
      'qr_scanner: WiFi 配置识别');
  Checks.check(qrScanner.eval('return _detectType("6901234567890")') == '数字条形码',
      'qr_scanner: 商品 EAN-13 条码识别');
  Checks.check(qrScanner.eval('return _detectType("普通文本测试")') == '纯文本',
      'qr_scanner: 纯文本识别');

  qrScanner.host.scannedBarcode = 'https://plugintoolbox.dev/scanner_test';
  qrScanner.call('startScan');
  Checks.check(qrScanner.host.stateValues['hasResult'] == true, 'qr_scanner: 扫码成功设置结果标志');
  Checks.check(qrScanner.host.stateValues['resultText'] == 'https://plugintoolbox.dev/scanner_test',
      'qr_scanner: 扫码内容正确回显');
  Checks.check(qrScanner.host.stateValues['resultType'] == '网址链接', 'qr_scanner: 扫码内容类型判定');

  qrScanner.call('copyResult');
  Checks.check(qrScanner.host.clipboardText == 'https://plugintoolbox.dev/scanner_test',
      'qr_scanner: 结果文本复制至剪贴板');

  qrScanner.host.decodedBarcode = '6901234567890';
  qrScanner.call('pickAndDecode');
  Checks.check(qrScanner.host.stateValues['resultText'] == '6901234567890',
      'qr_scanner: 图片条码离线解码');
  Checks.check(qrScanner.host.stateValues['resultType'] == '数字条形码',
      'qr_scanner: 图片条码类型分析');

  qrScanner.call('clearResult');
  Checks.check(qrScanner.host.stateValues['hasResult'] == false, 'qr_scanner: 清空识别结果');

  // ============================================================
  // signature_tool
  // ============================================================
  final signature = PluginEnv.load('../plugin-source/signature_tool');
  Checks.group('signature_tool 手写签名与画布控制');
  Checks.check(signature.host.stateValues['brushColor'] == '#000000', 'signature: 默认黑色笔刷');
  Checks.check(signature.host.stateValues['brushWidth'] == 3.0, 'signature: 默认笔画粗细 3.0');

  signature.call('setColorBlue');
  Checks.check(signature.host.stateValues['brushColor'] == '#1E88E5', 'signature: 切换蓝色笔刷');
  signature.call('setColorRed');
  Checks.check(signature.host.stateValues['brushColor'] == '#E53935', 'signature: 切换红色笔刷');

  signature.call('setWidthThick');
  Checks.check(signature.host.stateValues['brushWidth'] == 7.0, 'signature: 切换粗笔刷 (7.0)');
  signature.call('setWidthThin');
  Checks.check(signature.host.stateValues['brushWidth'] == 2.0, 'signature: 切换细笔刷 (2.0)');

  const mockPngB64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
  signature.host.stateValues['signatureBase64'] = mockPngB64;
  signature.call('saveImage');
  Checks.check(signature.host.fsFiles['signature.png'] == mockPngB64, 'signature: 保存 PNG 图片至沙箱');

  signature.call('copyBase64');
  Checks.check(signature.host.clipboardText == 'data:image/png;base64,$mockPngB64',
      'signature: 复制 Base64 Data URL');

  signature.call('clearPad');
  Checks.check(signature.host.stateValues['clearTick'] == 1, 'signature: 清空触发计数器自增');
  Checks.check(signature.host.stateValues['signatureBase64'] == '', 'signature: 清空 Base64 输出');

  // ============================================================
  // file_hash_tool
  // ============================================================
  final fileHash = PluginEnv.load('../plugin-source/file_hash_tool');
  Checks.group('file_hash_tool 文件哈希校验与属性分析');
  Checks.check(fileHash.eval('return _formatSize(512)') == '512 B', 'file_hash: 格式化字节数');
  Checks.check(fileHash.eval('return _formatSize(2048)') == '2.0 KB', 'file_hash: 格式化千字节');
  Checks.check(fileHash.eval('return _formatSize(10485760)') == '10.00 MB', 'file_hash: 格式化兆字节');

  fileHash.host.fsFiles['test_app.zip'] = 'PK\x03\x04Hello PluginToolbox Archive';
  fileHash.host.pickedFilePath = 'test_app.zip';
  fileHash.call('chooseFile');

  Checks.check(fileHash.host.stateValues['hasFile'] == true, 'file_hash: 文件选择并成功分析');
  Checks.check(fileHash.host.stateValues['fileName'] == 'test_app.zip', 'file_hash: 文件名提取');
  Checks.check(fileHash.host.stateValues['fileExt'] == 'zip', 'file_hash: 扩展名提取');

  final md5Code = fileHash.host.stateValues['md5Val'] as String;
  final sha1Code = fileHash.host.stateValues['sha1Val'] as String;
  final sha256Code = fileHash.host.stateValues['sha256Val'] as String;
  final crcCode = fileHash.host.stateValues['crc32Val'] as String;

  Checks.check(md5Code.length == 32, 'file_hash: 32 位 MD5 计算');
  Checks.check(sha1Code.length == 40, 'file_hash: 40 位 SHA-1 计算');
  Checks.check(sha256Code.length == 64, 'file_hash: 64 位 SHA-256 计算');
  Checks.check(crcCode.length == 8, 'file_hash: 8 位 CRC32 计算');

  fileHash.call('copyMd5');
  Checks.check(fileHash.host.clipboardText == md5Code, 'file_hash: 复制 MD5 校验码');

  fileHash.host.stateValues['compareHashText'] = md5Code.toLowerCase();
  fileHash.call('checkCompare');
  Checks.check(fileHash.host.stateValues['hasCompareResult'] == true &&
      (fileHash.host.stateValues['compareResult'] as String).contains('MD5'),
      'file_hash: 大小写不敏感 MD5 比对成功');

  fileHash.host.stateValues['compareHashText'] = sha256Code;
  fileHash.call('checkCompare');
  Checks.check((fileHash.host.stateValues['compareResult'] as String).contains('SHA-256'),
      'file_hash: SHA-256 比对成功');

  fileHash.host.stateValues['compareHashText'] = 'MISMATCH123456';
  fileHash.call('checkCompare');
  Checks.check((fileHash.host.stateValues['compareResult'] as String).contains('比对失败'),
      'file_hash: 错误校验码比对拦截');

  // ============================================================
  // cidr_tool
  // ============================================================
  final cidr = PluginEnv.load('../plugin-source/cidr_tool');
  Checks.group('cidr_tool 子网掩码与 CIDR 计算');
  cidr.host.stateValues['cidrInput'] = '192.168.1.15/24';
  cidr.call('calculate');
  Checks.check(cidr.host.stateValues['hasResult'] == true, 'cidr: 正常 /24 计算成功');
  Checks.check(cidr.host.stateValues['resNet'] == '192.168.1.0', 'cidr: 网络地址');
  Checks.check(cidr.host.stateValues['resBcast'] == '192.168.1.255', 'cidr: 广播地址');
  Checks.check((cidr.host.stateValues['resRange'] as String).contains('192.168.1.1 ~ 192.168.1.254'),
      'cidr: 可用主机范围');
  Checks.check((cidr.host.stateValues['resUsable'] as String).contains('254 / 256'),
      'cidr: 可用主机数');
  Checks.check((cidr.host.stateValues['resClass'] as String).contains('私有地址'),
      'cidr: 私网识别');

  cidr.host.stateValues['cidrInput'] = '10.0.0.1 255.255.0.0';
  cidr.call('calculate');
  Checks.check(cidr.host.stateValues['resNet'] == '10.0.0.0', 'cidr: 点分十进制掩码解析');
  Checks.check((cidr.host.stateValues['resMask'] as String).contains('/16'), 'cidr: /16 识别');

  cidr.host.stateValues['cidrInput'] = '999.1.1.1/24';
  cidr.call('calculate');
  Checks.check(cidr.host.stateValues['hasError'] == true, 'cidr: 非法 IP 拦截');

  cidr.host.stateValues['cidrInput'] = '192.168.1.1/24';
  cidr.call('setPrefix', [30]);
  Checks.check(cidr.host.stateValues['hasResult'] == true, 'cidr: 快捷掩码切换');
  Checks.check((cidr.host.stateValues['resCidr'] as String).contains('/30'), 'cidr: /30 确认');

  // ============================================================
  // md_table_tool
  // ============================================================
  final mdTable = PluginEnv.load('../plugin-source/md_table_tool');
  Checks.group('md_table_tool Markdown 表格对齐与排版');
  Checks.check(mdTable.eval('return _char_width(65)') == 1, 'md_table: ASCII 宽度 1');
  Checks.check(mdTable.eval('return _char_width(20320)') == 2, 'md_table: 中文字符宽度 2');
  mdTable.host.stateValues['inputText'] = '| 姓名 | 城市 |\n|---|---|\n| 张三 | 北京 |\n| Alice | New York |';
  mdTable.call('formatTable');
  Checks.check(mdTable.host.stateValues['hasResult'] == true, 'md_table: 对齐成功');
  final tableRes = mdTable.host.stateValues['resultText'] as String;
  Checks.check(tableRes.contains('| 姓名') && tableRes.contains('| Alice'), 'md_table: 保留完整内容');

  mdTable.host.stateValues['inputText'] = "Name\tAge\nBob\t25";
  mdTable.call('convertTsv');
  Checks.check((mdTable.host.stateValues['resultText'] as String).contains('| Name'), 'md_table: TSV 转换');

  mdTable.host.stateValues['inputText'] = '';
  mdTable.call('formatTable');
  Checks.check(mdTable.host.stateValues['hasError'] == true, 'md_table: 空内容报错');

  // ============================================================
  // zero_width_tool
  // ============================================================
  final zw = PluginEnv.load('../plugin-source/zero_width_tool');
  Checks.group('zero_width_tool 零宽字符隐写');
  zw.host.stateValues['coverText'] = '公开信息通知';
  zw.host.stateValues['secretText'] = '暗号9946';
  zw.call('encodeStego');
  Checks.check(zw.host.stateValues['hasResult'] == true, 'zw: 隐写成功');
  final stegoOut = zw.host.stateValues['resultText'] as String;
  Checks.check(stegoOut.length > '公开信息通知'.length, 'zw: 嵌入不可见字符');

  zw.host.stateValues['coverText'] = stegoOut;
  zw.call('decodeStego');
  Checks.check(zw.host.stateValues['resultText'] == '暗号9946', 'zw: 成功还原秘密文本');

  zw.host.stateValues['coverText'] = stegoOut;
  zw.call('stripStego');
  Checks.check(zw.host.stateValues['resultText'] == '公开信息通知', 'zw: 清除盲水印');

  // ============================================================
  // curl_tool
  // ============================================================
  final curl = PluginEnv.load('../plugin-source/curl_tool');
  Checks.group('curl_tool cURL 命令解析与代码生成');
  curl.host.stateValues['cmdInput'] =
      "curl 'https://api.example.com/items' -X POST -H 'Authorization: Bearer test' -d '{\"id\":1}'";
  curl.call('parseCurl');
  Checks.check(curl.host.stateValues['hasResult'] == true, 'curl: 解析成功');
  Checks.check(curl.host.stateValues['resMethod'] == 'POST', 'curl: 方法提取');
  Checks.check(curl.host.stateValues['resUrl'] == 'https://api.example.com/items', 'curl: URL 提取');
  Checks.check((curl.host.stateValues['generatedCode'] as String).contains('requests.post'),
      'curl: 生成 Python requests 代码');

  curl.call('setLang', ['js']);
  Checks.check((curl.host.stateValues['generatedCode'] as String).contains('fetch(url'),
      'curl: 生成 JS fetch 代码');

  curl.call('setLang', ['go']);
  Checks.check((curl.host.stateValues['generatedCode'] as String).contains('http.NewRequest'),
      'curl: 生成 Go net/http 代码');

  // ============================================================
  // git_commit_tool
  // ============================================================
  final gitc = PluginEnv.load('../plugin-source/git_commit_tool');
  Checks.group('git_commit_tool 规范化 Git Commit');
  gitc.host.stateValues['commitType'] = 'feat';
  gitc.host.stateValues['commitScope'] = 'auth';
  gitc.host.stateValues['commitSubject'] = '实现 OAuth2 登录';
  gitc.host.stateValues['commitBody'] = '支持多种第三方授权登录。';
  gitc.host.stateValues['isBreaking'] = false;
  gitc.host.stateValues['commitIssue'] = 'Closes #88';
  gitc.call('generate');
  Checks.check(gitc.host.stateValues['resHeader'] == 'feat(auth): 实现 OAuth2 登录',
      'gitc: Header 规范格式');
  Checks.check((gitc.host.stateValues['resFullMsg'] as String).contains('Closes #88'),
      'gitc: Issue 关联');
  Checks.check((gitc.host.stateValues['resGitCmd'] as String).contains('git commit -m'),
      'gitc: 完整命令构造');

  gitc.call('toggleBreaking');
  Checks.check((gitc.host.stateValues['resHeader'] as String).contains('feat(auth)!:'),
      'gitc: 破坏性变更感叹号标记');

  // ============================================================
  // compound_tool
  // ============================================================
  final comp = PluginEnv.load('../plugin-source/compound_tool');
  Checks.group('compound_tool 复利与定投计算');
  comp.host.stateValues['initPrincipal'] = '10000';
  comp.host.stateValues['periodicDeposit'] = '1000';
  comp.host.stateValues['depositFreq'] = 'month';
  comp.host.stateValues['annualRate'] = '6';
  comp.host.stateValues['durationYears'] = '10';
  comp.host.stateValues['inflationRate'] = '2';
  comp.call('calculate');
  Checks.check(comp.host.stateValues['hasResult'] == true, 'comp: 计算成功');
  Checks.check((comp.host.stateValues['resPrincipal'] as String).contains('130,000'),
      'comp: 累计本金');
  Checks.check((comp.host.stateValues['resTotalFv'] as String).contains('¥ '),
      'comp: 资产终值输出');

  comp.call('applyPreset', ['steady']);
  Checks.check(comp.host.stateValues['depositFreq'] == 'none', 'comp: 稳健预设应用');

  // ============================================================
  // tdee_tool
  // ============================================================
  final tdee = PluginEnv.load('../plugin-source/tdee_tool');
  Checks.group('tdee_tool 宏量营养素与 TDEE 规划');
  tdee.host.stateValues['gender'] = 'male';
  tdee.host.stateValues['weight'] = '75';
  tdee.host.stateValues['height'] = '180';
  tdee.host.stateValues['age'] = '28';
  tdee.host.stateValues['activityIndex'] = '2';
  tdee.host.stateValues['goal'] = 'cut';
  tdee.host.stateValues['dietStyle'] = 'high_protein';
  tdee.call('calculate');
  Checks.check(tdee.host.stateValues['hasResult'] == true, 'tdee: 计算成功');
  Checks.check((tdee.host.stateValues['resProtein'] as String).contains('g'),
      'tdee: 蛋白质克数输出');
  Checks.check((tdee.host.stateValues['resWater'] as String).contains('ml'),
      'tdee: 饮水量推荐输出');

  tdee.call('setGoal', ['bulk']);
  Checks.check(tdee.host.stateValues['hasResult'] == true, 'tdee: 目标切换');

  // ============================================================
  // world_clock_tool
  // ============================================================
  final wclock = PluginEnv.load('../plugin-source/world_clock_tool');
  Checks.group('world_clock_tool 世界时钟与时区换算');
  Checks.check(wclock.eval('return _days_to_civil(19631)') == 2023, 'wclock: 日历年份换算');
  Checks.check(wclock.eval('return _civil_to_days(2023, 10, 1)') == 19631, 'wclock: 日历往返');
  wclock.host.stateValues['customTime'] = '2026-10-07 14:00';
  wclock.call('convertInputTime');
  Checks.check(wclock.host.stateValues['hasResult'] == true, 'wclock: 跨时区时间推算');
  Checks.check((wclock.host.stateValues['time_bj'] as String).contains('14:00:00'),
      'wclock: 北京基准时间');
  Checks.check((wclock.host.stateValues['time_lon'] as String).contains('06:00:00'),
      'wclock: 伦敦时间对齐 (UTC+0)');
  Checks.check((wclock.host.stateValues['time_tk'] as String).contains('15:00:00'),
      'wclock: 东京时间对齐 (UTC+9)');

  // ============================================================
  // linux_cheat_tool
  // ============================================================
  final lnx = PluginEnv.load('../plugin-source/linux_cheat_tool');
  Checks.group('linux_cheat_tool Linux 命令速查');
  lnx.host.stateValues['searchKeyword'] = '端口';
  lnx.call('doSearch');
  Checks.check((lnx.host.stateValues['selCmd'] as String).contains('8080'), 'lnx: 搜索端口相关命令');
  lnx.call('setCat', ['file']);
  Checks.check((lnx.host.stateValues['pageInfo'] as String).contains('页'), 'lnx: 分类筛选');

  // ============================================================
  // css_tool
  // ============================================================
  final css = PluginEnv.load('../plugin-source/css_tool');
  Checks.group('css_tool CSS 样式与阴影生成');
  css.call('generateShadow');
  Checks.check((css.host.stateValues['generatedCss'] as String).contains('box-shadow'),
      'css: 盒阴影代码生成');
  css.call('generateGradient');
  Checks.check((css.host.stateValues['generatedCss'] as String).contains('linear-gradient'),
      'css: 渐变代码生成');
  css.call('applyShadowPreset', ['glow']);
  Checks.check((css.host.stateValues['generatedCss'] as String).contains('rgba(79, 172, 254'),
      'css: 发光预设生效');

  // ============================================================
  // whois_tool
  // ============================================================
  final whois = PluginEnv.load('../plugin-source/whois_tool');
  Checks.group('whois_tool 域名 WHOIS 与 RDAP 查询');
  Checks.check(whois.eval('return _clean_domain("https://GITHUB.COM/Aclguh")') == 'github.com',
      'whois: 域名清洗提取');
  Checks.check(whois.eval('return _valid_domain("github.com")') == true, 'whois: 合法域名');
  Checks.check(whois.eval('return _valid_domain("invalid")') == false, 'whois: 缺少顶级后缀拦截');

  final mockRdap = '{"ldhName":"EXAMPLE.COM","events":[{"eventAction":"registration","eventDate":"1995-08-14"},{"eventAction":"expiration","eventDate":"2025-08-13"}],"entities":[{"roles":["registrar"],"vcardArray":["vcard",[["fn",{},"text","ICANN Registrar"]]]}],"status":["clientDeleteProhibited"],"nameservers":[{"ldhName":"A.IANA-SERVERS.NET"}]}';
  whois.host.cannedResponses['https://rdap.org/domain/example.com'] = {
    'status': '200',
    'body': mockRdap,
  };
  whois.host.stateValues['domainInput'] = 'example.com';
  whois.call('queryWhois');
  Checks.check(whois.host.stateValues['hasResult'] == true, 'whois: 响应成功');
  Checks.check(whois.host.stateValues['resDomain'] == 'EXAMPLE.COM', 'whois: 域名提取');
  Checks.check(whois.host.stateValues['resRegistrar'] == 'ICANN Registrar', 'whois: 注册商提取');
  Checks.check(whois.host.stateValues['resRegDate'] == '1995-08-14', 'whois: 注册日期');
  Checks.check(whois.host.stateValues['resExpDate'] == '2025-08-13', 'whois: 到期日期');

  // ============================================================
  // ocr_tool
  // ============================================================
  final ocr = PluginEnv.load('../plugin-source/ocr_tool');
  Checks.group('ocr_tool 离线文字识别');
  ocr.call('onInit');
  Checks.check(ocr.host.stateValues['hasResult'] == false, 'ocr: 初始无结果');
  ocr.call('pickAndRecognize');
  Checks.check(ocr.host.stateValues['hasResult'] == true, 'ocr: 选图识别成功');
  Checks.check((ocr.host.stateValues['lineCount'] as int? ?? 0) >= 2, 'ocr: 识别行数');
  ocr.call('copyResult');
  Checks.check(ocr.host.clipboardText != null && ocr.host.clipboardText!.contains('OCR'), 'ocr: 结果复制到剪贴板');
  ocr.call('clearResult');
  Checks.check(ocr.host.stateValues['hasResult'] == false, 'ocr: 清空状态');

  // ============================================================
  // decibel_meter_tool
  // ============================================================
  final decibel = PluginEnv.load('../plugin-source/decibel_meter_tool');
  Checks.group('decibel_meter_tool 环境噪音分贝计');
  decibel.call('onInit');
  Checks.check(decibel.host.stateValues['currentDb'] == '--', 'decibel: 初始状态');
  decibel.call('sampleDecibel');
  Checks.check(decibel.host.stateValues['currentDb'] == '58.5', 'decibel: 采样声压');
  Checks.check(decibel.host.stateValues['levelTag'] != null, 'decibel: 噪音级别评定');
  Checks.check(decibel.eval('return _evalNoiseLevel(20.0)') == '极安静 (深山/耳语)', 'decibel: 极安静级别');
  Checks.check(decibel.eval('return _evalNoiseLevel(90.0)') == '严重噪音 (损耳风险)', 'decibel: 严重噪音级别');
  decibel.call('copyStats');
  Checks.check(decibel.host.clipboardText != null && decibel.host.clipboardText!.contains('噪音检测报告'), 'decibel: 复制报告');

  // ============================================================
  // compass_level_tool
  // ============================================================
  final compass = PluginEnv.load('../plugin-source/compass_level_tool');
  Checks.group('compass_level_tool 电子罗盘与水平仪');
  compass.call('onInit');
  Checks.check((compass.host.stateValues['heading'] as int? ?? 0) == 129, 'compass: 方位角计算');
  Checks.check(compass.eval('return _calcHeadingLabel(0)') == '正北', 'compass: 正北方向判定');
  Checks.check(compass.eval('return _calcHeadingLabel(90)') == '正东', 'compass: 正东方向判定');
  Checks.check(compass.eval('return _evalLevel(1.0, 1.0)') == true, 'compass: 水平平整判定');
  Checks.check(compass.eval('return _evalLevel(5.0, 1.0)') == false, 'compass: 倾斜判定');

  // ============================================================
  // exif_cleaner_tool
  // ============================================================
  final exif = PluginEnv.load('../plugin-source/exif_cleaner_tool');
  Checks.group('exif_cleaner_tool 照片 EXIF 隐私检测与擦除');
  exif.call('onInit');
  Checks.check(exif.host.stateValues['hasSelected'] == false, 'exif: 初始未选择');
  exif.call('pickAndInspect');
  Checks.check(exif.host.stateValues['hasSelected'] == true, 'exif: 读取照片元数据');
  Checks.check(exif.host.stateValues['privacyWarning'].toString().contains('高危'), 'exif: 检测到 GPS 泄露告警');
  exif.call('cleanExif');
  Checks.check(exif.host.stateValues['isCleaned'] == true, 'exif: 一键抹除成功');
  Checks.check(exif.host.stateValues['privacyWarning'].toString().contains('极安全'), 'exif: 抹除后安全状态');

  // ============================================================
  // flashlight_tool
  // ============================================================
  final flash = PluginEnv.load('../plugin-source/flashlight_tool');
  Checks.group('flashlight_tool 多功能手电与补光灯');
  flash.call('onInit');
  Checks.check(flash.host.stateValues['torchStatus'] == '已关闭', 'flashlight: 初始手电关闭');
  flash.call('toggleTorch');
  Checks.check(flash.host.stateValues['torchStatus'].toString().contains('已开启'), 'flashlight: 开关手电开启');
  flash.call('setColorWarm');
  Checks.check(flash.host.stateValues['currentColorHex'] == '#FFF2D6', 'flashlight: 切换暖色温');
  flash.call('setColorRed');
  Checks.check(flash.host.stateValues['currentColorHex'] == '#FF3B30', 'flashlight: 切换警示红光');

  // ============================================================
  // ble_scanner_tool
  // ============================================================
  final ble = PluginEnv.load('../plugin-source/ble_scanner_tool');
  Checks.group('ble_scanner_tool BLE 蓝牙设备嗅探器');
  ble.call('onInit');
  Checks.check(ble.host.stateValues['deviceCount'] == 0, 'ble: 初始 0 设备');
  ble.call('startScan');
  Checks.check((ble.host.stateValues['deviceCount'] as int? ?? 0) >= 1, 'ble: 发现广播外设');
  Checks.check(ble.host.stateValues['hasDevices'] == true, 'ble: 列表展示');
  ble.call('copyList');
  Checks.check(ble.host.clipboardText != null && ble.host.clipboardText!.contains('BLE-SmartSensor'), 'ble: 复制设备信息');
  ble.call('stopScan');
  Checks.check(ble.host.stateValues['isScanning'] == false, 'ble: 停止扫描');

  // ============================================================
  // ledger_tool
  // ============================================================
  final ledger = PluginEnv.load('../plugin-source/ledger_tool');
  Checks.group('ledger_tool 极简 SQLite 记账本');
  ledger.call('onInit');
  ledger.host.stateValues['inputAmount'] = '35.5';
  ledger.host.stateValues['inputNote'] = '午餐便当';
  ledger.call('addRecord');
  Checks.check(ledger.host.dbExecLog.any((sql) => sql.contains('INSERT INTO ledger_records')), 'ledger: 插入 SQLite 记录');
  Checks.check(ledger.eval('return _calcBalance(50.0, 100.0)') == 50.0, 'ledger: 收支结余计算');
  ledger.call('exportCsv');
  Checks.check(ledger.host.clipboardText != null && ledger.host.clipboardText!.contains('序号,类型,分类,金额,备注'), 'ledger: 导出 CSV');

  // ============================================================
  // tone_generator_tool
  // ============================================================
  final tone = PluginEnv.load('../plugin-source/tone_generator_tool');
  Checks.group('tone_generator_tool 音频频率发生器与调音器');
  tone.call('onInit');
  Checks.check(tone.host.stateValues['freqHz'] == '440', 'tone: 默认 440 Hz');
  tone.call('setNoteC4');
  Checks.check(tone.host.stateValues['freqHz'] == '261', 'tone: 切换中央 C');
  tone.call('setNoteA4');
  Checks.check(tone.host.stateValues['freqHz'] == '440', 'tone: 切换标准 A4');
  Checks.check(tone.eval('return _freqToPitchName(440)').toString().contains('A4'), 'tone: 音高名称');
  tone.call('stopTone');
  Checks.check(tone.host.stateValues['statusText'].toString().contains('停止'), 'tone: 停止发音');

  // ============================================================
  // nfc_toolbox
  // ============================================================
  final nfc = PluginEnv.load('../plugin-source/nfc_toolbox');
  Checks.group('nfc_toolbox NFC 标签读写多功能箱');
  nfc.call('onInit');
  Checks.check(nfc.host.stateValues['hasTag'] == false, 'nfc: 初始无标签');
  nfc.call('readNdefTag');
  Checks.check(nfc.host.stateValues['hasTag'] == true, 'nfc: 读取 NDEF 成功');
  Checks.check(nfc.host.stateValues['tagPayload'].toString().contains('example.com'), 'nfc: 读取负载内容');
  nfc.host.stateValues['inputPayload'] = 'https://custom-site.org';
  nfc.call('writeNdefTag');
  Checks.check(nfc.host.stateValues['nfcStatus'].toString().contains('写入成功'), 'nfc: 写入标签成功');
  nfc.call('clearData');
  Checks.check(nfc.host.stateValues['hasTag'] == false, 'nfc: 清空数据');

  // ============================================================
  // secret_vault_tool
  // ============================================================
  final vault = PluginEnv.load('../plugin-source/secret_vault_tool');
  Checks.group('secret_vault_tool 生物认证隐私保险箱');
  vault.call('onInit');
  Checks.check(vault.host.stateValues['isUnlocked'] == false, 'vault: 初始锁定');
  vault.call('unlockVault');
  Checks.check(vault.host.stateValues['isUnlocked'] == true, 'vault: 指纹核验通过解锁');
  vault.host.stateValues['inputSecret'] = 'SecretToken_12345';
  vault.call('saveSecret');
  Checks.check(vault.host.storageBox['user_secret_data'] == 'SecretToken_12345', 'vault: 持久化机密');
  vault.call('copyVault');
  Checks.check(vault.host.clipboardText == 'SecretToken_12345', 'vault: 复制机密内容');
  vault.call('lockVault');
  Checks.check(vault.host.stateValues['isUnlocked'] == false, 'vault: 重新上锁销毁内存');

  // ============================================================
  // ws_debugger_tool
  // ============================================================
  final ws = PluginEnv.load('../plugin-source/ws_debugger_tool');
  Checks.group('ws_debugger_tool WebSocket 实时调试终端');
  ws.call('onInit');
  Checks.check(ws.host.stateValues['connStatus'] == '未连接', 'ws: 初始未连接');
  ws.call('connectWs');
  Checks.check(ws.host.wsUrlLog.any((u) => u.contains('echo.websocket.events')), 'ws: 发起连接');
  ws.host.stateValues['msgToSend'] = '{"action":"hello"}';
  ws.call('sendMessage');
  Checks.check(ws.host.wsSentMessages.any((m) => m.contains('hello')), 'ws: 发送数据帧');
  ws.call('disconnectWs');
  Checks.check(ws.host.stateValues['connStatus'].toString().contains('断开'), 'ws: 断开连接');

  // ============================================================
  // ai_writer_tool
  // ============================================================
  final ai = PluginEnv.load('../plugin-source/ai_writer_tool');
  Checks.group('ai_writer_tool AI 随身助手与润色工具');
  ai.call('onInit');
  Checks.check(ai.host.stateValues['promptMode'] == '周报润色', 'ai: 初始周报模式');
  ai.call('setModeTranslate');
  Checks.check(ai.host.stateValues['promptMode'] == '中英互译', 'ai: 切换互译模式');
  ai.call('setModeWeekly');
  ai.host.stateValues['inputText'] = '本周完成了所有新插件的设计开发与验证';
  ai.call('generateAi');
  Checks.check(ai.host.stateValues['hasResult'] == true, 'ai: 生成完成');
  Checks.check(ai.host.stateValues['outputText'].toString().contains('AI'), 'ai: 产出结果内容');
  ai.call('copyResult');
  Checks.check(ai.host.clipboardText != null && ai.host.clipboardText!.contains('AI'), 'ai: 复制结果');

  exit(Checks.finish('test_all'));
}





