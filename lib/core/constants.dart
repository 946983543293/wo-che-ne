/// 「我车呢」全局常量：应用信息、存储键名、上限默认值、路由名。
///
/// 与架构 §3.1（模型字段默认值）、§7.3（路由方案）保持一致；
/// 数据层（T02）与状态层（T03）引用此文件，不得各写各的键名。
abstract final class AppConstants {
  AppConstants._();

  // ---------- 应用信息 ----------
  /// 应用显示名。
  static const String appName = '我车呢';

  /// 停车记录本地文件名（应用私有目录下）。
  static const String recordsFileName = 'records.json';

  /// 照片存储子目录名（应用私有目录下）。
  static const String photosDirName = 'photos';

  // ---------- 上限默认值（架构 §3.1 AppSettings） ----------
  /// 历史记录默认上限。
  static const int defaultMaxRecords = 10;

  /// 历史记录可设最小值。
  static const int minMaxRecords = 3;

  /// 历史记录可设最大值。
  static const int maxMaxRecords = 20;

  /// 每条记录照片上限（0–3 张，性能护栏）。
  static const int maxPhotosPerRecord = 3;

  /// 定位精度告警阈值（米）：超过则 UI 提示「主要靠照片认车」。
  static const double poorAccuracyMeters = 20;

  // ---------- 存储键名（shared_preferences，架构 §3.1/§3.2） ----------
  /// 键：历史记录保存条数（int）。
  static const String keyMaxRecords = 'settings.maxRecords';

  /// 键：主题模式（String：system/light/dark）。
  static const String keyThemeMode = 'settings.themeMode';

  /// 键：震动反馈开关（bool）。
  static const String keyHapticEnabled = 'settings.hapticEnabled';

  /// 键：「以后不再提示」引导总开关（bool）。
  static const String keyGuideDisabled = 'settings.guideDisabled';

  /// 键：已完成引导步号（`List<String>` 存的 int 集合）。
  static const String keyGuideStepsSeen = 'settings.guideStepsSeen';

  /// 键：隐私政策是否已同意（bool）。
  static const String keyPrivacyAgreed = 'settings.privacyAgreed';

  /// 键：隐私政策同意时间（ISO 8601 String）。
  static const String keyPrivacyAgreedAt = 'settings.privacyAgreedAt';

  // ---------- 路由名（Navigator 1.0 命名路由，架构 §7.3） ----------
  /// 首页（停车态/找车态双状态）。
  static const String routeHome = '/';

  /// 拍照页。
  static const String routeCamera = '/camera';

  /// 地图找车页。
  static const String routeMapFind = '/map-find';

  /// 历史记录页。
  static const String routeHistory = '/history';

  /// 记录详情页。
  static const String routeRecordDetail = '/record-detail';

  /// 设置页。
  static const String routeSettings = '/settings';

  // ---------- 桌面快捷方式（P1-2，Dart ↔ MainActivity 约定） ----------
  /// 原生快捷方式桥接通道名（`MethodChannel`）。
  static const String shortcutChannelName = 'com.wochene.app/shortcut';

  /// 快捷方式 intent 的 action（与 `res/xml/shortcuts.xml` 一致）。
  static const String shortcutIntentAction = 'com.wochene.app.action.RECORD_PARKING';

  /// 归一化后的业务动作类型：一键记车位（与 shortcuts.xml 的 shortcutId 一致）。
  static const String shortcutActionRecordParking = 'record_parking';

  // ---------- 关于页（PRD §4.7） ----------
  /// 开发者署名（设置页「关于」分组与页脚展示）。
  static const String developerName = '聆风语';

  /// 开源仓库地址（MIT 协议公开仓库）。
  ///
  /// 应用内「设置 → 关于 → 开源仓库」展示此地址，并支持复制到剪贴板 / 外部打开。
  static const String githubRepoUrl = 'https://github.com/LingFengyuTHU/wo-che-ne';

  /// 开源协议名称。
  static const String licenseName = 'MIT';
}
