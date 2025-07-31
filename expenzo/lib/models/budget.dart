import 'package:hive/hive.dart';

part 'budget.g.dart';

@HiveType(typeId: 2)
class Budget extends HiveObject {
  @HiveField(0)
  String? categoryId; // null for total budget

  @HiveField(1)
  double amount;

  Budget({this.categoryId, required this.amount});

  Map<String, dynamic> toMap() => {'categoryId': categoryId, 'amount': amount};

  factory Budget.fromMap(Map<String, dynamic> map) =>
      Budget(categoryId: map['categoryId'], amount: map['amount']);
}
