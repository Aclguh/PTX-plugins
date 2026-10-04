import 'dart:convert';
import 'dart:io';

import 'package:ptx_dev_harness/host_stubs.dart';
import 'package:lua_dardo/lua.dart';

void main(List<String> args) {
  final ls = LuaState.newState();
  ls.openLibs();
  HarnessHost().bind(ls);
  final code = utf8.decode(File(args.first).readAsBytesSync());
  try {
    if (ls.loadString(code) != ThreadStatus.luaOk) {
      // ignore: avoid_print
      print('COMPILE ERROR: ${ls.toStr(-1)}');
      exit(1);
    }
    final st = ls.pCall(0, 1, 0);
    if (st != ThreadStatus.luaOk) {
      // ignore: avoid_print
      print('RUNTIME ERROR: ${ls.toStr(-1)}');
      exit(2);
    }
    // ignore: avoid_print
    print('RESULT: ${ls.toStr(-1)}');
  } catch (e) {
    // ignore: avoid_print
    print('DART ERROR: $e');
    exit(3);
  }
}
