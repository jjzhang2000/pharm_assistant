/// 药箱：存放药品的容器，一个药箱对应一个页面。
class MedicineBox {
  /// 可选的水粉/水彩风格药箱底色（ARGB），低饱和柔和，避免浓烈刺眼。
  static const List<int> boxPalette = [
    0xFFBFD7EA, // 水粉蓝
    0xFFC9E4C5, // 水粉绿
    0xFFF4E1B5, // 水粉米黄
    0xFFD9C7E8, // 水粉紫
    0xFFBCE3E0, // 水粉青
    0xFFF3C6D2, // 水粉粉
    0xFFF2D8B1, // 水粉橙
    0xFFC6D4E1, // 水粉灰蓝
  ];

  /// 唯一标识（时间戳字符串）
  final String id;
  /// 药箱名，显示在 AppBar
  final String name;
  /// 创建时间
  final DateTime createdAt;
  /// 药箱底色（ARGB，0 表示尚未分配）
  final int color;

  MedicineBox({
    required this.id,
    required this.name,
    required this.createdAt,
    this.color = 0,
  });

  /// 返回一个未被 [usedColors] 占用的颜色，全部用完后循环回第一个
  static int nextColor(Set<int> usedColors) {
    for (final c in boxPalette) {
      if (!usedColors.contains(c)) return c;
    }
    return boxPalette.first;
  }

  factory MedicineBox.fromJson(Map<String, dynamic> json) {
    return MedicineBox(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      color: json['color'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'color': color,
    };
  }

  MedicineBox copyWith({int? color}) {
    return MedicineBox(
      id: id,
      name: name,
      createdAt: createdAt,
      color: color ?? this.color,
    );
  }
}
