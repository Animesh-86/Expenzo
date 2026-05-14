import 'package:hive/hive.dart';

part 'saving_goal.g.dart';

@HiveType(typeId: 4)
class SavingGoal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double targetAmount;

  @HiveField(3)
  double currentAmount;

  @HiveField(4)
  int color;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime? targetDate;

  @HiveField(7)
  String? category;

  SavingGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    required this.color,
    required this.createdAt,
    this.targetDate,
    this.category,
  });
}
