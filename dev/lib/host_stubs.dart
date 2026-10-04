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
  String? clipboardText;

  /// url -> {status, body}；未命中时向脚本回调 onNetworkError
  final Map<String, Map<String, String>> cannedResponses = {};

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
