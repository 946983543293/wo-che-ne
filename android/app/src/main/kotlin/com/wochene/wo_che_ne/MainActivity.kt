package com.wochene.wo_che_ne

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * 应用主 Activity（P1-2 桌面快捷方式的原生桥接）。
 *
 * ## 与 Dart 侧的契约（见 `lib/services/shortcut_service.dart`）
 * - 通道名：[CHANNEL] = `com.wochene.app/shortcut`。
 * - Dart → 原生：`getLaunchAction` 返回**一次性**的冷启动动作（无则 `null`）。
 * - 原生 → Dart：`launchAction`（参数为 action 字符串）推送**热启动**动作。
 *
 * ## 为什么需要它
 * Android 的静态快捷方式（`res/xml/shortcuts.xml`）以 action
 * [ACTION_RECORD_PARKING] = `com.wochene.app.action.RECORD_PARKING` 启动本 Activity。
 * 本类据此识别「一键记车位」意图；冷启动经 `getLaunchAction` 拉取，热启动
 * （App 已在后台）经 `onNewIntent` 反向推送。动作消费后即清空，避免配置变更
 * （旋转屏幕等）导致重复触发。
 *
 * 之所以自建通道而不用 `quick_actions`：见 Dart 侧 `ShortcutService` 的说明
 * （Dart 与 Android 插件两侧通道名不一致）。此方案行为可预期、可审计、零插件依赖。
 */
class MainActivity : FlutterActivity() {

    /** 尚未被 Dart 消费的启动动作（冷启动）。 */
    private var pendingAction: String? = null

    /** 原生 → Dart 的通道句柄（`configureFlutterEngine` 后可用）。 */
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        // 必须在 super.onCreate 之前读取 intent（super 可能消费/替换它）。
        pendingAction = extractAction(intent)
        // 同样要在 super 之前安装：Flutter 引擎初始化期间抛出的异常也要能落盘。
        installCrashLogger()
        super.onCreate(savedInstanceState)
    }

    /**
     * 安装 Java 层未捕获异常记录器（release 真机崩溃取证）。
     *
     * ## 为什么需要它
     * Dart 层（`FlutterError.onError` / `PlatformDispatcher.instance.onError`）
     * 只能抓到 Dart 异常。发生在平台线程 / 原生 SDK（如高德地图 mapcore）内部的
     * 崩溃直接把进程杀掉，Dart 侧日志一片空白，事后完全无法复现。这里把
     * `Thread.UncaughtExceptionHandler` 兜一层，先把 Throwable 落盘再交还原 handler。
     *
     * ## 落盘位置
     * `filesDir/crash_java.log`，与 Dart 侧 `getApplicationSupportDirectory()`
     * 指向同一目录，由 `DiagnosticsService.readNativeLog()` 读取，
     * 用户在「设置 → 诊断 → 诊断日志」可见。
     *
     * ## 约束
     * - 全程 try/catch，自身绝不抛异常（否则会把一次崩溃变成死循环）；
     * - 写完后**必须**调用原 handler（`previous?.uncaughtException`），
     *   否则会破坏系统正常的崩溃上报 / ANR 弹窗流程；
     * - 只保留最近 [MAX_CRASH_ENTRIES] 条，避免日志无限膨胀。
     */
    private fun installCrashLogger() {
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        if (previous is CrashLogger) {
            return // 已安装（onCreate 重入时不重复包一层）。
        }
        Thread.setDefaultUncaughtExceptionHandler(
            CrashLogger(applicationContext.filesDir, previous),
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchAction" -> {
                    val action = pendingAction
                    pendingAction = null // 一次性消费，避免重复触发。
                    result.success(action)
                }
                else -> result.notImplemented()
            }
        }
        channel = methodChannel
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = extractAction(intent) ?: return
        val activeChannel = channel
        if (activeChannel == null) {
            // 引擎尚在初始化：降级为冷启动动作，待 Dart 拉取。
            pendingAction = action
        } else {
            activeChannel.invokeMethod("launchAction", action)
        }
    }

    /**
     * 仅识别「一键记车位」快捷方式 action；其余（如 `MAIN`）一律忽略，
     * 保证正常启动不会被误判为快捷方式意图。
     */
    private fun extractAction(intent: Intent?): String? {
        val action = intent?.action ?: return null
        return if (action == ACTION_RECORD_PARKING) action else null
    }

    companion object {
        /** 原生桥接方法通道名（与 `AppConstants.shortcutChannelName` 一致）。 */
        private const val CHANNEL = "com.wochene.app/shortcut"

        /** 快捷方式 intent action（与 `res/xml/shortcuts.xml` 一致）。 */
        private const val ACTION_RECORD_PARKING = "com.wochene.app.action.RECORD_PARKING"
    }
}

/**
 * Java 层未捕获异常记录器：把 Throwable 追加写入 `filesDir/crash_java.log`。
 *
 * 每条格式（与 Dart 侧 [DiagnosticsService] 的裁剪逻辑配套）：
 * ```
 * ===== 2026-09-24T10:31:05.123Z thread=main =====
 * java.lang.NoSuchMethodException: updatePrivacyShow
 *     at ...（最多 4000 字符）
 * ```
 * 超过 [MAX_CRASH_ENTRIES] 条时只保留最近这些；超过 [MAX_FILE_BYTES] 则重写文件。
 * 写完后务必把异常交给 [previous]，保持系统原有崩溃流程不变。
 */
private class CrashLogger(
    private val filesDir: File,
    private val previous: Thread.UncaughtExceptionHandler?,
) : Thread.UncaughtExceptionHandler {

    override fun uncaughtException(thread: Thread, throwable: Throwable) {
        try {
            appendLog(thread, throwable)
        } catch (logError: Throwable) {
            // 日志自身失败绝不能吞掉这次崩溃的主流程。
            Log.w(TAG, "crash log write failed", logError)
        }
        previous?.uncaughtException(thread, throwable)
    }

    private fun appendLog(thread: Thread, throwable: Throwable) {
        val file = File(filesDir, LOG_FILE_NAME)
        val entry = formatEntry(thread, throwable)

        val existing = readEntries(file)
        val entries = ArrayList<String>(existing.size + 1)
        entries.addAll(existing)
        entries.add(entry)
        while (entries.size > MAX_CRASH_ENTRIES) {
            entries.removeAt(0)
        }

        val body = buildString {
            for (e in entries) {
                append(ENTRY_PREFIX)
                append(e)
                append('\n')
            }
        }
        // 极端情况下（单条堆栈极长）直接重写，避免反复读改写。
        if (body.toByteArray().size > MAX_FILE_BYTES) {
            file.writeText(ENTRY_PREFIX + entry + "\n")
        } else {
            file.writeText(body)
        }
    }

    /** 读取已存在的条目（按 [ENTRY_PREFIX] 切分，去尾部空白）。 */
    private fun readEntries(file: File): List<String> {
        if (!file.exists()) {
            return emptyList()
        }
        val raw = file.readText()
        if (raw.isBlank()) {
            return emptyList()
        }
        return raw
            .split(Regex("^$ENTRY_PREFIX", RegexOption.MULTILINE))
            .map { it.trimEnd() }
            .filter { it.isNotEmpty() }
    }

    private fun formatEntry(thread: Thread, throwable: Throwable): String {
        val stack = StringWriter().also { throwable.printStackTrace(PrintWriter(it)) }.toString()
        val clipped = if (stack.length > MAX_STACK_CHARS) stack.substring(0, MAX_STACK_CHARS) else stack
        return "${ENTRY_PREFIX}${isoNow()} thread=${thread.name} $ENTRY_SUFFIX\n$clipped"
    }

    private fun isoNow(): String = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        .apply { timeZone = TimeZone.getTimeZone("UTC") }
        .format(Date())

    private companion object {
        const val TAG = "WoCheNe.CrashLogger"

        /** 日志文件名（与 Dart 侧 `DiagnosticsService.nativeLogFileName` 一致）。 */
        const val LOG_FILE_NAME = "crash_java.log"

        /** 条目起始标记（Dart 侧 `DiagnosticsService` 用同样规则切分）。 */
        const val ENTRY_PREFIX = "===== "

        /** 条目标题结束标记（与 [ENTRY_PREFIX] 配对，形如 `===== ... =====`）。 */
        const val ENTRY_SUFFIX = "====="

        /** 单条堆栈最大字符数。 */
        const val MAX_STACK_CHARS = 4000

        /** 最多保留的崩溃条数。 */
        const val MAX_CRASH_ENTRIES = 20

        /** 文件体积上限（字节），超过则重写为仅剩最新一条。 */
        const val MAX_FILE_BYTES = 200_000
    }
}
