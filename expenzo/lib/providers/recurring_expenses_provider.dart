import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/recurring_expense.dart';
import '../models/expense.dart';
import 'package:provider/provider.dart';
import 'expenses_provider.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';
import '../providers/budgets_provider.dart';

class RecurringExpensesProvider extends ChangeNotifier {
  final Box<RecurringExpense> _recurringBox = Hive.box<RecurringExpense>(
    'recurring_expenses',
  );

  List<RecurringExpense> get recurringExpenses {
    try {
      return _recurringBox.values.toList();
    } catch (e) {
      print('Error reading recurring expenses from Hive: $e');
      return [];
    }
  }

  void addRecurring(RecurringExpense exp) async {
    await _recurringBox.put(exp.id, exp);
    notifyListeners();
  }

  void updateRecurring(RecurringExpense exp) async {
    await _recurringBox.put(exp.id, exp);
    notifyListeners();
  }

  void deleteRecurring(String id) async {
    await _recurringBox.delete(id);
    notifyListeners();
  }

  RecurringExpense? getRecurring(String id) {
    try {
      return _recurringBox.get(id);
    } catch (e) {
      print('Error reading recurring expense $id from Hive: $e');
      return null;
    }
  }

  List<RecurringExpense> getUpcomingReminders({int daysAhead = 3}) {
    final now = DateTime.now();
    final upcoming = recurringExpenses
        .where(
          (e) =>
              e.nextDueDate.isAfter(now) &&
              e.nextDueDate.isBefore(now.add(Duration(days: daysAhead))),
        )
        .toList();
    return upcoming;
  }

  Future<void> scheduleUpcomingReminders({int daysAhead = 3}) async {
    final reminders = getUpcomingReminders(daysAhead: daysAhead);
    for (final exp in reminders) {
      final dueIn = exp.nextDueDate.difference(DateTime.now()).inDays;
      if (dueIn >= 0 && dueIn <= daysAhead) {
        await showBudgetNotification(
          'Upcoming Bill: ${exp.description}',
          'Your ${exp.description} (${exp.category}) of ₹${exp.amount.toStringAsFixed(2)} is due on ${exp.nextDueDate.toLocal().toString().split(' ')[0]}.',
        );
      }
    }
  }

  Future<void> processDueRecurringExpenses(BuildContext context) async {
    final now = DateTime.now();
    final expensesProvider = Provider.of<ExpensesProvider>(
      context,
      listen: false,
    );
    final budgetsProvider = Provider.of<BudgetsProvider>(
      context,
      listen: false,
    );
    for (final rec in recurringExpenses) {
      if (rec.nextDueDate.isBefore(now) || _isSameDay(rec.nextDueDate, now)) {
        // Check if already added for this due date
        final alreadyExists = expensesProvider.expenses.any(
          (e) =>
              e.description == rec.description &&
              e.amount == rec.amount &&
              _isSameDay(e.date, rec.nextDueDate),
        );
        if (!alreadyExists) {
          // Add to main expenses
          final newExpense = Expense(
            id: const Uuid().v4(),
            amount: rec.amount,
            category: rec.category,
            description: rec.description,
            date: rec.nextDueDate,
          );
          expensesProvider.addExpense(
            newExpense,
            budgetsProvider: budgetsProvider,
          );
        }
        // Update nextDueDate
        DateTime next = rec.nextDueDate;
        if (rec.recurrence == 'monthly') {
          next = DateTime(next.year, next.month + 1, next.day);
        } else if (rec.recurrence == 'weekly') {
          next = next.add(const Duration(days: 7));
        }
        if (rec.endDate == null || next.isBefore(rec.endDate!)) {
          rec.nextDueDate = next;
          await _recurringBox.put(rec.id, rec);
        }
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
