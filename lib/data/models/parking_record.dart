import '../../core/utils/geo_utils.dart';

/// 停车记录模型（架构 §3.1 字段表 / §7.4 手写 JSON 序列化）。
///
/// 坐标使用高德坐标系（GCJ-02），与高德地图/定位插件天然一致，无需转换。
/// 不引入 build_runner：`fromJson` / `toJson` / `copyWith` 全手写。
class ParkingRecord {
  /// 构造一条停车记录。
  ///
  /// [photoPaths] 为相对文件名列表（`photos/{id}_{n}.jpg`），无论传值与否都会
  /// 归一化为不可变列表，避免外部误改。
  ParkingRecord({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.poiName,
    this.note,
    this.accuracy,
    List<String>? photoPaths,
    required this.createdAt,
    this.archived = false,
  }) : photoPaths = List<String>.unmodifiable(photoPaths ?? const <String>[]);

  /// 记录唯一标识（uuid v4）。
  final String id;

  /// 纬度（GCJ-02）。
  final double latitude;

  /// 经度（GCJ-02）。
  final double longitude;

  /// 高德逆地理得到的地点名；定位失败或未取到时为 null。
  final String? poiName;

  /// 备注（P2-2 预留，本期恒为 null，保留字段以保证 JSON 向前兼容）。
  final String? note;

  /// 定位精度（米）；超过 20 米时 UI 提示「主要靠照片认车」。
  final double? accuracy;

  /// 照片相对文件名列表（0–3 张，形如 `photos/{id}_{n}.jpg`）。
  final List<String> photoPaths;

  /// 记录创建时间（本地时区）。
  final DateTime createdAt;

  /// 是否已归档：false=首页找车态卡片；true=历史列表。
  final bool archived;

  /// 定位失败降级时写入的坐标哨兵 `(0, 0)`。
  ///
  /// 真实经纬度（校园约 40°N/116°E）永不落原点，故 `(0,0)` 可安全表示
  /// 「无坐标」——此时记录退化为「纯照片 + 手动地点」。
  static const double unknownCoordinate = 0.0;

  /// 本条记录是否含有效坐标（找车地图用；降级记录为 false）。
  bool get hasLocation =>
      latitude != unknownCoordinate || longitude != unknownCoordinate;

  /// 本条记录坐标点，供 [GeoUtils] 做方位角/距离计算。
  GeoPoint get point => GeoPoint(latitude, longitude);

  /// 从 JSON 反序列化。
  ///
  /// 对缺失/类型不符的字段采取保守回退（如 `archived` 缺省 false、
  /// `photoPaths` 缺省空列表），保证旧数据可平滑读取。
  factory ParkingRecord.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photoPaths'];
    return ParkingRecord(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      poiName: json['poiName'] as String?,
      note: json['note'] as String?,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      photoPaths: rawPhotos is List
          ? rawPhotos.map((dynamic e) => e.toString()).toList()
          : const <String>[],
      createdAt: DateTime.parse(json['createdAt'] as String),
      archived: json['archived'] as bool? ?? false,
    );
  }

  /// 序列化为 JSON（可被 `jsonEncode` 直接使用）。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'poiName': poiName,
        'note': note,
        'accuracy': accuracy,
        'photoPaths': photoPaths,
        'createdAt': createdAt.toIso8601String(),
        'archived': archived,
      };

  /// 返回一份修改了指定字段的副本。
  ///
  /// 可空字段（[poiName] / [note] / [accuracy]）使用哨兵默认值：
  /// 不传该参数表示「保持原值」，显式传 `null` 表示「置空」。
  ParkingRecord copyWith({
    String? id,
    double? latitude,
    double? longitude,
    Object? poiName = _unset,
    Object? note = _unset,
    Object? accuracy = _unset,
    List<String>? photoPaths,
    DateTime? createdAt,
    bool? archived,
  }) {
    return ParkingRecord(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      poiName: identical(poiName, _unset) ? this.poiName : poiName as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      accuracy:
          identical(accuracy, _unset) ? this.accuracy : (accuracy as num?)?.toDouble(),
      photoPaths: photoPaths ?? this.photoPaths,
      createdAt: createdAt ?? this.createdAt,
      archived: archived ?? this.archived,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParkingRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          poiName == other.poiName &&
          note == other.note &&
          accuracy == other.accuracy &&
          _listEquals(photoPaths, other.photoPaths) &&
          createdAt == other.createdAt &&
          archived == other.archived;

  @override
  int get hashCode => Object.hash(
        id,
        latitude,
        longitude,
        poiName,
        note,
        accuracy,
        Object.hashAll(photoPaths),
        createdAt,
        archived,
      );

  @override
  String toString() =>
      'ParkingRecord(id: $id, poi: $poiName, lat: $latitude, lng: $longitude, '
      'archived: $archived, createdAt: $createdAt)';

  /// `copyWith` 的可空字段哨兵：区分「不传参」与「显式传 null」。
  static const Object _unset = Object();

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
