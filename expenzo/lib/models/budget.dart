import 'package:hive/hive.dart';

part 'budget.g.dart';

@HiveType(typeId: 2)
class Budget extends HiveObject {
  @HiveField(0)
  String? categoryId; // null for total budget

  @HiveField(1)
  double amount;

  @HiveField(2)
  String period; // 'Daily', 'Weekly', 'Monthly', 'Yearly' - default 'Monthly'

  Budget({this.categoryId, required this.amount, this.period = 'Monthly'});

  Map<String, dynamic> toMap() => {
    'categoryId': categoryId,
    'amount': amount,
    'period': period,
  };

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
    categoryId: map['categoryId'],
    amount: map['amount'],
    period: map['period'] ?? 'Monthly',
  );
}
