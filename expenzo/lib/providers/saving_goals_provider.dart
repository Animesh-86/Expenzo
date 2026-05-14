import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/saving_goal.dart';

class SavingGoalsProvider extends ChangeNotifier {
  Box<SavingGoal> get _goalBox {
    if (!Hive.isBoxOpen('saving_goals')) {
      print('Warning: saving_goals box not found.');
    }
    return Hive.box<SavingGoal>('saving_goals');
  }

  List<SavingGoal> get goals {
    try {
      if (!Hive.isBoxOpen('saving_goals')) return [];
      return _goalBox.values.toList();
    } catch (e) {
      print('Error reading saving goals: $e');
      return [];
    }
  }

  void addGoal(SavingGoal goal) async {
    if (!Hive.isBoxOpen('saving_goals')) return;
    await _goalBox.put(goal.id, goal);
    notifyListeners();
  }

  void updateGoal(SavingGoal goal) async {
    if (!Hive.isBoxOpen('saving_goals')) return;
    await _goalBox.put(goal.id, goal);
    notifyListeners();
  }

  void deleteGoal(String id) async {
    if (!Hive.isBoxOpen('saving_goals')) return;
    await _goalBox.delete(id);
    notifyListeners();
  }

  void contribute(String id, double amount) async {
    if (!Hive.isBoxOpen('saving_goals')) return;
    final goal = _goalBox.get(id);
    if (goal != null) {
      goal.currentAmount += amount;
      await goal.save();
      notifyListeners();
    }
  }
}
