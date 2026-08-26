/// 药箱：存放药品的容器，一个药箱对应一个页面。
class MedicineBox {
  /// 唯一标识（时间戳字符串）
  final String id;
  /// 药箱名，显示在 AppBar
  final String name;
  /// 创建时间
  final DateTime createdAt;

  MedicineBox({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory MedicineBox.fromJson(Map<String, dynamic> json) {
    return MedicineBox(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
