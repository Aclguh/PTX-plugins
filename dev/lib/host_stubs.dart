import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:lua_dardo/lua.dart';

/// 插件开发 harness 的宿主 API 语义桩。
///
/// 与 packages/lua 生产绑定保持同名、同参、同返回语义：
/// - codec/hash/util/system 为同步纯函数，逐一对齐生产实现；
/// - storage/clipboard/network/dialog.confirm 按宿主契约改为同步直调回调；
/// - 网络请求通过 [cannedResponses] 预设响应，未命中时回调 onNetworkError。
class HarnessHost {
  final Map<String, dynamic> stateValues = {};
  final List<String> toasts = [];
  final List<String> alerts = [];
  final Map<String, String> storageBox = {};
  final List<String> networkGets = [];
  final List<String> networkPosts = [];
  String? clipboardText;

  /// url -> {status, body}；未命中时向脚本回调 onNetworkError
  final Map<String, Map<String, String>> cannedResponses = {};

  /// POST 请求的预设响应，键为 url（与生产 network.post 同语义）
  final Map<String, Map<String, String>> cannedPosts = {};

  /// 固定时间戳（秒），供时间相关插件做确定性断言
  int fixedTimestampSec = 1727654400; // 2024-09-30 00:00:00 UTC

  final Random _random = Random.secure();

  void bind(LuaState ls) {
    _bindState(ls);
    _bindDialog(ls);
    _bindClipboard(ls);
    _bindStorage(ls);
    _bindNetwork(ls);
    _bindCodec(ls);
    _bindHash(ls);
    _bindUtil(ls);
    _bindSystem(ls);
    _bindJson(ls);
  }

  // ---- state ----
  void _bindState(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final key = ls.checkString(1) ?? '';
      final val = stateValues[key];
      _pushHostValue(ls, val);
      return 1;
    });
    ls.setField(-2, 'get');
    ls.pushDartFunction((ls) {
      final key = ls.checkString(1) ?? '';
      stateValues[key] = _readHostValue(ls, 2);
      return 0;
    });
    ls.setField(-2, 'set');
    ls.setGlobal('state');
  }

  // ---- dialog ----
  void _bindDialog(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      toasts.add(ls.checkString(1) ?? '');
      return 0;
    });
    ls.setField(-2, 'toast');
    ls.pushDartFunction((ls) {
      alerts.add('${ls.checkString(1) ?? ''}: ${ls.checkString(2) ?? ''}');
      return 0;
    });
    ls.setField(-2, 'alert');
    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 3);
      // harness 中用户永远点"确定"，与宿主异步回调语义一致
      _invokeRef(ls, cbRef, [true]);
      return 0;
    });
    ls.setField(-2, 'confirm');
    ls.setGlobal('dialog');
  }

  // ---- clipboard ----
  void _bindClipboard(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      clipboardText = ls.checkString(1) ?? '';
      return 0;
    });
    ls.setField(-2, 'set');
    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      _invokeRef(ls, cbRef, [clipboardText]);
      return 0;
    });
    ls.setField(-2, 'get');
    ls.setGlobal('clipboard');
  }

  // ---- storage ----
  void _bindStorage(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      storageBox[ls.checkString(1) ?? ''] = ls.checkString(2) ?? '';
      return 0;
    });
    ls.setField(-2, 'set');
    ls.pushDartFunction((ls) {
      final key = ls.checkString(1) ?? '';
      final cbRef = _refFn(ls, 2);
      _invokeRef(ls, cbRef, [storageBox[key]]);
      return 0;
    });
    ls.setField(-2, 'get');
    ls.pushDartFunction((ls) {
      storageBox.remove(ls.checkString(1) ?? '');
      return 0;
    });
    ls.setField(-2, 'remove');
    ls.setGlobal('storage');
  }

  // ---- network ----
  void _bindNetwork(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final url = ls.checkString(1) ?? '';
      networkGets.add(url);
      final canned = cannedResponses[url];
      if (canned != null) {
        // 与生产 NetworkApi 对齐: 状态码为整数, 字符串会让插件的
        // `status ~= 200` 比较永真而走错分支
        final statusCode = int.tryParse(canned['status'] ?? '200') ?? 200;
        stateValues['__http_status'] = statusCode;
        stateValues['__http_body'] = canned['body'];
        _invokeGlobal(ls, 'onNetworkResponse', [statusCode, canned['body']]);
      } else {
        stateValues['__http_error'] = 'harness: 无预设响应';
        _invokeGlobal(ls, 'onNetworkError', ['harness: 无预设响应']);
      }
      return 0;
    });
    ls.setField(-2, 'get');
    ls.pushDartFunction((ls) {
      final url = ls.checkString(1) ?? '';
      final body = ls.checkString(2) ?? '';
      networkPosts.add('$url <= $body');
      final canned = cannedPosts[url];
      if (canned != null) {
        final statusCode = int.tryParse(canned['status'] ?? '200') ?? 200;
        stateValues['__http_status'] = statusCode;
        stateValues['__http_body'] = canned['body'];
        _invokeGlobal(ls, 'onNetworkResponse', [statusCode, canned['body']]);
      } else {
        stateValues['__http_error'] = 'harness: 无预设 POST 响应';
        _invokeGlobal(ls, 'onNetworkError', ['harness: 无预设 POST 响应']);
      }
      return 0;
    });
    ls.setField(-2, 'post');
    ls.setGlobal('network');
  }

  // ---- codec (对齐 CodecApi 生产语义) ----
  void _bindCodec(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      ls.pushString(base64Encode(utf8.encode(ls.checkString(1) ?? '')));
      return 1;
    });
    ls.setField(-2, 'base64Encode');
    ls.pushDartFunction((ls) {
      ls.pushString(utf8.decode(base64Decode(ls.checkString(1) ?? '')));
      return 1;
    });
    ls.setField(-2, 'base64Decode');
    ls.pushDartFunction((ls) {
      ls.pushString(Uri.encodeComponent(ls.checkString(1) ?? ''));
      return 1;
    });
    ls.setField(-2, 'urlEncode');
    ls.pushDartFunction((ls) {
      ls.pushString(Uri.decodeComponent(ls.checkString(1) ?? ''));
      return 1;
    });
    ls.setField(-2, 'urlDecode');
    ls.setGlobal('codec');
  }

  // ---- hash (对齐 HashApi 生产语义) ----
  void _bindHash(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      ls.pushString(crypto.md5.convert(utf8.encode(ls.checkString(1) ?? '')).toString());
      return 1;
    });
    ls.setField(-2, 'md5');
    ls.pushDartFunction((ls) {
      ls.pushString(crypto.sha1.convert(utf8.encode(ls.checkString(1) ?? '')).toString());
      return 1;
    });
    ls.setField(-2, 'sha1');
    ls.pushDartFunction((ls) {
      ls.pushString(crypto.sha256.convert(utf8.encode(ls.checkString(1) ?? '')).toString());
      return 1;
    });
    ls.setField(-2, 'sha256');
    ls.setGlobal('hash');
  }

  // ---- util (对齐 UtilApi 生产语义) ----
  void _bindUtil(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      ls.pushString(_uuidV4());
      return 1;
    });
    ls.setField(-2, 'uuid');
    ls.pushDartFunction((ls) {
      ls.pushInteger(fixedTimestampSec);
      return 1;
    });
    ls.setField(-2, 'timestamp');
    ls.pushDartFunction((ls) {
      ls.pushInteger(fixedTimestampSec * 1000);
      return 1;
    });
    ls.setField(-2, 'timestampMs');
    ls.setGlobal('util');
  }

  // ---- system (对齐 SystemApi 生产语义, 取值为 harness 固定桩值) ----
  void _bindSystem(LuaState ls) {
    ls.newTable();
    void fn(String name, int Function(LuaState) impl) {
      ls.pushDartFunction(impl);
      ls.setField(-2, name);
    }

    fn('platform', (ls) {
      ls.pushString('android');
      return 1;
    });
    fn('osVersion', (ls) {
      ls.pushString('harness-android-14');
      return 1;
    });
    fn('hostname', (ls) {
      ls.pushString('harness-device');
      return 1;
    });
    fn('cores', (ls) {
      ls.pushInteger(8);
      return 1;
    });
    fn('locale', (ls) {
      ls.pushString('zh_CN');
      return 1;
    });
    fn('screenWidth', (ls) {
      ls.pushInteger(1080);
      return 1;
    });
    fn('screenHeight', (ls) {
      ls.pushInteger(2400);
      return 1;
    });
    fn('pixelRatio', (ls) {
      ls.pushNumber(2.75);
      return 1;
    });
    fn('brightness', (ls) {
      ls.pushString('dark');
      return 1;
    });
    ls.setGlobal('system');
  }

  // ---- json (对齐 JsonApi 生产语义: 数组判据、null->键缺失、循环/深度防御) ----
  static const int _jsonMaxDepth = 64;

  void _bindJson(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      if (ls.getTop() < 1) {
        ls.error2('json.encode 缺少参数: 需要一个可序列化值');
        return 0;
      }
      final dart = _readJsonValue(ls, 1, <Object?>{}, 0);
      ls.pushString(jsonEncode(dart));
      return 1;
    });
    ls.setField(-2, 'encode');
    ls.pushDartFunction((ls) {
      final text = ls.checkString(1) ?? '';
      if (_jsonBracketDepth(text) > _jsonMaxDepth) {
        ls.error2('JSON 解析失败: 嵌套层级超过 $_jsonMaxDepth');
        return 0;
      }
      _pushJsonValue(ls, jsonDecode(text), 0);
      return 1;
    });
    ls.setField(-2, 'decode');
    ls.setGlobal('json');
  }

  static dynamic _readJsonValue(LuaState ls, int idx, Set<Object?> seen, int depth) {
    if (depth > _jsonMaxDepth) {
      ls.error2('JSON 序列化失败: 嵌套层级超过 $_jsonMaxDepth');
    }
    switch (ls.type(idx)) {
      case LuaType.luaNil:
        return null;
      case LuaType.luaBoolean:
        return ls.toBoolean(idx);
      case LuaType.luaNumber:
        return ls.isInteger(idx) ? ls.toInteger(idx) : ls.toNumber(idx);
      case LuaType.luaString:
        return ls.toStr(idx);
      case LuaType.luaTable:
        final absIdx = idx < 0 ? ls.getTop() + idx + 1 : idx;
        final identity = ls.toPointer(absIdx);
        if (seen.contains(identity)) {
          ls.error2('JSON 序列化失败: 表存在循环引用');
        }
        seen.add(identity);
        final entries = <dynamic, dynamic>{};
        ls.pushNil();
        while (ls.next(absIdx)) {
          final keyType = ls.type(-2);
          dynamic key;
          if (keyType == LuaType.luaString) {
            key = ls.toStr(-2);
          } else if (keyType == LuaType.luaNumber) {
            key = ls.isInteger(-2) ? ls.toInteger(-2) : ls.toNumber(-2);
          } else {
            ls.pop(1);
            continue;
          }
          entries[key] = _readJsonValue(ls, -1, seen, depth + 1);
          ls.pop(1);
        }
        seen.remove(identity);
        if (entries.isEmpty) return <String, dynamic>{};
        var isSequentialArray = true;
        for (var i = 1; i <= entries.length; i++) {
          if (!entries.containsKey(i)) {
            isSequentialArray = false;
            break;
          }
        }
        if (isSequentialArray) {
          return [for (var i = 1; i <= entries.length; i++) entries[i]];
        }
        return {for (final e in entries.entries) e.key.toString(): e.value};
      default:
        ls.error2('JSON 序列化失败: 不支持的类型 ${ls.typeName2(idx)}');
        return null;
    }
  }

  static void _pushJsonValue(LuaState ls, Object? val, int depth) {
    if (depth > _jsonMaxDepth) {
      ls.error2('JSON 解析失败: 嵌套层级超过 $_jsonMaxDepth');
    }
    if (val == null) {
      ls.pushNil();
    } else if (val is bool) {
      ls.pushBoolean(val);
    } else if (val is int) {
      ls.pushInteger(val);
    } else if (val is num) {
      ls.pushNumber(val.toDouble());
    } else if (val is String) {
      ls.pushString(val);
    } else if (val is List) {
      ls.newTable();
      for (var i = 0; i < val.length; i++) {
        ls.pushInteger(i + 1);
        _pushJsonValue(ls, val[i], depth + 1);
        ls.setTable(-3);
      }
    } else if (val is Map) {
      ls.newTable();
      val.forEach((k, v) {
        ls.pushString(k.toString());
        _pushJsonValue(ls, v, depth + 1);
        ls.setTable(-3);
      });
    } else {
      ls.pushString(val.toString());
    }
  }

  static int _jsonBracketDepth(String text) {
    var depth = 0, maxDepthSeen = 0;
    var inString = false, escaped = false;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{' || ch == '[') {
        depth++;
        if (depth > maxDepthSeen) maxDepthSeen = depth;
      } else if (ch == '}' || ch == ']') {
        depth--;
        if (depth < 0) depth = 0;
      }
    }
    return maxDepthSeen;
  }

  String _uuidV4() {
    String hex(int n) => _random.nextInt(1 << n).toRadixString(16).padLeft(n >> 2, '0');
    // 变体位须以十六进制呈现 (8-b), 十进制插值会产出 "10"/"11" 两位数;
    // 尾组为 12 位 (8+4), 与标准 8-4-4-4-12 分段一致
    final variant = (_random.nextInt(4) + 8).toRadixString(16);
    return '${hex(32)}-${hex(16)}-4${hex(12)}-$variant${hex(12)}-${hex(32)}${hex(16)}';
  }

  static void _pushHostValue(LuaState ls, dynamic val) {
    if (val == null) {
      ls.pushNil();
    } else if (val is bool) {
      ls.pushBoolean(val);
    } else if (val is int) {
      ls.pushInteger(val);
    } else if (val is double) {
      ls.pushNumber(val);
    } else {
      ls.pushString(val.toString());
    }
  }

  static dynamic _readHostValue(LuaState ls, int idx) {
    switch (ls.type(idx)) {
      case LuaType.luaBoolean:
        return ls.toBoolean(idx);
      case LuaType.luaNumber:
        return ls.isInteger(idx) ? ls.toInteger(idx) : ls.toNumber(idx);
      case LuaType.luaString:
        return ls.toStr(idx);
      default:
        return null;
    }
  }

  static int? _refFn(LuaState ls, int stackIdx) {
    if (ls.type(stackIdx) != LuaType.luaFunction) return null;
    ls.pushValue(stackIdx);
    return ls.ref(luaRegistryIndex);
  }

  static void _invokeRef(LuaState ls, int? ref, List<Object?> args) {
    if (ref == null) return;
    ls.rawGetI(luaRegistryIndex, ref);
    ls.unRef(luaRegistryIndex, ref);
    _callTop(ls, args);
  }

  static void _invokeGlobal(LuaState ls, String name, List<Object?> args) {
    if (ls.getGlobal(name) != LuaType.luaFunction) {
      ls.pop(1);
      return;
    }
    _callTop(ls, args);
  }

  static void _callTop(LuaState ls, List<Object?> args) {
    for (final arg in args) {
      _pushHostValue(ls, arg);
    }
    final status = ls.pCall(args.length, 0, 0);
    if (status != ThreadStatus.luaOk) {
      // 有意区别于宿主的静默吞错: 开发期应让回调内的 Lua 错误显式暴露
      // ignore: avoid_print
      print('CALLBACK ERROR: ${ls.toStr(-1)}');
      ls.pop(1);
    }
  }
}
