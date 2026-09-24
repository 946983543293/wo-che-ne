// QA 独立验证（素材轮）—— 三张 Seedream 素材接入 + cacheWidth 降采样守卫。
//
// 运行时可观测的部分走 widget 断言；运行时难以触发的部分（资源加载失败的
// 降级分支、Marker anchor、CameraPreview 外层包装）走**静态源码守卫**，
// 即把「不许这么做」的规则固化成测试，防止后续改动悄悄破坏。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wo_che_ne/data/models/app_settings.dart';
import 'package:wo_che_ne/data/storage/local_store.dart';
import 'package:wo_che_ne/state/providers.dart';
import 'package:wo_che_ne/widgets/photo_strip.dart';

import 'support/fakes.dart';
import 'support/rig.dart';

/// 1×1 PNG（写在临时目录里充当真实照片，让 `Image.file` 能真正解码）。
const String _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==';

/// 定位项目根目录（向上找 pubspec.yaml）。
Directory _projectRoot() {
  Directory dir = Directory.current;
  for (int i = 0; i < 6; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir;
    }
    dir = dir.parent;
  }
  throw StateError('未能定位项目根目录（找不到 pubspec.yaml）');
}

String _sourceOf(String relativePath) =>
    File('${_projectRoot().path}/$relativePath').readAsStringSync();

/// 去掉 `//` 之后的内容，只留代码（用于静态守卫）。
List<String> _codeLines(String source) => source
    .split('\n')
    .map((String line) => line.split('//').first)
    .toList();

/// 先让 `LocalStore` 的异步 IO 在**真实**异步区跑完，再用固定帧数推进渲染。
///
/// `testWidgets` 跑在 FakeAsync 区里，`dart:io` 的 Future 不会随 pump 完成，
/// 直接 `pumpAndSettle` 会卡在 `CircularProgressIndicator` 上超时。
Future<void> _settleWithIo(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync<void>(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await pumpFrames(tester, 10);
}

void main() {
  late Directory root;

  setUp(() {
    installPermissionMock();
    root = Directory.systemTemp.createTempSync('wcn_asset_qa_');
    final Directory photos = Directory('${root.path}/photos');
    photos.createSync(recursive: true);
    File('${photos.path}/q_0.jpg')
        .writeAsBytesSync(base64Decode(_onePixelPngBase64));
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  testWidgets('ASSET-1 首页停车态横幅：带 errorBuilder，且降级高度仍是 150',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildApp(
        settings: FakeSettingsRepository(
          AppSettings(privacyAgreed: true, guideDisabled: true),
        ),
        parking: FakeParkingRepository(),
        root: root,
      ),
    );
    await tester.pumpAndSettle();

    final Finder hero = find.byWidgetPredicate((Widget widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName ==
            'assets/images/home_parking_hero.png');
    expect(hero, findsOneWidget, reason: '首页停车态应渲染主视觉横幅');

    final Image heroImage = tester.widget<Image>(hero);
    expect(heroImage.errorBuilder, isNotNull,
        reason: '素材缺失必须能降级，不能抛错或留空白');
    expect(heroImage.height, 150,
        reason: '降级分支是 SizedBox(height:150)，高度必须与正常态一致');
  });

  testWidgets('ASSET-2 缩略图：cacheWidth = 边长 × devicePixelRatio（限分辨率解码）',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localStoreProvider.overrideWithValue(LocalStore(rootOverride: root)),
        ],
        child: const MaterialApp(
          home: PhotoThumb(relativePath: 'photos/q_0.jpg', size: 64),
        ),
      ),
    );
    await _settleWithIo(tester);

    expect(find.byType(Image), findsOneWidget,
        reason: '缩略图应渲染出 Image（照片文件已就绪）');
    final Image thumb = tester.widget<Image>(find.byType(Image));
    expect(thumb.image, isA<ResizeImage>(), reason: '缩略图必须降采样解码');
    final ResizeImage resized = thumb.image as ResizeImage;
    expect(resized.width, (64 * tester.view.devicePixelRatio).round());
  });

  testWidgets('ASSET-3 全屏浏览页：不得加 cacheWidth（要看原图）',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          localStoreProvider.overrideWithValue(LocalStore(rootOverride: root)),
        ],
        child: const MaterialApp(
          home: PhotoViewerPage(photoPaths: <String>['photos/q_0.jpg']),
        ),
      ),
    );
    await _settleWithIo(tester);

    expect(find.byType(Image), findsOneWidget,
        reason: '全屏浏览页应渲染出 Image（照片文件已就绪）');
    final Image full = tester.widget<Image>(find.byType(Image));
    expect(full.image, isA<FileImage>(),
        reason: '全屏浏览必须按原图解码，不能套 ResizeImage 降采样');
  });

  test('ASSET-4 地图车图钉：Marker 不得显式指定 anchor（必须保持默认 0.5/1.0）', () {
    final List<String> lines =
        _codeLines(_sourceOf('lib/pages/map_find/map_find_page.dart'));
    expect(lines.where((String line) => line.contains('anchor')), isEmpty,
        reason: '图钉尖已对齐素材画布底部中心，改 anchor 会让图钉偏移');
  });

  test('ASSET-5 拍照预览：CameraPreview 外层不得再套 AspectRatio（预览变形）', () {
    final List<String> lines =
        _codeLines(_sourceOf('lib/pages/camera/camera_page.dart'));
    expect(lines.where((String line) => line.contains('AspectRatio')), isEmpty,
        reason: 'CameraPreview 自身已是 AspectRatio，外层再套会强制错误比例');
    expect(lines.any((String line) => line.contains('CameraPreview(')), isTrue);
    expect(lines.any((String line) => line.contains('ClipRect(')), isTrue);
  });

  test('ASSET-6 地图图钉加载失败：静默回退系统默认橙色图钉，不冒泡', () {
    final String source = _sourceOf('lib/pages/map_find/map_find_page.dart');
    expect(source, contains('defaultMarkerWithHue(BitmapDescriptor.hueOrange)'),
        reason: '自定义图钉加载失败必须回退系统默认橙色图钉');
    expect(source, contains('catch (error, stack)'),
        reason: '图钉加载必须 try/catch 兜住，不能在 initState 里冒泡成闪退');
  });
}
