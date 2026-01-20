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

    // 1. Check Total Budget (Defaulting to Monthly for now as per legacy, but could be daily)
    // We'll assume total budget is Monthly for simplicity unless we change that UI too.
    final monthExpenses = allExpenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
    final totalSpentMonth = monthExpenses.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );
    final totalBudget = budgetsProvider.totalBudget ?? 0;

    if (totalBudget > 0) {
      final progress = totalSpentMonth / totalBudget;
      if (progress >= 1.0) {
        showBudgetNotification(
          'Total Budget Exceeded',
          'You have exceeded your total monthly budget!',
        );
      } else if (progress >= 0.8) {
        showBudgetNotification(
          'Total Budget Warning',
          'You have spent 80% of your total monthly budget.',
        );
      }
    }

    // 2. Check Category Budgets
    // We need to group expenses by category AND check against that category's specific period
    final categories = allExpenses
        .map((e) => e.category)
        .toSet(); // get all active categories

    for (final catId in categories) {
      final budgetObj = budgetsProvider.getBudgetObject(catId);
      if (budgetObj == null || budgetObj.amount <= 0) continue;

      double spent = 0;
      if (budgetObj.period == 'Daily') {
        spent = allExpenses
            .where(
              (e) =>
                  e.category == catId &&
                  e.date.year == now.year &&
                  e.date.month == now.month &&
                  e.date.day == now.day,
            )
            .fold(0, (sum, e) => sum + e.amount);
      } else {
        // Monthly or others, treat as Monthly default
        spent = allExpenses
            .where(
              (e) =>
                  e.category == catId &&
                  e.date.year == now.year &&
                  e.date.month == now.month,
            )
            .fold(0, (sum, e) => sum + e.amount);
      }

      final progress = spent / budgetObj.amount;
      if (progress >= 1.0) {
        showBudgetNotification(
          'Budget Exceeded',
          'Exceeded ${budgetObj.period} budget for category: $catId',
        );
      } else if (progress >= 0.8) {
        showBudgetNotification(
          'Budget Warning',
          '80% of ${budgetObj.period} budget spent for category: $catId',
        );
      }
    }
  }
}
