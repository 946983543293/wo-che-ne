import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';

/// 本地文件存取（架构 §1.4、§3.2 `LocalStore`、§7.7 照片文件规范）。
///
/// 职责边界（红线）：**所有路径拼接只在此文件**，页面/仓储不直接碰 `File`。
/// - 记录：应用私有目录下的 `records.json`，**原子写入**（先写 `.tmp` 再 rename）。
/// - 照片：应用私有目录下的 `photos/`，命名 `{recordId}_{index}.jpg`，不进系统相册。
///
/// [rootOverride] 仅用于测试注入临时目录；生产环境走
/// `path_provider.getApplicationDocumentsDirectory()`。
class LocalStore {
  /// 创建本地存储访问器。[rootOverride] 传 `Directory` 即注入测试根目录。
  LocalStore({this._rootOverride});

  final Directory? _rootOverride;

  /// 应用私有根目录（记录 JSON 与 photos/ 的父目录）。
  Future<Directory> rootDir() async {
    final Directory? override = _rootOverride;
    if (override != null) {
      if (!await override.exists()) {
        await override.create(recursive: true);
      }
      return override;
    }
    return getApplicationDocumentsDirectory();
  }

  /// 照片目录（`photos/`），不存在时会创建。
  Future<Directory> photosDir() async {
    final Directory root = await rootDir();
    final Directory dir = Directory(_join(root.path, AppConstants.photosDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 记录 JSON 文件句柄。
  Future<File> recordsFile() async {
    final Directory root = await rootDir();
    return File(_join(root.path, AppConstants.recordsFileName));
  }

  /// 读取全部记录的原始 JSON 列表。
  ///
  /// 文件不存在或内容损坏时返回空列表（不抛异常，避免启动即崩）。
  Future<List<Map<String, dynamic>>> readRecords() async {
    final File file = await recordsFile();
    if (!await file.exists()) {
      return <Map<String, dynamic>>[];
    }
    try {
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return <Map<String, dynamic>>[];
      }
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
          .toList();
    } on FormatException catch (error) {
      debugPrint('[LocalStore] records.json 解析失败，按空列表处理：$error');
      return <Map<String, dynamic>>[];
    }
  }

  /// 原子写入全部记录：先写 `records.json.tmp`，flush 后 rename 覆盖目标文件。
  Future<void> writeRecords(List<Map<String, dynamic>> records) async {
    final File file = await recordsFile();
    final File tmp = File('${file.path}.tmp');
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    await tmp.writeAsString(encoder.convert(records), flush: true);
    await tmp.rename(file.path);
  }

  /// 保存一张照片，返回**相对文件名**（`photos/{recordId}_{index}.jpg`）。
  ///
  /// [index] 为照片序号（0 起），与 [ParkingRecord.photoPaths] 对应。
  Future<String> savePhoto(String recordId, int index, List<int> bytes) async {
    final Directory dir = await photosDir();
    final String fileName = '${recordId}_$index.jpg';
    final File file = File(_join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return '${AppConstants.photosDirName}/$fileName';
  }

  /// 删除某条记录的全部照片文件（`{recordId}_*.jpg`）。
  Future<void> deletePhotos(String recordId) async {
    final Directory dir = await photosDir();
    if (!await dir.exists()) {
      return;
    }
    final String prefix = '${recordId}_';
    await for (final FileSystemEntity entity in dir.list()) {
      if (entity is File) {
        final String name = entity.uri.pathSegments.last;
        if (name.startsWith(prefix)) {
          try {
            await entity.delete();
          } on FileSystemException catch (error) {
            debugPrint('[LocalStore] 删除照片失败（忽略）$name：$error');
          }
        }
      }
    }
  }

  /// 删除单张照片文件（按 [relativePath] 相对文件名，如 `photos/{id}_{n}.jpg`）。
  ///
  /// 供拍照页缩略图「×」重拍使用；文件不存在时静默返回。
  Future<void> deletePhoto(String relativePath) async {
    final Directory root = await rootDir();
    final File file = File(_join(root.path, relativePath));
    if (!await file.exists()) {
      return;
    }
    try {
      await file.delete();
    } on FileSystemException catch (error) {
      debugPrint('[LocalStore] 删除照片失败（忽略）$relativePath：$error');
    }
  }

  /// 将照片相对文件名解析为绝对路径（供 UI 渲染 `Image.file`）。
  Future<String> absolutePhotoPath(String relativePath) async {
    final Directory root = await rootDir();
    return _join(root.path, relativePath);
  }

  /// 以 `/` 拼接路径片段（仅本文件内部使用；不引 `package:path` 以少一依赖）。
  static String _join(String base, String child) =>
      base.endsWith('/') ? '$base$child' : '$base/$child';
}
