import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/storage/local_store.dart';
import '../../services/location_service.dart';
import '../../state/coach_mark_controller.dart';
import '../../state/providers.dart';
import '../../widgets/coach_mark_overlay.dart';

/// 拍照页入参（架构 §7.3：页面间传参用构造参数，不用全局变量）。
class CameraPageArgs {
  /// 创建入参。[fix] 为 null 表示定位失败降级（走纯照片 + 手动地点）。
  const CameraPageArgs({required this.recordId, this.fix});

  /// 本记录的 id（拍照前即确定，用于命名 `photos/{id}_{n}.jpg`）。
  final String recordId;

  /// 定位结果；失败为 null。
  final PositionFix? fix;
}

/// 拍照页（架构 §4② / PRD §4.2）。
///
/// 0–3 张都合法：快门可连拍（上限 3 张自动收工），「拍够了就这样」随时结束
/// （0 张时文案为「不拍了，直接记」）。照片先出缩略图、再异步写私有目录，
/// **绝不进系统相册**。定位失败时提供「补充地点」一键展开的手动输入。
class CameraPage extends ConsumerStatefulWidget {
  /// 创建拍照页。
  const CameraPage({super.key, required this.args});

  /// 入参（记录 id + 定位结果）。
  final CameraPageArgs args;

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  final GlobalKey _controlsKey = GlobalKey();
  final TextEditingController _placeController = TextEditingController();

  late final LocalStore _store;

  CameraController? _controller;
  bool _initializing = true;
  bool _permissionDenied = false;
  bool _busy = false;
  bool _showHint = true;
  bool _placeExpanded = false;
  bool _saved = false;
  bool _step2Checked = false;
  int _nextIndex = 0;
  int? _coachStep;

  List<String> _photoPaths = <String>[];

  @override
  void initState() {
    super.initState();
    _store = ref.read(localStoreProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initCamera());
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (!_saved) {
      // 用户放弃记录：清理已写入的孤儿照片，避免私有目录残留。
      _store.deletePhotos(widget.args.recordId).ignore();
    }
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final bool granted = await _ensureCameraPermission();
    if (!mounted) {
      return;
    }
    if (!granted) {
      setState(() {
        _permissionDenied = true;
        _initializing = false;
      });
      return;
    }
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _permissionDenied = true;
            _initializing = false;
          });
        }
        return;
      }
      final CameraDescription camera = cameras.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final CameraController controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _initializing = false;
        });
      }
    }
  }

  Future<bool> _ensureCameraPermission() async {
    try {
      if ((await Permission.camera.status).isGranted) {
        return true;
      }
      if (!mounted) {
        return false;
      }
      final bool ok = await _showRationale(
            title: '需要相机权限',
            reason: '用于拍摄停车位照片，帮你找车时认车。照片只存本机、不进相册。',
          ) ??
          false;
      if (!ok) {
        return false;
      }
      return (await Permission.camera.request()).isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> _showRationale({required String title, required String reason}) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(reason),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('暂不'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  // ---------- 拍摄 ----------

  Future<void> _capture() async {
    final CameraController? controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _busy ||
        _photoPaths.length >= AppConstants.maxPhotosPerRecord) {
      return;
    }
    setState(() => _busy = true);
    try {
      final XFile shot = await controller.takePicture();
      final List<int> bytes = await shot.readAsBytes();
      final int index = _nextIndex;
      final String relative = await _store.savePhoto(widget.args.recordId, index, bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _nextIndex = index + 1;
        _photoPaths = <String>[..._photoPaths, relative];
        _showHint = false;
        _busy = false;
      });
      // 拍满 3 张自动收工，无需再点。
      if (_photoPaths.length >= AppConstants.maxPhotosPerRecord) {
        await _finish();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('拍摄失败，请重试');
      }
    }
  }

  Future<void> _removePhoto(int index) async {
    if (index < 0 || index >= _photoPaths.length) {
      return;
    }
    final String relative = _photoPaths[index];
    setState(() => _photoPaths = <String>[..._photoPaths]..removeAt(index));
    await _store.deletePhoto(relative);
  }

  // ---------- 完成 ----------

  Future<void> _finish() async {
    if (_saved) {
      return;
    }
    if (_coachStep == 2) {
      await _completeCoach(2);
      if (mounted) {
        setState(() => _coachStep = null);
      }
    }
    final String place = _placeController.text.trim();
    await ref.read(parkingControllerProvider.notifier).saveNewRecord(
          id: widget.args.recordId,
          fix: widget.args.fix,
          photoPaths: _photoPaths,
          manualPlaceName: place.isEmpty ? null : place,
        );
    _saved = true;
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _dismissCoach(int step, bool neverAgain) {
    setState(() => _coachStep = null);
    _completeCoach(step, neverAgain: neverAgain);
  }

  Future<void> _completeCoach(int step, {bool neverAgain = false}) {
    return ref
        .read(coachMarkControllerProvider.notifier)
        .completeStep(step, neverAgain: neverAgain);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- 构建 ----------

  @override
  Widget build(BuildContext context) {
    final CoachMarkState? coach = ref.watch(coachMarkControllerProvider).valueOrNull;
    if (!_step2Checked && coach != null) {
      _step2Checked = true;
      if (coach.shouldShow(2)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _coachStep = 2);
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.immersive,
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: Column(
              children: <Widget>[
                _buildTopBar(),
                Expanded(child: _buildPreview()),
                _buildPlaceField(),
                _buildControls(),
              ],
            ),
          ),
          if (_coachStep == 2)
            Positioned.fill(
              child: CoachMarkOverlay(
                targetKey: _controlsKey,
                message: '顺手拍张照，找车不迷路；点这里随时完成',
                onDismiss: (bool neverAgain) => _dismissCoach(2, neverAgain),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.onScrim),
            tooltip: '返回',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: AnimatedOpacity(
              opacity: _showHint ? 1 : 0,
              duration: AppTokens.motionNormal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.scrim,
                  borderRadius: BorderRadius.circular(AppTokens.radiusS),
                ),
                child: const Text(
                  '拍一张车的位置、周围标志物，找车不迷路',
                  style: TextStyle(color: AppColors.onScrim, fontSize: AppTokens.fontCaption),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator(color: AppColors.onScrim));
    }
    final CameraController? controller = _controller;
    if (_permissionDenied || controller == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.no_photography_outlined, color: AppColors.onScrim, size: 44),
              const SizedBox(height: 14),
              const Text(
                '未获得相机权限',
                style: TextStyle(color: AppColors.onScrim, fontSize: AppTokens.fontBody),
              ),
              const SizedBox(height: 6),
              Text(
                '仍可只记录位置，点下方按钮完成',
                style: TextStyle(
                  color: AppColors.onScrim.withValues(alpha: 0.7),
                  fontSize: AppTokens.fontCaption,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    // camera 0.11.4 的 `CameraPreview` 自身已是 `AspectRatio`（竖屏时内部用
    // `1 / aspectRatio` 并套 `RotatedBox`）。外面再套一层用**原始** aspectRatio
    // 的 `AspectRatio` 会强制出错误比例的盒子 → 预览被拉伸变形（而 takePicture
    // 走原生像素，存下来的照片正常）。这里直接用 `CameraPreview`，
    // 外层仅加 `ClipRect` 防止极端比例溢出。
    return ClipRect(
      child: Center(child: CameraPreview(controller)),
    );
  }

  Widget _buildPlaceField() {
    final TextTheme text = Theme.of(context).textTheme;
    if (!_placeExpanded) {
      final bool locatingFailed = widget.args.fix == null;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _placeExpanded = true),
            icon: Icon(
              Icons.edit_location_alt_outlined,
              size: 18,
              color: locatingFailed ? AppColors.accent : AppColors.onScrim,
            ),
            label: Text(
              locatingFailed ? '定位失败，补充地点' : '补充地点（可选）',
              style: text.bodySmall?.copyWith(
                color: locatingFailed ? AppColors.accent : AppColors.onScrim,
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: TextField(
        controller: _placeController,
        autofocus: true,
        style: const TextStyle(color: AppColors.onScrim),
        decoration: InputDecoration(
          hintText: '例如：紫荆园东侧',
          hintStyle: TextStyle(color: AppColors.onScrim.withValues(alpha: 0.6)),
          prefixIcon: const Icon(Icons.place_outlined, color: AppColors.onScrim, size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close, color: AppColors.onScrim, size: 20),
            onPressed: () => setState(() => _placeExpanded = false),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusS),
            borderSide: BorderSide(color: AppColors.onScrim.withValues(alpha: 0.4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusS),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        key: _controlsKey,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(child: _buildThumbStrip()),
          const SizedBox(width: 12),
          _buildShutter(),
          const SizedBox(width: 12),
          _buildFinishButton(),
        ],
      ),
    );
  }

  Widget _buildThumbStrip() {
    return SizedBox(
      height: 60,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < _photoPaths.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildThumb(i, _photoPaths[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumb(int index, String relative) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        FutureBuilder<String>(
          future: _store.absolutePhotoPath(relative),
          builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
            // 限分辨率解码：只按 56dp × DPR 解码，避免 3 张原图全分辨率解码吃掉几十 MB。
            final int cacheWidth =
                (56 * MediaQuery.devicePixelRatioOf(context)).round();
            final Widget image = snapshot.hasData
                ? Image.file(
                    File(snapshot.data!),
                    width: 56,
                    height: 56,
                    cacheWidth: cacheWidth,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _thumbFallback(),
                  )
                : _thumbFallback();
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusS),
              child: image,
            );
          },
        ),
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: AppColors.scrim,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: AppColors.onScrim),
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbFallback() {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.onScrim.withValues(alpha: 0.15),
      child: const Icon(Icons.image_outlined, color: AppColors.onScrim, size: 20),
    );
  }

  Widget _buildShutter() {
    final bool disabled = _busy ||
        _controller == null ||
        _photoPaths.length >= AppConstants.maxPhotosPerRecord;
    return Semantics(
      button: true,
      label: '快门',
      child: GestureDetector(
        onTap: disabled ? null : _capture,
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.onScrim, width: 4),
            color: disabled ? AppColors.onScrim.withValues(alpha: 0.4) : AppColors.onScrim,
          ),
        ),
      ),
    );
  }

  Widget _buildFinishButton() {
    return OutlinedButton(
      onPressed: _finish,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(
        _photoPaths.isEmpty ? '不拍了，直接记' : '拍够了就这样',
        style: const TextStyle(fontSize: AppTokens.fontCaption),
      ),
    );
  }
}
