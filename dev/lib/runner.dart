import 'dart:convert';
import 'dart:io';

import 'package:lua_dardo/lua.dart';

import 'host_stubs.dart';

/// 单个插件的测试运行环境：加载 plugin.json + main.lua，执行 onInit，
/// 之后可通过 [call] 模拟 UI 事件调用。
class PluginEnv {
  final HarnessHost host = HarnessHost();
  final LuaState ls;
  final String pluginId;
  final String dir;
  Map<String, dynamic> manifest;

  PluginEnv._(this.pluginId, this.dir, this.manifest) : ls = LuaState.newState() {
    ls.openLibs();
    host.bind(ls);
  }

  static PluginEnv load(String dir) {
    final manifestFile = File('$dir/plugin.json');
    if (!manifestFile.existsSync()) {
      throw Exception('缺少 plugin.json: $dir');
    }
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final env = PluginEnv._(manifest['id'] as String, dir, manifest);

    final entry = manifest['entry']?.toString() ?? 'main.lua';
    final code = File('$dir/$entry').readAsStringSync();
    if (env.ls.loadString(code) != ThreadStatus.luaOk) {
      throw Exception('[${env.pluginId}] Lua 编译错误: ${env.ls.toStr(-1)}');
    }
    if (env.ls.pCall(0, 0, 0) != ThreadStatus.luaOk) {
      throw Exception('[${env.pluginId}] Lua 执行错误: ${env.ls.toStr(-1)}');
    }
    env.call('onInit');
    return env;
  }

  /// 模拟 UI 事件调用全局 Lua 函数（与宿主 dispatchAction 同语义）
  dynamic call(String fn, [List<dynamic> args = const []]) {
    if (ls.getGlobal(fn) != LuaType.luaFunction) {
      ls.pop(1);
      throw Exception('[${pluginId}] Lua 函数未定义: $fn');
    }
    for (final arg in args) {
      _pushValue(arg);
    }
    if (ls.pCall(args.length, 1, 0) != ThreadStatus.luaOk) {
      final err = ls.toStr(-1) ?? 'unknown';
      ls.pop(1);
      throw Exception('[${pluginId}] 调用 $fn 失败: $err');
    }
    final res = _popValue();
    return res;
  }

  /// 直接读取一段 Lua 表达式的值（测试钩子用，如 env.eval('return _qr_matrix("hi","M")')）
  dynamic eval(String chunk) {
    if (ls.loadString(chunk) != ThreadStatus.luaOk) {
      throw Exception('eval 编译错误: ${ls.toStr(-1)}');
    }
    if (ls.pCall(0, 1, 0) != ThreadStatus.luaOk) {
      final err = ls.toStr(-1) ?? 'unknown';
      ls.pop(1);
      throw Exception('eval 执行错误: $err');
    }
    final res = _popValue();
    return res;
  }

  void _pushValue(dynamic val, [Set<Object?>? visited]) {
    if (val is Map || val is List) {
      final seen = visited ??= <Object?>{};
      if (seen.contains(val)) throw Exception('循环引用');
      seen.add(val);
    }
    if (val == null) {
      ls.pushNil();
    } else if (val is bool) {
      ls.pushBoolean(val);
    } else if (val is int) {
      ls.pushInteger(val);
    } else if (val is double) {
      ls.pushNumber(val);
    } else if (val is String) {
      ls.pushString(val);
    } else if (val is Map) {
      ls.newTable();
      val.forEach((k, v) {
        ls.pushString(k.toString());
        _pushValue(v, visited);
        ls.setTable(-3);
      });
    } else if (val is List) {
      ls.newTable();
      for (var i = 0; i < val.length; i++) {
        ls.pushInteger(i + 1);
        _pushValue(val[i], visited);
        ls.setTable(-3);
      }
    } else {
      ls.pushString(val.toString());
    }
    visited?.remove(val);
  }

  dynamic _popValue() {
    switch (ls.type(-1)) {
      case LuaType.luaNil:
        ls.pop(1);
        return null;
      case LuaType.luaBoolean:
        final b = ls.toBoolean(-1);
        ls.pop(1);
        return b;
      case LuaType.luaNumber:
        final n = ls.isInteger(-1) ? ls.toInteger(-1) : ls.toNumber(-1);
        ls.pop(1);
        return n;
      case LuaType.luaString:
        final s = ls.toStr(-1);
        ls.pop(1);
        return s;
      case LuaType.luaTable:
        final t = _readTable(-1);
        ls.pop(1);
        return t;
      default:
        ls.pop(1);
        return null;
    }
  }

  Map<String, dynamic> _readTable(int idx) {
    final map = <String, dynamic>{};
    ls.pushNil();
    while (ls.next(idx < 0 ? idx - 1 : idx)) {
      final key = ls.toStr(-2) ?? ls.toInteger(-2).toString();
      map[key] = _readCurrentValue();
      ls.pop(1);
    }
    return map;
  }

  dynamic _readCurrentValue() {
    switch (ls.type(-1)) {
      case LuaType.luaNil:
        return null;
      case LuaType.luaBoolean:
        return ls.toBoolean(-1);
      case LuaType.luaNumber:
        return ls.isInteger(-1) ? ls.toInteger(-1) : ls.toNumber(-1);
      case LuaType.luaString:
        return ls.toStr(-1);
      case LuaType.luaTable:
        return _readTable(-1);
      default:
        return null;
    }
  }
}

/// 极简断言器
class Checks {
  static int pass = 0;
  static int fail = 0;
  static final List<String> failures = [];

  static void check(bool cond, String label, [Object? actual, Object? expected]) {
    if (cond) {
      pass++;
    } else {
      fail++;
      failures.add(label);
      // ignore: avoid_print
      print('  FAIL $label'
          '${actual != null || expected != null ? ' -> 实际: $actual 期望: $expected' : ''}');
    }
  }

  static void group(String name) {
    // ignore: avoid_print
    print('--- $name ---');
  }

  static int finish(String suiteName) {
    // ignore: avoid_print
    print('\n==== $suiteName: $pass 通过, $fail 失败 ====');
    if (fail > 0) exitCode = 1;
    return fail;
  }
}
