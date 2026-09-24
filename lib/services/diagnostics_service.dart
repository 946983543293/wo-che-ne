import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 诊断日志服务：把最近若干条未处理错误落盘到应用私有目录的 `diagnostics.log`。
///
/// 用途：**真机闪退取证**。闪退常常发生在用户手上、开发者拿不到 logcat 的场景；
/// 全局错误捕获把堆栈写进这里，用户复现一次即可在「设置 → 诊断日志」里
/// 查看 / 复制全文发给我们。
///
/// 设计约束：
/// - **不新增依赖**：沿用 `LocalStore` 取应用私有目录的方式（`path_provider`）；
/// - **永不抛异常**：写日志失败一律静默，绝不能把原本的小错误放大成二次崩溃；
/// - **可在 `runApp` 之前构造**：不依赖 `WidgetsBinding` / 任何 Provider。
///
  /// [rootOverride] 仅用于测试注入临时目录；生产环境走
  /// `path_provider.getApplicationDocumentsDirectory()`。
class DiagnosticsService {
  /// 创建诊断日志服务。
  ///
  /// [rootOverride] / [nativeRootOverride] 传 `Directory` 即注入测试根目录，
  /// 生产环境为空走 `path_provider`。两者必须分别注入，因为它们在 Android 上
  /// 指向**不同的**目录（documents vs support），混用会读不到对方的日志。
  DiagnosticsService({this.rootOverride, this.nativeRootOverride});

  /// 测试注入的 Dart 日志根目录；生产环境为 null（走 `getApplicationDocumentsDirectory`）。
  final Directory? rootOverride;

  /// 测试注入的原生崩溃日志根目录；生产环境为 null（走 `getApplicationSupportDirectory`）。
  final Directory? nativeRootOverride;

  /// 最多保留的错误条数（超出后丢弃最旧的）。
  static const int maxEntries = 50;

  /// 单条堆栈保留的最大字符数（避免日志无限膨胀）。
  static const int maxStackChars = 2000;

  /// 日志文件名（应用私有目录下）。
  static const String logFileName = 'diagnostics.log';

  /// 每条日志的起始标记（用于按条切分与裁剪）。
  static const String entryPrefix = '## ';

  /// 原生（Java/Kotlin 层）未捕获异常日志文件名。
  ///
  /// 由 `MainActivity.CrashLogger` 写在 `filesDir` 下；Android 上
  /// `getApplicationSupportDirectory()` 与 `filesDir` 是同一目录。
  /// Dart 侧只读不清格式（`保留最近 20 条`的裁剪逻辑在 Kotlin 侧），这里原样呈现。
  static const String nativeLogFileName = 'crash_java.log';

  /// 记录一条错误：`时间戳 + [tag] + error.toString() + 堆栈前 [maxStackChars] 字符`。
  ///
  /// 超出 [maxEntries] 时丢弃最旧的条目。任何 IO 失败都静默吞掉。
  Future<void> logError(
    Object error, {
    StackTrace? stack,
    String tag = 'error',
  }) async {
    try {
      final File file = await _logFile();
      final List<String> entries = await _readEntries(file);
      entries.add(_formatEntry(error, stack, tag));
      while (entries.length > maxEntries) {
        entries.removeAt(0);
      }
      await file.writeAsString(_encode(entries), flush: true);
    } catch (_) {
      // 诊断日志自身失败一律静默（避免把原错误放大成崩溃）。
    }
  }

  /// 读取日志全文；文件不存在或读取失败时返回空串。
  Future<String> readLog() async {
    try {
      final File file = await _logFile();
      if (!await file.exists()) {
        return '';
      }
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  /// 清空日志（文件置空，不删除文件本身）。失败静默。
  Future<void> clear() async {
    try {
      final File file = await _logFile();
      if (await file.exists()) {
        await file.writeAsString('', flush: true);
      }
    } catch (_) {
      // 静默。
    }
  }

  /// 读取**原生层**崩溃日志（`crash_java.log`）全文；不存在或失败返回空串。
  ///
  /// Dart 侧的 `FlutterError.onError` / `PlatformDispatcher.instance.onError`
  /// 只能抓到 Dart 异常；平台线程 / 原生 SDK（如高德地图 mapcore）内部的崩溃
  /// 会直接杀进程，只有这个文件能留下痕迹。
  Future<String> readNativeLog() async {
    try {
      final File file = await _nativeLogFile();
      if (!await file.exists()) {
        return '';
      }
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  /// 清空原生崩溃日志。失败静默。
  Future<void> clearNativeLog() async {
    try {
      final File file = await _nativeLogFile();
      if (await file.exists()) {
        await file.writeAsString('', flush: true);
      }
    } catch (_) {
      // 静默。
    }
  }

  Future<Directory> _rootDir() async {
    final Directory? override = rootOverride;
    if (override != null) {
      if (!await override.exists()) {
        await override.create(recursive: true);
      }
      return override;
    }
    return getApplicationDocumentsDirectory();
  }

  /// 原生日志所在目录：Android 上与 `Context.getFilesDir()` 是同一个。
  Future<Directory> _nativeRootDir() async {
    final Directory? override = nativeRootOverride;
    if (override != null) {
      if (!await override.exists()) {
        await override.create(recursive: true);
      }
      return override;
    }
    return getApplicationSupportDirectory();
  }

  Future<File> _logFile() async {
    final Directory root = await _rootDir();
    return File(_join(root.path, logFileName));
  }

  Future<File> _nativeLogFile() async {
    final Directory root = await _nativeRootDir();
    return File(_join(root.path, nativeLogFileName));
  }

  /// 按 [entryPrefix] 切分出已存在的条目（去掉首尾空白）。
  Future<List<String>> _readEntries(File file) async {
    if (!await file.exists()) {
      return <String>[];
    }
    final String raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <String>[];
    }
    return raw
        .split(RegExp('^$entryPrefix', multiLine: true))
        .map((String entry) => entry.trimRight())
        .where((String entry) => entry.isNotEmpty)
        .toList();
  }

  static String _encode(List<String> entries) =>
      '${entries.map((String entry) => '$entryPrefix$entry').join('\n')}\n';

  static String _formatEntry(Object error, StackTrace? stack, String tag) {
    final String stackText = stack?.toString() ?? '';
    final String clipped = stackText.length > maxStackChars
        ? stackText.substring(0, maxStackChars)
        : stackText;
    final String head =
        '[${DateTime.now().toIso8601String()}] [$tag] $error';
    return clipped.isEmpty ? head : '$head\n$clipped';
  }

  /// 以 `/` 拼接路径片段（仅本文件内部使用；不引 `package:path` 以少一依赖）。
  static String _join(String base, String child) =>
      base.endsWith('/') ? '$base$child' : '$base/$child';
}

/// 全局诊断日志服务实例（`main()` 注册错误捕获与设置页取证共用）。
final DiagnosticsService diagnosticsService = DiagnosticsService();
