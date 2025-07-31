import 'package:hive/hive.dart';

part 'category.g.dart';

@HiveType(typeId: 1)
class Category extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int icon; // Store icon as codePoint for easy serialization

  @HiveField(3)
  bool isCustom;

  @HiveField(4)
  int color; // Store color as ARGB int

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.isCustom,
    required this.color,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'isCustom': isCustom,
    'color': color,
  };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
    id: map['id'],
    name: map['name'],
    icon: map['icon'],
    isCustom: map['isCustom'],
    color: map['color'] ?? 0xFF1976D2,
  );
}
