import 'dart:convert';
import 'dart:io';

import 'package:ptx_dev_harness/runner.dart';

/// 导出 qr_tool 编码结果矩阵，供 Python segno 参考实现比对。
/// 用法: dart run bin/qr_dump.dart
void main() {
  final env = PluginEnv.load('../plugin-source/qr_tool');
  final out = <String, dynamic>{};
  final texts = [
    'A',
    'HELLO',
    '0123456789',
    'https://plugin.toolbox/qr?from=ptx&id=42',
    '你好，二维码！',
    'Mixed 中文 & ASCII 123!',
    'Emoji 😀🌟 test',
    'x' * 62,
    'x' * 84,
    'y' * 104, // 触发 M->L 回退
    'z' * 106, // L 级别 v5 容量边界
    'line1\nline2\ttab\\quote"end',
  ];
  for (final text in texts) {
    final dynamic res;
    try {
      // 与插件 build() 一致: 先 M 后 L 回退
      res = env.eval('local res, err = _qr_matrix(${json.encode(text)}, "M")\n'
          'if res == nil then res = _qr_matrix(${json.encode(text)}, "L") end\n'
          'if res == nil then error(tostring(err)) end\n'
          'return res');
    } catch (e) {
      out[text] = {'error': e.toString()};
      continue;
    }
    if (res is! Map<String, dynamic>) {
      out[text] = {'error': 'non-map result: $res'};
      continue;
    }
    final size = res['size'] as int;
    final rawMatrix = res['matrix'] as Map<String, dynamic>;
    final rows = <List<int>>[];
    for (var r = 0; r < size; r++) {
      final row = rawMatrix[r.toString()] as Map<String, dynamic>;
      rows.add([for (var c = 0; c < size; c++) row[c.toString()] == true ? 1 : 0]);
    }
    out[text] = {
      'version': res['version'],
      'mask': res['mask'],
      'ecl': res['ecl'],
      'size': size,
      'matrix': rows,
    };
  }
  final f = File('build/qr_out.json');
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
  // ignore: avoid_print
  print('wrote ${f.path} (${out.length} cases)');
}
