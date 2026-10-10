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

  String scannedBarcode = 'https://github.com/Aclguh/PTX-plugins';
  String decodedBarcode = 'https://github.com/Aclguh/PTX-plugins';
  String pickedImagePath = 'data/test_qr.png';
  String pickedFilePath = 'data/sample.txt';
  final Map<String, String> fsFiles = {};
  String recognizedOcrText = '离线 OCR 识别文本样例\n发票代码: 12345678\n金额: 99.00';
  List<String> recognizedOcrLines = ['离线 OCR 识别文本样例', '发票代码: 12345678', '金额: 99.00'];
  double decibelLevel = 58.5;
  bool isPlayingTone = false;
  double compassHeading = 128.5;
  double accelerometerX = 0.15;
  double accelerometerY = 0.22;
  double accelerometerZ = 9.81;
  Map<String, dynamic> sampleImageInfo = {
    'width': 1920,
    'height': 1080,
    'format': 'jpeg',
    'size': 204800,
    'hasExif': true,
    'make': 'CameraBrand',
    'model': 'X100',
    'latitude': 39.9042,
    'longitude': 116.4074,
  };
  final List<String> sharedTexts = [];
  final List<String> sharedFiles = [];
  bool torchOn = false;
  bool screenKeepOn = false;
  double screenBrightness = 0.8;
  bool bleScanning = false;
  final List<String> dbExecLog = [];
  final List<String> dbQueryLog = [];
  final Map<String, List<Map<String, dynamic>>> dbMockRows = {};
  bool biometricsAvailable = true;
  bool nfcAvailable = true;
  bool aiAvailable = true;
  final List<String> wsUrlLog = [];
  final List<String> wsSentMessages = [];
  final List<String> hapticFeedbacks = [];
  bool locationAvailable = true;
  double locationLatitude = 39.9042;
  double locationLongitude = 116.4074;
  double locationAltitude = 52.8;
  double locationSpeed = 16.5; // m/s (59.4 km/h)
  double locationAccuracy = 5.0;

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
    _bindCamera(ls);
    _bindMedia(ls);
    _bindFs(ls);
    _bindVision(ls);
    _bindAudio(ls);
    _bindSensor(ls);
    _bindImage(ls);
    _bindShare(ls);
    _bindTorch(ls);
    _bindScreen(ls);
    _bindBluetooth(ls);
    _bindDatabase(ls);
    _bindBiometrics(ls);
    _bindCrypto(ls);
    _bindNfc(ls);
    _bindWebsocket(ls);
    _bindAi(ls);
    _bindTimer(ls);
    _bindHaptic(ls);
    _bindDocument(ls);
    _bindLocation(ls);
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
    ls.pushDartFunction((ls) {
      final ms = ls.checkInteger(1) ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ms > 10000000000 ? ms : ms * 1000);
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      final sec = dt.second.toString().padLeft(2, '0');
      ls.pushString('$y-$m-$d $h:$min:$sec');
      return 1;
    });
    ls.setField(-2, 'formatTime');
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

  // ---- camera ----
  void _bindCamera(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      int? cbRef;
      if (ls.type(1) == LuaType.luaFunction) {
        cbRef = _refFn(ls, 1);
      } else if (ls.type(2) == LuaType.luaFunction) {
        cbRef = _refFn(ls, 2);
      }
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [scannedBarcode]);
      } else {
        stateValues['__scanned_code'] = scannedBarcode;
      }
      return 0;
    });
    ls.setField(-2, 'scan');

    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 2);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [decodedBarcode]);
      } else {
        stateValues['__decoded_code'] = decodedBarcode;
      }
      return 0;
    });
    ls.setField(-2, 'decodeImage');

    ls.setGlobal('camera');
  }

  // ---- media ----
  void _bindMedia(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [pickedImagePath]);
      } else {
        stateValues['__picked_image'] = pickedImagePath;
      }
      return 0;
    });
    ls.setField(-2, 'pickImage');

    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [pickedFilePath]);
      } else {
        stateValues['__picked_file'] = pickedFilePath;
      }
      return 0;
    });
    ls.setField(-2, 'pickFile');

    ls.setGlobal('media');
  }

  // ---- fs ----
  void _bindFs(LuaState ls) {
    ls.newTable();

    ls.pushDartFunction((ls) {
      final relPath = ls.checkString(1) ?? '';
      final content = fsFiles[relPath];
      if (content == null) {
        ls.pushNil();
        ls.pushString('文件不存在: $relPath');
        return 2;
      }
      ls.pushString(content);
      return 1;
    });
    ls.setField(-2, 'readFile');

    ls.pushDartFunction((ls) {
      final relPath = ls.checkString(1) ?? '';
      final content = ls.checkString(2) ?? '';
      fsFiles[relPath] = content;
      ls.pushBoolean(true);
      return 1;
    });
    ls.setField(-2, 'writeFile');

    ls.pushDartFunction((ls) {
      final relPath = ls.checkString(1) ?? '';
      final content = ls.checkString(2) ?? '';
      fsFiles[relPath] = content;
      ls.pushBoolean(true);
      return 1;
    });
    ls.setField(-2, 'writeBase64');

    ls.pushDartFunction((ls) {
      final relPath = ls.checkString(1) ?? '';
      final content = fsFiles[relPath] ?? '';
      ls.pushString(content);
      return 1;
    });
    ls.setField(-2, 'readBase64');

    ls.pushDartFunction((ls) {
      final relPath = ls.checkString(1) ?? '';
      ls.pushBoolean(fsFiles.containsKey(relPath));
      return 1;
    });
    ls.setField(-2, 'exists');

    ls.pushDartFunction((ls) {
      final relPath = ls.checkString(1) ?? '';
      fsFiles.remove(relPath);
      ls.pushBoolean(true);
      return 1;
    });
    ls.setField(-2, 'remove');

    ls.pushDartFunction((ls) {
      int? cbRef;
      if (ls.type(1) == LuaType.luaFunction) {
        cbRef = _refFn(ls, 1);
      } else if (ls.type(2) == LuaType.luaFunction) {
        cbRef = _refFn(ls, 2);
      }
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [pickedFilePath]);
      } else {
        stateValues['__picked_file'] = pickedFilePath;
      }
      return 0;
    });
    ls.setField(-2, 'pickFile');

    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 2);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [true]);
      }
      return 0;
    });
    ls.setField(-2, 'saveToGallery');

    ls.pushDartFunction((ls) {
      int? cbRef;
      if (ls.type(2) == LuaType.luaFunction) {
        cbRef = _refFn(ls, 2);
      } else if (ls.type(3) == LuaType.luaFunction) {
        cbRef = _refFn(ls, 3);
      }
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [true]);
      }
      return 0;
    });
    ls.setField(-2, 'exportFile');

    ls.pushDartFunction((ls) {
      final relPath = ls.checkString(1) ?? '';
      final content = fsFiles[relPath] ?? 'sample file data for harness';
      final bytes = utf8.encode(content);
      final algo = ls.type(2) == LuaType.luaString ? ls.toStr(2)?.toLowerCase() : null;

      if (algo == 'md5') {
        ls.pushString(crypto.md5.convert(bytes).toString());
        return 1;
      } else if (algo == 'sha1') {
        ls.pushString(crypto.sha1.convert(bytes).toString());
        return 1;
      } else if (algo == 'sha256') {
        ls.pushString(crypto.sha256.convert(bytes).toString());
        return 1;
      } else if (algo == 'crc32') {
        ls.pushString('27F013DB');
        return 1;
      } else {
        final fileName = relPath.contains('/')
            ? relPath.substring(relPath.lastIndexOf('/') + 1)
            : relPath;
        final dotIdx = fileName.lastIndexOf('.');
        final ext = dotIdx >= 0 ? fileName.substring(dotIdx + 1) : '';

        ls.newTable();
        ls.pushString('name');
        ls.pushString(fileName);
        ls.setTable(-3);

        ls.pushString('size');
        ls.pushInteger(bytes.length);
        ls.setTable(-3);

        ls.pushString('extension');
        ls.pushString(ext);
        ls.setTable(-3);

        ls.pushString('modifiedMs');
        ls.pushInteger(fixedTimestampSec * 1000);
        ls.setTable(-3);

        ls.pushString('md5');
        ls.pushString(crypto.md5.convert(bytes).toString());
        ls.setTable(-3);

        ls.pushString('sha1');
        ls.pushString(crypto.sha1.convert(bytes).toString());
        ls.setTable(-3);

        ls.pushString('sha256');
        ls.pushString(crypto.sha256.convert(bytes).toString());
        ls.setTable(-3);

        ls.pushString('crc32');
        ls.pushString('27F013DB');
        ls.setTable(-3);

        return 1;
      }
    });
    ls.setField(-2, 'hash');

    ls.setGlobal('fs');
  }

  // ---- vision ----
  void _bindVision(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 2);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [
          {
            'ok': true,
            'text': recognizedOcrText,
            'lines': recognizedOcrLines,
          }
        ]);
      } else {
        stateValues['__ocr_text'] = recognizedOcrText;
      }
      return 0;
    });
    ls.setField(-2, 'recognizeText');

    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 2);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [decodedBarcode]);
      } else {
        stateValues['__decoded_code'] = decodedBarcode;
      }
      return 0;
    });
    ls.setField(-2, 'decodeBarcode');
    ls.setGlobal('vision');
  }

  // ---- audio ----
  void _bindAudio(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [decibelLevel]);
      }
      ls.pushNumber(decibelLevel);
      return 1;
    });
    ls.setField(-2, 'getDecibel');

    ls.pushDartFunction((ls) {
      isPlayingTone = true;
      final cbRef = _refFn(ls, 3);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [true]);
      }
      ls.pushBoolean(true);
      return 1;
    });
    ls.setField(-2, 'playTone');

    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 2);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [true]);
      }
      ls.pushBoolean(true);
      return 1;
    });
    ls.setField(-2, 'play');

    ls.pushDartFunction((ls) {
      isPlayingTone = false;
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [true]);
      }
      ls.pushBoolean(true);
      return 1;
    });
    ls.setField(-2, 'stop');
    ls.setGlobal('audio');
  }

  // ---- sensor ----
  void _bindSensor(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      ls.pushBoolean(true);
      return 1;
    });
    ls.setField(-2, 'isAvailable');

    ls.pushDartFunction((ls) {
      _pushJsonValue(ls, {
        'heading': compassHeading,
        'accuracy': 15.0,
      }, 0);
      return 1;
    });
    ls.setField(-2, 'getCompass');

    ls.pushDartFunction((ls) {
      _pushJsonValue(ls, {
        'x': accelerometerX,
        'y': accelerometerY,
        'z': accelerometerZ,
      }, 0);
      return 1;
    });
    ls.setField(-2, 'getAccelerometer');

    ls.pushDartFunction((ls) {
      _pushJsonValue(ls, {
        'x': 0.0,
        'y': 0.0,
        'z': 0.0,
      }, 0);
      return 1;
    });
    ls.setField(-2, 'getGyroscope');
    ls.setGlobal('sensor');
  }

  // ---- image ----
  void _bindImage(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 2);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [sampleImageInfo]);
      } else {
        _pushJsonValue(ls, sampleImageInfo, 0);
        return 1;
      }
      return 0;
    });
    ls.setField(-2, 'info');

    ls.pushDartFunction((ls) {
      final relPath = ls.checkString(1) ?? '';
      final cbRef = _refFn(ls, 2);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [{'ok': true, 'path': relPath}]);
      }
      ls.pushBoolean(true);
      return 1;
    });
    ls.setField(-2, 'stripExif');

    ls.pushDartFunction((ls) {
      final relPath = ls.checkString(1) ?? '';
      final cbRef = _refFn(ls, 3);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [{'ok': true, 'path': relPath}]);
      }
      ls.pushBoolean(true);
      return 1;
    });
    ls.setField(-2, 'compress');
    ls.setGlobal('image');
  }

  // ---- share ----
  void _bindShare(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final text = ls.checkString(1) ?? '';
      sharedTexts.add(text);
      return 0;
    });
    ls.setField(-2, 'text');

    ls.pushDartFunction((ls) {
      final file = ls.checkString(1) ?? '';
      sharedFiles.add(file);
      final cbRef = _refFn(ls, 4) ?? _refFn(ls, 2);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [true]);
      }
      return 0;
    });
    ls.setField(-2, 'file');
    ls.setGlobal('share');
  }

  // ---- torch ----
  void _bindTorch(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      torchOn = true;
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) _invokeRef(ls, cbRef, [true]);
      return 0;
    });
    ls.setField(-2, 'on');

    ls.pushDartFunction((ls) {
      torchOn = false;
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) _invokeRef(ls, cbRef, [true]);
      return 0;
    });
    ls.setField(-2, 'off');

    ls.pushDartFunction((ls) {
      torchOn = !torchOn;
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) _invokeRef(ls, cbRef, [torchOn]);
      return 0;
    });
    ls.setField(-2, 'toggle');

    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) _invokeRef(ls, cbRef, [torchOn]);
      ls.pushBoolean(torchOn);
      return 1;
    });
    ls.setField(-2, 'status');
    ls.setGlobal('torch');
  }

  // ---- screen ----
  void _bindScreen(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      screenKeepOn = ls.toBoolean(1);
      final cbRef = _refFn(ls, 2);
      if (cbRef != null) _invokeRef(ls, cbRef, [true]);
      return 0;
    });
    ls.setField(-2, 'setKeepScreenOn');

    ls.pushDartFunction((ls) {
      screenBrightness = ls.toNumber(1).clamp(0.0, 1.0);
      final cbRef = _refFn(ls, 2);
      if (cbRef != null) _invokeRef(ls, cbRef, [true]);
      return 0;
    });
    ls.setField(-2, 'setBrightness');

    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) _invokeRef(ls, cbRef, [screenBrightness]);
      ls.pushNumber(screenBrightness);
      return 1;
    });
    ls.setField(-2, 'getBrightness');
    ls.setGlobal('screen');
  }

  // ---- bluetooth ----
  void _bindBluetooth(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) _invokeRef(ls, cbRef, [true]);
      ls.pushBoolean(true);
      return 1;
    });
    ls.setField(-2, 'isAvailable');

    ls.pushDartFunction((ls) {
      bleScanning = true;
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [
          {
            'ok': true,
            'device': {
              'id': 'AA:BB:CC:DD:EE:01',
              'name': 'BLE-SmartSensor',
              'rssi': -65,
            }
          }
        ]);
      }
      return 0;
    });
    ls.setField(-2, 'startScan');

    ls.pushDartFunction((ls) {
      bleScanning = false;
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) _invokeRef(ls, cbRef, [true]);
      return 0;
    });
    ls.setField(-2, 'stopScan');
    ls.setGlobal('bluetooth');
  }

  // ---- database (db) ----
  void _bindDatabase(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final sql = ls.checkString(1) ?? '';
      int? cbRef;
      if (ls.type(2) == LuaType.luaFunction) {
        cbRef = _refFn(ls, 2);
      } else if (ls.type(3) == LuaType.luaFunction) {
        cbRef = _refFn(ls, 3);
      }
      dbExecLog.add(sql);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [{'ok': true, 'affectedRows': 1}]);
      }
      return 0;
    });
    ls.setField(-2, 'execute');

    ls.pushDartFunction((ls) {
      final sql = ls.checkString(1) ?? '';
      int? cbRef;
      if (ls.type(2) == LuaType.luaFunction) {
        cbRef = _refFn(ls, 2);
      } else if (ls.type(3) == LuaType.luaFunction) {
        cbRef = _refFn(ls, 3);
      }
      dbQueryLog.add(sql);
      final rows = dbMockRows[sql] ?? [
        {'id': 1, 'category': '餐饮', 'amount': 25.5, 'date': '2026-10-09', 'note': '午餐'},
        {'id': 2, 'category': '交通', 'amount': 4.0, 'date': '2026-10-09', 'note': '地铁'},
      ];
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [{'ok': true, 'rows': rows}]);
      }
      return 0;
    });
    ls.setField(-2, 'query');
    ls.setGlobal('db');
  }

  // ---- biometrics ----
  void _bindBiometrics(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) _invokeRef(ls, cbRef, [biometricsAvailable]);
      ls.pushBoolean(biometricsAvailable);
      return 1;
    });
    ls.setField(-2, 'isAvailable');

    ls.pushDartFunction((ls) {
      int? cbRef;
      if (ls.type(1) == LuaType.luaFunction) {
        cbRef = _refFn(ls, 1);
      } else if (ls.type(2) == LuaType.luaFunction) {
        cbRef = _refFn(ls, 2);
      }
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [{'ok': true}]);
      }
      return 0;
    });
    ls.setField(-2, 'authenticate');
    ls.setGlobal('biometrics');
  }

  // ---- crypto ----
  void _bindCrypto(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final key = ls.checkString(1) ?? '';
      final msg = ls.checkString(2) ?? '';
      final h = crypto.Hmac(crypto.sha256, utf8.encode(key)).convert(utf8.encode(msg));
      ls.pushString(h.toString());
      return 1;
    });
    ls.setField(-2, 'hmacSha256');

    ls.pushDartFunction((ls) {
      final key = ls.checkString(1) ?? '';
      final msg = ls.checkString(2) ?? '';
      final h = crypto.Hmac(crypto.md5, utf8.encode(key)).convert(utf8.encode(msg));
      ls.pushString(h.toString());
      return 1;
    });
    ls.setField(-2, 'hmacMd5');

    ls.pushDartFunction((ls) {
      final msg = ls.checkString(1) ?? '';
      final h = crypto.sha512.convert(utf8.encode(msg));
      ls.pushString(h.toString());
      return 1;
    });
    ls.setField(-2, 'sha512');
    ls.setGlobal('crypto');
  }

  // ---- nfc ----
  void _bindNfc(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) _invokeRef(ls, cbRef, [nfcAvailable]);
      ls.pushBoolean(nfcAvailable);
      return 1;
    });
    ls.setField(-2, 'isAvailable');

    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [
          {
            'ok': true,
            'records': [
              {'type': 'text', 'payload': 'https://example.com/nfc-tag'}
            ]
          }
        ]);
      }
      return 0;
    });
    ls.setField(-2, 'readNdef');

    ls.pushDartFunction((ls) {
      int? cbRef;
      if (ls.type(2) == LuaType.luaFunction) cbRef = _refFn(ls, 2);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [{'ok': true}]);
      }
      return 0;
    });
    ls.setField(-2, 'writeNdef');
    ls.setGlobal('nfc');
  }

  // ---- websocket ----
  void _bindWebsocket(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final url = ls.checkString(1) ?? '';
      wsUrlLog.add(url);
      if (ls.type(2) == LuaType.luaTable) {
        ls.getField(2, 'onOpen');
        if (ls.type(-1) == LuaType.luaFunction) {
          final cb = _refFn(ls, -1);
          _invokeRef(ls, cb, []);
        } else {
          ls.pop(1);
        }
      }
      ls.pushString('ws_101');
      return 1;
    });
    ls.setField(-2, 'connect');

    ls.pushDartFunction((ls) {
      final id = ls.checkString(1) ?? '';
      final msg = ls.checkString(2) ?? '';
      wsSentMessages.add('$id: $msg');
      ls.pushBoolean(true);
      return 1;
    });
    ls.setField(-2, 'send');

    ls.pushDartFunction((ls) {
      ls.pushBoolean(true);
      return 1;
    });
    ls.setField(-2, 'close');
    ls.setGlobal('websocket');
  }

  // ---- ai ----
  void _bindAi(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) _invokeRef(ls, cbRef, [aiAvailable]);
      ls.pushBoolean(aiAvailable);
      return 1;
    });
    ls.setField(-2, 'isAvailable');

    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 2);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [
          {
            'ok': true,
            'content': '【AI 润色与生成结果】\n本周主要完成了模块架构演进与全量能力拓展，各指标均达到预期。',
          }
        ]);
      }
      return 0;
    });
    ls.setField(-2, 'chat');
    ls.setGlobal('ai');
  }

  // ---- timer ----
  void _bindTimer(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 2);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, []);
      }
      ls.pushInteger(1);
      return 1;
    });
    ls.setField(-2, 'setTimeout');

    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 2);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, []);
      }
      ls.pushInteger(2);
      return 1;
    });
    ls.setField(-2, 'setInterval');

    ls.pushDartFunction((ls) {
      return 0;
    });
    ls.setField(-2, 'clear');
    ls.setGlobal('timer');
  }

  // ---- haptic ----
  void _bindHaptic(LuaState ls) {
    ls.newTable();
    for (final m in ['light', 'medium', 'heavy', 'selection', 'vibrate']) {
      ls.pushDartFunction((ls) {
        hapticFeedbacks.add(m);
        return 0;
      });
      ls.setField(-2, m);
    }
    ls.setGlobal('haptic');
  }

  // ---- document ----
  void _bindDocument(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final content = ls.checkString(1) ?? '';
      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      ls.newTable();
      for (var r = 0; r < lines.length; r++) {
        ls.pushInteger(r + 1);
        ls.newTable();
        final cols = lines[r].split(',');
        for (var c = 0; c < cols.length; c++) {
          ls.pushInteger(c + 1);
          ls.pushString(cols[c].trim());
          ls.setTable(-3);
        }
        ls.setTable(-3);
      }
      return 1;
    });
    ls.setField(-2, 'csvParse');

    ls.pushDartFunction((ls) {
      ls.pushString('header1,header2\nval1,val2');
      return 1;
    });
    ls.setField(-2, 'csvStringify');
    ls.setGlobal('document');
  }

  // ---- location ----
  void _bindLocation(LuaState ls) {
    ls.newTable();
    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [locationAvailable]);
        return 0;
      }
      ls.pushBoolean(locationAvailable);
      return 1;
    });
    ls.setField(-2, 'isAvailable');

    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [
          {
            'ok': true,
            'latitude': locationLatitude,
            'longitude': locationLongitude,
            'altitude': locationAltitude,
            'speed': locationSpeed,
            'accuracy': locationAccuracy,
            'timestamp': fixedTimestampSec * 1000,
          }
        ]);
      }
      return 0;
    });
    ls.setField(-2, 'getCurrentPosition');

    ls.pushDartFunction((ls) {
      final cbRef = _refFn(ls, 1);
      if (cbRef != null) {
        _invokeRef(ls, cbRef, [locationAltitude]);
      }
      return 0;
    });
    ls.setField(-2, 'getAltitude');

    ls.setGlobal('location');
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
    } else if (val is Map || val is List) {
      _pushJsonValue(ls, val, 0);
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
