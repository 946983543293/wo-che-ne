// Bug 修复补测 —— 诊断日志服务（真机闪退取证）。
//
// 覆盖：写入可读回 / 条目裁剪到 50 条 / 堆栈截断 / 清空 / 写入失败不抛异常。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/services/diagnostics_service.dart';

void main() {
  late Directory root;
  late Directory nativeRoot;
  late DiagnosticsService service;

  setUp(() {
    root = Directory.systemTemp.createTempSync('wcn_diag_');
    nativeRoot = Directory.systemTemp.createTempSync('wcn_native_');
    service = DiagnosticsService(
      rootOverride: root,
      nativeRootOverride: nativeRoot,
    );
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
    if (nativeRoot.existsSync()) {
      nativeRoot.deleteSync(recursive: true);
    }
  });

  test('DIAG-1 写入一条错误后可读回：含 tag、错误文本与堆栈', () async {
    await service.logError(
      StateError('boom'),
      stack: StackTrace.current,
      tag: 'unit',
    );

    final String log = await service.readLog();
    expect(log, startsWith('## '));
    expect(log, contains('[unit]'));
    expect(log, contains('boom'));
    expect(log, contains('diagnostics_service_test.dart'));
  });

  test('DIAG-2 空日志读取返回空串（不抛异常）', () async {
    expect(await service.readLog(), '');
  });

  test('DIAG-3 超过 maxEntries 只保留最近 50 条', () async {
    for (int i = 0; i < DiagnosticsService.maxEntries + 10; i++) {
      await service.logError(StateError('err-$i'), tag: 'unit');
    }

    final String log = await service.readLog();
    final int entries = '## '.allMatches(log).length;
    expect(entries, DiagnosticsService.maxEntries);
    expect(log, contains('err-59'));
    expect(log, isNot(contains('err-0\n')));
    expect(log, isNot(contains('err-9\n')));
  });

  test('DIAG-4 堆栈超长时截断到 maxStackChars', () async {
    final String longStack = 'A' * 5000;
    await service.logError(StateError('boom'), stack: StackTrace.fromString(longStack));

    final String log = await service.readLog();
    final int aCount = 'A'.allMatches(log).length;
    expect(aCount, DiagnosticsService.maxStackChars);
  });

  test('DIAG-5 清空后 readLog 返回空串', () async {
    await service.logError(StateError('boom'), tag: 'unit');
    expect(await service.readLog(), isNotEmpty);

    await service.clear();

    expect(await service.readLog(), '');
  });

  test('DIAG-6 写入失败（根目录不可创建）静默吞掉，不抛异常', () async {
    // 用一个**文件**冒充根目录 → create 失败，验证日志写入不会二次崩溃。
    final File blocker = File('${root.path}/blocker')..writeAsStringSync('x');
    final DiagnosticsService broken =
        DiagnosticsService(rootOverride: Directory(blocker.path));

    await expectLater(broken.logError(StateError('boom')), completes);
    expect(await broken.readLog(), '');
  });

  // ---- 原生崩溃日志（`MainActivity.CrashLogger` 写在 filesDir 下）----

  test('DIAG-7 原生日志为空时 readNativeLog 返回空串', () async {
    expect(await service.readNativeLog(), '');
  });

  test('DIAG-8 原生日志可被原样读回（不做任何格式化改写）', () async {
    const String nativeContent = '===== 2026-09-24T10:31:05.123Z thread=main =====\n'
        'java.lang.NoSuchMethodException: updatePrivacyShow\n'
        '    at com.amap.api.maps.MapsInitializer.a(Unknown Source:0)\n';
    File(
      '${nativeRoot.path}/${DiagnosticsService.nativeLogFileName}',
    ).writeAsStringSync(nativeContent);

    final String log = await service.readNativeLog();
    expect(log, nativeContent);
    // 与 Dart 日志是**两个不同的文件**，互不影响。
    expect(await service.readLog(), '');
  });

  test('DIAG-9 清空原生日志不影响 Dart 日志，反之亦然', () async {
    await service.logError(StateError('dart-boom'), tag: 'unit');
    File('${nativeRoot.path}/${DiagnosticsService.nativeLogFileName}')
        .writeAsStringSync('===== crash =====\nboom\n');

    await service.clearNativeLog();
    expect(await service.readNativeLog(), '');
    expect(await service.readLog(), contains('dart-boom'));

    await service.clear();
    expect(await service.readLog(), '');
  });

  test('DIAG-10 原生日志读取失败（路径不可读）返回空串，不抛异常', () async {
    final File blocker = File('${nativeRoot.path}/blocker')..writeAsStringSync('x');
    final DiagnosticsService broken =
        DiagnosticsService(nativeRootOverride: Directory(blocker.path));

    expect(await broken.readNativeLog(), '');
    await expectLater(broken.clearNativeLog(), completes);
  });
}
