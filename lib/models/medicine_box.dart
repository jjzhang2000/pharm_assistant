class MedicineBox {
  final String id;
  final String name;
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
