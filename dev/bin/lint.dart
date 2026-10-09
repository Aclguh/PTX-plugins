import 'dart:convert';
import 'dart:io';

import 'package:lua_dardo/lua.dart';

/// PTX-plugins 插件包静态 lint：
/// 校验 plugin.json 清单、UI AST 组件/图标/样式白名单、事件绑定与 Lua 函数交叉引用、
/// Lua 语法可编译性。任何 FAIL 都会以非零码退出。
void main() {
  const widgets = {
    'Column', 'Row', 'Stack', 'Padding', 'Center', 'Expanded', 'SizedBox',
    'SingleChildScrollView', 'Text', 'SelectableText', 'TextField',
    'FilledButton', 'OutlinedButton', 'IconButton', 'Card', 'Container',
    'ListView', 'ListTile', 'Image', 'PixelGrid', 'DrawingPad', 'SignaturePad',
    'Wrap', 'Divider', 'ProgressBar', 'Switch', 'Slider', 'Dropdown',
    'Tabs', 'TabBar', 'MarkdownView', 'Markdown', 'Chart', 'LineChart',
    'BarChart', 'Html', 'HtmlView', 'Canvas',
  };
  const icons = {
    'code', 'qr_code', 'qr_code_scanner', 'phone_android', 'arrow_downward',
    'arrow_upward', 'swap_vert', 'content_copy', 'settings', 'delete_outline',
    'search', 'check', 'brush', 'draw', 'clear', 'refresh', 'save', 'share',
    'folder_open', 'file_present', 'camera_alt', 'compare_arrows', 'image',
    'fingerprint',
  };
  const styles = {
    'displayLarge', 'displayMedium', 'displaySmall', 'headlineLarge',
    'headlineMedium', 'headlineSmall', 'titleLarge', 'titleMedium',
    'titleSmall', 'bodyLarge', 'bodyMedium', 'bodySmall', 'labelLarge',
  };
  const categories = {
    'encoding', 'generator', 'text', 'system', 'calculator', 'network', 'other',
  };
  const permissions = {
    'clipboard', 'storage', 'network', 'camera', 'photo_library', 'photoLibrary',
    'torch', 'sensor', 'notification', 'biometrics', 'microphone', 'screen',
    'location', 'bluetooth', 'nfc', 'ai', 'database', 'db', 'ipc',
  };
  const eventKeys = {'onPressed', 'onTap', 'onChanged', 'onExport', 'onLinkTap'};
  const actions = {'callLua', 'setState', 'copyToClipboard'};

  var pass = 0, fail = 0;
  void check(bool cond, String label) {
    if (cond) {
      pass++;
    } else {
      fail++;
      // ignore: avoid_print
      print('  FAIL $label');
    }
  }

  // lint 扫描上一级 PTX-plugins/plugin-source/ 目录的插件
  final root = Directory('../plugin-source');
  final pluginDirs = root
      .listSync()
      .whereType<Directory>()
      .where((d) => File('${d.path}/plugin.json').existsSync())
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  // ignore: avoid_print
  print('发现 ${pluginDirs.length} 个插件目录\n');

  for (final dir in pluginDirs) {
    final name = dir.path.split(Platform.pathSeparator).last;
    // ignore: avoid_print
    print('== $name ==');
    final luaSrc = File('${dir.path}/main.lua').readAsStringSync();
    final definedFns = RegExp(r'function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
        .allMatches(luaSrc)
        .map((m) => m.group(1)!)
        .toSet();

    // 1. 清单
    final manifest =
        jsonDecode(File('${dir.path}/plugin.json').readAsStringSync())
            as Map<String, dynamic>;
    final id = manifest['id']?.toString() ?? '';
    check(RegExp(r'^[a-z0-9_]{3,50}$').hasMatch(id), '$name: id 合法 ($id)');
    check(id == name, '$name: id 与目录名一致');
    for (final field in ['name', 'version', 'description', 'author']) {
      check(manifest[field] != null && manifest[field].toString().isNotEmpty,
          '$name: $field 非空');
    }
    check(manifest['type'] == 'lua', '$name: type=lua');
    check(categories.contains(manifest['category']), '$name: category 合法');
    final perms = (manifest['permissions'] as List? ?? [])
        .map((p) => p.toString())
        .toList();
    check(perms.every(permissions.contains),
        '$name: permissions 均为已知枚举 ($perms)');
    check(File('${dir.path}/${manifest['entry']}').existsSync(),
        '$name: 入口文件存在');

    // 2. Lua 语法
    final ls = LuaState.newState();
    ls.openLibs();
    check(ls.loadString(luaSrc) == ThreadStatus.luaOk, '$name: main.lua 可编译');

    // 3. UI AST
    final ui = jsonDecode(
            File('${dir.path}/${manifest['ui']}').readAsStringSync())
        as Map<String, dynamic>;

    void walk(Map<String, dynamic> node) {
      final type = node['type']?.toString() ?? '';
      check(widgets.contains(type), '$name: 组件类型白名单 ($type)');

      final props = node['props'];
      if (props is Map) {
        final style = props['style']?.toString();
        if (style != null && (type == 'Text' || type == 'SelectableText')) {
          check(styles.contains(style), '$name: 文本样式白名单 ($style)');
        }
        final icon = props['icon']?.toString();
        if (icon != null) {
          check(icons.contains(icon), '$name: 图标白名单 ($icon)');
        }
        if (type == 'Container') {
          final color = props['color']?.toString();
          if (color != null) {
            check(
                RegExp(r'^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(color) ||
                    RegExp(r'^\{\{state\.[A-Za-z0-9_]+\}\}$').hasMatch(color.trim()),
                '$name: Container color 为十六进制或状态插值 ($color)');
          }
        }
      }
      final styleProp = node['style']?.toString(); // 样例风格: style 可外置
      if (styleProp != null) {
        check(styles.contains(styleProp), '$name: 文本样式白名单 ($styleProp)');
      }

      final visible = node['visible'];
      if (visible != null && visible is! bool) {
        check(RegExp(r'^\{\{state\.[A-Za-z0-9_]+\}\}$')
                .hasMatch(visible.toString().trim()),
            '$name: visible 仅支持布尔态或 {{state.key}} ($visible)');
      }

      if (type == 'TextField') {
        check(node['ref'] != null, '$name: TextField 必须声明 ref');
      }

      final events = node['events'];
      if (events is Map) {
        events.forEach((k, v) {
          check(eventKeys.contains(k.toString()), '$name: 事件键白名单 ($k)');
          if (v is Map) {
            final action = v['action']?.toString() ?? '';
            check(actions.contains(action), '$name: 事件 action 白名单 ($action)');
            if (action == 'callLua') {
              final fn = v['function']?.toString() ?? '';
              check(definedFns.contains(fn),
                  '$name: callLua 目标函数已在 main.lua 定义 ($fn)');
            }
            if (action == 'setState') {
              check(v['key'] != null, '$name: setState 事件必须带 key');
            }
          } else {
            check(false, '$name: 事件必须是对象 ($k)');
          }
        });
      }

      final children = node['children'];
      if (children is List) {
        for (final c in children) {
          if (c is Map) walk(Map<String, dynamic>.from(c));
        }
      }
    }

    walk(ui);
    final rootType = ui['type']?.toString();
    check(const {'SingleChildScrollView', 'Column', 'ListView'}
        .contains(rootType), '$name: 根节点为可滚动布局 ($rootType)');

    // 4. main.lua 中不得使用被沙箱封禁的标准库与不可用的模式匹配
    check(!RegExp(r'(^|[^a-zA-Z0-9_])os\.').hasMatch(luaSrc), '$name: 未使用被沙箱封禁的库 (os.)');
    check(!RegExp(r'(^|[^a-zA-Z0-9_])io\.').hasMatch(luaSrc), '$name: 未使用被沙箱封禁的库 (io.)');
    for (final banned in ['require(', 'dofile(', 'loadfile(']) {
      check(!luaSrc.contains(banned), '$name: 未使用被沙箱封禁的库 ($banned)');
    }
    // lua_dardo 分支的模式匹配子系统不可用 (gmatch/gsub 静默失效或 RangeError);
    // math.min 与 max 为同一份复制粘贴实现, 行为等同于 max, 同样禁用
    for (final broken in ['string.gmatch', 'string.gsub', 'string.match',
      'string.reverse', 'math.min']) {
      check(!luaSrc.contains(broken), '$name: 未使用不可用/行为异常的标准函数 ($broken)');
    }
    // string.find 必须显式纯文本模式 (第 4 参 true); 按行粗检, 多行调用请自行拆行
    for (final line in luaSrc.split('\n')) {
      if (line.contains('string.find(')) {
        check(line.contains(', true') || line.contains(',true'),
            '$name: string.find 使用纯文本模式 (第 4 参 true): ${line.trim()}');
      }
    }
    // ignore: avoid_print
    print('');
  }

  // ignore: avoid_print
  print('==== lint: $pass 通过, $fail 失败 ====');
  if (fail > 0) exit(1);
}
