import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/budget.dart';

class BudgetsProvider extends ChangeNotifier {
  final Box<Budget> _budgetBox = Hive.box<Budget>('budgets');

  List<Budget> get budgets {
    try {
      return _budgetBox.values.toList();
    } catch (e) {
      print('Error reading budgets from Hive: $e');
      return [];
    }
  }

  double? getBudgetForCategory(String categoryId) {
    try {
      return _budgetBox.values
          .firstWhere(
            (b) => b.categoryId == categoryId,
            orElse: () => Budget(categoryId: categoryId, amount: 0),
          )
          .amount;
    } catch (e) {
      print('Error reading budget for category $categoryId: $e');
      return 0;
    }
  }

  double? get totalBudget {
    try {
      final b = _budgetBox.values.firstWhere(
        (b) => b.categoryId == null,
        orElse: () => Budget(categoryId: null, amount: 0),
      );
      return b.amount;
    } catch (e) {
      print('Error reading total budget from Hive: $e');
      return 0;
    }
  }

  void setBudget(String? categoryId, double amount) async {
    // Always use null for total budget key and categoryId
    final key = categoryId; // null for total
    await _budgetBox.put(key, Budget(categoryId: categoryId, amount: amount));
    notifyListeners();
  }
}
