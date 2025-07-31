import 'package:hive/hive.dart';

part 'recurring_expense.g.dart';

@HiveType(typeId: 3)
class RecurringExpense extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  double amount;

  @HiveField(2)
  String category;

  @HiveField(3)
  String description;

  @HiveField(4)
  DateTime startDate;

  @HiveField(5)
  String recurrence; // e.g., 'monthly', 'weekly', 'custom'

  @HiveField(6)
  DateTime nextDueDate;

  @HiveField(7)
  DateTime? endDate;

  RecurringExpense({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.startDate,
    required this.recurrence,
    required this.nextDueDate,
    this.endDate,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'category': category,
    'description': description,
    'startDate': startDate.toIso8601String(),
    'recurrence': recurrence,
    'nextDueDate': nextDueDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
  };

  factory RecurringExpense.fromMap(Map<String, dynamic> map) =>
      RecurringExpense(
        id: map['id'],
        amount: map['amount'],
        category: map['category'],
        description: map['description'],
        startDate: DateTime.parse(map['startDate']),
        recurrence: map['recurrence'],
        nextDueDate: DateTime.parse(map['nextDueDate']),
        endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      );
}
