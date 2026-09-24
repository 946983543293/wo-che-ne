import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/storage/local_store.dart';
import '../state/providers.dart';

/// 单张照片缩略图（可点开大图）。无照片时显示令牌化占位（不引版权素材）。
///
/// 一切路径拼接都经 [LocalStore]，页面不直接拼 `File` 路径（架构 §7.7）。
class PhotoThumb extends ConsumerWidget {
  /// 创建缩略图。[relativePath] 为相对文件名（`photos/{id}_{n}.jpg`），null 显示占位。
  const PhotoThumb({
    super.key,
    required this.relativePath,
    this.size = 64,
    this.onTap,
  });

  /// 相对文件名；null 或空串时显示占位。
  final String? relativePath;

  /// 边长（正方形）。
  final double size;

  /// 点击回调（如打开全屏浏览）。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? relative = relativePath;
    // 限分辨率解码：只按 `size × DPR` 解码，避免原图全分辨率解码吃掉几十 MB。
    final int cacheWidth =
        (size * MediaQuery.devicePixelRatioOf(context)).round();
    final Widget content = (relative == null || relative.isEmpty)
        ? _placeholder(context)
        : FutureBuilder<String>(
            future: ref.read(localStoreProvider).absolutePhotoPath(relative),
            builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
              if (!snapshot.hasData) {
                return _placeholder(context);
              }
              return Image.file(
                File(snapshot.data!),
                width: size,
                height: size,
                cacheWidth: cacheWidth,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(context),
              );
            },
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusS),
      child: SizedBox(
        width: size,
        height: size,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, child: content),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.10),
      child: Icon(
        Icons.photo_outlined,
        color: AppColors.primary,
        size: size * 0.42,
      ),
    );
  }
}

/// 照片横排缩略图条（历史列表与地图找车页复用）。
///
/// 点击任一缩略图进入全屏浏览（左右滑动 + 双指放大）。
class PhotoStrip extends ConsumerWidget {
  /// 创建照片条。[photoPaths] 为空时整体不占位。
  const PhotoStrip({
    super.key,
    required this.photoPaths,
    this.thumbSize = 60,
  });

  /// 照片相对文件名列表。
  final List<String> photoPaths;

  /// 缩略图边长。
  final double thumbSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (photoPaths.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: thumbSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photoPaths.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) => PhotoThumb(
          relativePath: photoPaths[index],
          size: thumbSize,
          onTap: () => openPhotoViewer(context, photoPaths, index),
        ),
      ),
    );
  }
}

/// 打开全屏照片浏览页。
void openPhotoViewer(
  BuildContext context,
  List<String> photoPaths,
  int initialIndex,
) {
  if (photoPaths.isEmpty) {
    return;
  }
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => PhotoViewerPage(
        photoPaths: photoPaths,
        initialIndex: initialIndex.clamp(0, photoPaths.length - 1),
      ),
    ),
  );
}

/// 全屏照片浏览页：左右滑动切换 + 双指放大。
class PhotoViewerPage extends ConsumerStatefulWidget {
  /// 创建浏览页。
  const PhotoViewerPage({
    super.key,
    required this.photoPaths,
    this.initialIndex = 0,
  });

  /// 照片相对文件名列表。
  final List<String> photoPaths;

  /// 初始页序号。
  final int initialIndex;

  @override
  ConsumerState<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends ConsumerState<PhotoViewerPage> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LocalStore store = ref.read(localStoreProvider);
    return Scaffold(
      backgroundColor: AppColors.immersive,
      body: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photoPaths.length,
            onPageChanged: (int i) => setState(() => _index = i),
            itemBuilder: (BuildContext context, int i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: FutureBuilder<String>(
                  future: store.absolutePhotoPath(widget.photoPaths[i]),
                  builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator(
                        color: AppColors.onScrim,
                      );
                    }
                    return Image.file(
                      File(snapshot.data!),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.onScrim,
                        size: 48,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: AppColors.onScrim),
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const Spacer(),
                if (widget.photoPaths.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Text(
                      '${_index + 1} / ${widget.photoPaths.length}',
                      style: const TextStyle(
                        color: AppColors.onScrim,
                        fontSize: AppTokens.fontCaption,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
