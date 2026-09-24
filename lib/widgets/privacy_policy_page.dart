import 'package:flutter/material.dart';

/// 隐私政策全文页（与仓库 `PRIVACY.md` 同步，应用内可离线查看）。
///
/// 首启同意框与设置页共用本页，保证「用户可随时查阅」且文案单一来源。
class PrivacyPolicyPage extends StatelessWidget {
  /// 创建隐私政策页。
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私政策')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Text(
            privacyPolicyText,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.7),
          ),
        ),
      ),
    );
  }
}

/// 隐私政策正文（与 `PRIVACY.md` 一致的精简版）。
const String privacyPolicyText = '''
「我车呢」隐私政策

一句话版本：本应用不收集、不上传、不分享任何用户数据，你的全部数据只存在你自己的手机里。

一、我们处理什么数据
本应用只在你本机保存以下数据，且全部由你主动产生：
• 停车位置（经纬度、地点名、时间）：用于帮你找到车，存于应用私有目录 records.json。
• 你拍摄的停车照片（0–3 张/条）：用于凭照片认车，存于应用私有目录 photos/，不写入系统相册。
• 应用设置（记录上限、主题、引导状态等）：用于记住你的偏好，存于系统键值存储。

二、我们做什么 / 不做什么
• 纯本地存储：无账号、无后端服务器、无云同步。
• 零数据出设备：除高德地图 SDK 为提供定位/地图服务所必需的网络请求外，应用自身没有任何网络请求。
• 无埋点、无统计、无广告 SDK。
• 卸载应用即删除全部数据（含照片），不留残余。
• 不收集设备标识、通讯录、剪贴板、应用列表等任何与找车无关的信息。

三、权限说明（按需申请、给理由）
• 定位（精确/粗略）：你点「记下车位」时才申请，用于记录车位坐标与找车时显示你的位置。
• 相机：你进入拍照页时才申请，用于拍摄停车位照片（仅存入应用私有目录）。
拒绝授权不影响其余功能：定位被拒可纯照片记录，相机被拒可纯定位记录。
本应用不申请相册读取、通知等无关权限。

四、第三方 SDK
本应用使用高德地图 SDK（地图显示与融合定位）。高德 SDK 会在你同意本政策后才初始化（延迟初始化设计），其数据处理遵循《高德地图开放平台隐私政策》。本应用不向高德之外的任何第三方提供你的数据。

五、开源与可验证
本应用全部源代码在 GitHub 开源，上述承诺可被任何人审计验证。本文件在开源仓库与应用内同步维护，以仓库最新版本为准。

六、联系我们
如有隐私相关问题，请通过 GitHub 仓库 Issues 反馈。
''';
