import 'enums.dart';

class Category {
  final int? id;
  final String name;
  final String icon;
  final String colorHex;
  final TransactionType type;
  final bool isDefault;
  final DateTime createdAt;

  const Category({
    this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.type,
    this.isDefault = true,
    required this.createdAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      colorHex: map['color_hex'] as String,
      type: TransactionType.fromString(map['type'] as String),
      isDefault: (map['is_default'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color_hex': colorHex,
      'type': type.value,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Category copyWith({
    int? id,
    String? name,
    String? icon,
    String? colorHex,
    TransactionType? type,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.id == id && other.name == name && other.type == type;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ type.hashCode;
}
