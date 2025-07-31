import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/expense.dart';
import '../providers/budgets_provider.dart';
import '../main.dart';

class ExpensesProvider extends ChangeNotifier {
  final Box<Expense> _expenseBox = Hive.box<Expense>('expenses');

  List<Expense> get expenses {
    try {
      return _expenseBox.values.toList();
    } catch (e) {
      print('Error reading expenses from Hive: $e');
      return [];
    }
  }

  void addExpense(Expense expense, {BudgetsProvider? budgetsProvider}) async {
    await _expenseBox.put(expense.id, expense);
    notifyListeners();
    _checkBudgets(budgetsProvider);
  }

  void updateExpense(
    Expense expense, {
    BudgetsProvider? budgetsProvider,
  }) async {
    await _expenseBox.put(expense.id, expense);
    notifyListeners();
    _checkBudgets(budgetsProvider);
  }

  void deleteExpense(String id) async {
    await _expenseBox.delete(id);
    notifyListeners();
  }

  Expense? getExpense(String id) {
    try {
      return _expenseBox.get(id);
    } catch (e) {
      print('Error reading expense $id from Hive: $e');
      return null;
    }
  }

  void _checkBudgets(BudgetsProvider? budgetsProvider) {
    if (budgetsProvider == null) return;
    final allExpenses = expenses;
    final now = DateTime.now();
    final monthExpenses = allExpenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
    final total = monthExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    final totalBudget = budgetsProvider.totalBudget ?? 0;
    if (totalBudget > 0) {
      final progress = total / totalBudget;
      if (progress >= 1.0) {
        showBudgetNotification(
          'Budget Exceeded',
          'You have exceeded your total monthly budget!',
        );
      } else if (progress >= 0.8) {
        showBudgetNotification(
          'Budget Warning',
          'You have spent 80% of your total monthly budget.',
        );
      }
    }
    // Per-category
    final Map<String, double> byCategory = {};
    for (final e in monthExpenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    byCategory.forEach((catId, spent) {
      final budget = budgetsProvider.getBudgetForCategory(catId) ?? 0;
      if (budget > 0) {
        final progress = spent / budget;
        if (progress >= 1.0) {
          showBudgetNotification(
            'Budget Exceeded',
            'You have exceeded your budget for category: $catId',
          );
        } else if (progress >= 0.8) {
          showBudgetNotification(
            'Budget Warning',
            'You have spent 80% of your budget for category: $catId',
          );
        }
      }
    });
  }
}
