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

  Budget? getBudgetObject(String categoryId) {
    try {
      return _budgetBox.values.firstWhere(
        (b) => b.categoryId == categoryId,
        orElse: () =>
            Budget(categoryId: categoryId, amount: 0, period: 'Monthly'),
      );
    } catch (e) {
      print('Error reading budget object for $categoryId: $e');
      return null;
    }
  }

  double? getBudgetForCategory(String categoryId) {
    // Legacy method mostly, but still useful for simple amount checks
    return getBudgetObject(categoryId)?.amount ?? 0;
  }

  double? get totalBudget {
    try {
      final b = _budgetBox.values.firstWhere(
        (b) => b.categoryId == null,
        orElse: () => Budget(categoryId: null, amount: 0, period: 'Monthly'),
      );
      return b.amount;
    } catch (e) {
      print('Error reading total budget from Hive: $e');
      return 0;
    }
  }

  void setBudget(
    String? categoryId,
    double amount, {
    String period = 'Monthly',
  }) async {
    // simple check: if existing budget, update it
    Budget? existing;
    try {
      existing = _budgetBox.values.firstWhere(
        (b) => b.categoryId == categoryId,
      );
    } catch (_) {}

    if (existing != null) {
      existing.amount = amount;
      existing.period = period;
      await existing.save();
    } else {
      await _budgetBox.add(
        Budget(categoryId: categoryId, amount: amount, period: period),
      );
    }
    notifyListeners();
  }
}
