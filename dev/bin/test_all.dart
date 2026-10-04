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

  exit(Checks.finish('test_all'));
}
