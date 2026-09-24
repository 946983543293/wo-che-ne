import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../services/diagnostics_service.dart';

/// 诊断日志页（设置 → 诊断 → 诊断日志）。
///
/// 分两段展示本机日志，均带滚动与选中能力：
/// - **Dart 诊断日志**：`FlutterError.onError` / `PlatformDispatcher.instance.onError`
///   捕获的 Dart 异常（应用私有目录 `diagnostics.log`）；
/// - **原生崩溃日志**：`MainActivity.CrashLogger` 捕获的 Java 层未捕获异常
///   （`filesDir/crash_java.log`）——平台线程 / 原生 SDK 内部的崩溃只有这里留有痕迹。
///
/// 「复制全文」把两段一起复制（中间用分隔标题隔开）。「清空」两段都清。
class DiagnosticsLogPage extends StatefulWidget {
  /// 创建诊断日志页。[service] 可注入测试替身，缺省用全局实例。
  const DiagnosticsLogPage({super.key, this.service});

  /// 日志来源；null 时用全局 [diagnosticsService]。
  final DiagnosticsService? service;

  @override
  State<DiagnosticsLogPage> createState() => _DiagnosticsLogPageState();
}

/// 一个分区的标题 + 正文（用于渲染与复制）。
class _LogSection {
  const _LogSection({required this.title, required this.body});

  /// 分区标题。
  final String title;

  /// 日志正文（空串表示无内容）。
  final String body;
}

class _DiagnosticsLogPageState extends State<DiagnosticsLogPage> {
  late final DiagnosticsService _service;
  String _dartLog = '';
  String _nativeLog = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? diagnosticsService;
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final String dart = await _service.readLog();
    final String native = await _service.readNativeLog();
    if (!mounted) {
      return;
    }
    setState(() {
      _dartLog = dart;
      _nativeLog = native;
      _loading = false;
    });
  }

  /// 两段日志的合并文本（供「复制全文」使用，中间用分隔标题隔开）。
  String _combinedText() {
    final List<_LogSection> sections = _sections();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < sections.length; i++) {
      if (i > 0) {
        buffer.writeln();
      }
      buffer.writeln('===== ${sections[i].title} =====');
      buffer.writeln(sections[i].body);
    }
    return buffer.toString();
  }

  List<_LogSection> _sections() => <_LogSection>[
        _LogSection(
          title: 'Dart 诊断日志',
          body: _dartLog.isEmpty ? '（无 Dart 层错误日志）' : _dartLog,
        ),
        _LogSection(
          title: '原生崩溃日志（Java 层未捕获异常）',
          body: _nativeLog.isEmpty ? '（无原生崩溃日志）' : _nativeLog,
        ),
      ];

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: _combinedText()));
    if (!mounted) {
      return;
    }
    _toast('日志已复制');
  }

  Future<void> _clear() async {
    await _service.clear();
    await _service.clearNativeLog();
    await _reload();
    if (!mounted) {
      return;
    }
    _toast('日志已清空');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool hasAny = _dartLog.isNotEmpty || _nativeLog.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('诊断日志'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: '复制全文',
            onPressed: hasAny ? _copyAll : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空',
            onPressed: hasAny ? _clear : null,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.pagePadding,
                  12,
                  AppTokens.pagePadding,
                  40,
                ),
                children: <Widget>[
                  for (final _LogSection section in _sections()) ...<Widget>[
                    Text(
                      section.title,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      section.body,
                      style: const TextStyle(
                        fontSize: AppTokens.fontCaptionS,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    '遇到闪退后回到这里即可看到堆栈；把全文发给我们即可定位。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
      ),
    );
  }
}
