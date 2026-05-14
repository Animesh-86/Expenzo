import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../providers/saving_goals_provider.dart';
import '../models/saving_goal.dart';
import '../theme.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final List<String> _categories = [
    'General',
    'Travel',
    'Electronics',
    'Education',
    'Emergency Fund',
    'Vehicle',
    'Home',
    'Other'
  ];

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case 'Travel': return Icons.flight;
      case 'Electronics': return Icons.devices;
      case 'Education': return Icons.school;
      case 'Emergency Fund': return Icons.health_and_safety;
      case 'Vehicle': return Icons.directions_car;
      case 'Home': return Icons.home;
      default: return Icons.savings;
    }
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'General';
    DateTime? selectedDate;
    int selectedColor = Colors.blueAccent.value;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('New Savings Goal', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Goal Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Target Amount (₹)'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  dropdownColor: Colors.grey[900],
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (val) => setState(() => selectedCategory = val!),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    selectedDate == null ? 'Set Target Date (Optional)' : 'Target: ${DateFormat('MMM d, yyyy').format(selectedDate!)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  trailing: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Pick a Color', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Colors.blueAccent,
                    Colors.greenAccent,
                    Colors.orangeAccent,
                    Colors.purpleAccent,
                    Colors.redAccent,
                  ].map((color) => GestureDetector(
                    onTap: () => setState(() => selectedColor = color.value),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selectedColor == color.value ? Border.all(color: Colors.white, width: 2) : null,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text;
                final amt = double.tryParse(amountController.text);
                if (name.isNotEmpty && amt != null) {
                  Provider.of<SavingGoalsProvider>(context, listen: false).addGoal(
                    SavingGoal(
                      id: const Uuid().v4(),
                      name: name,
                      targetAmount: amt,
                      color: selectedColor,
                      createdAt: DateTime.now(),
                      category: selectedCategory,
                      targetDate: selectedDate,
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showContributeDialog(SavingGoal goal) {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Add to ${goal.name}', style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Amount (₹)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(amountController.text);
              if (amt != null) {
                Provider.of<SavingGoalsProvider>(context, listen: false).contribute(goal.id, amt);
                Navigator.pop(context);
              }
            },
            child: const Text('Add Savings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goals = Provider.of<SavingGoalsProvider>(context).goals;

    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      body: goals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stars, size: 80, color: Colors.blueAccent.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'No savings goals yet.\nStart saving for your dreams!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                final progress = (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
                final isCompleted = goal.currentAmount >= goal.targetAmount;
                
                // Smart calculations
                int? daysLeft;
                double? weeklyNeeded;
                if (goal.targetDate != null && !isCompleted) {
                  daysLeft = goal.targetDate!.difference(DateTime.now()).inDays;
                  if (daysLeft > 0) {
                    final remaining = goal.targetAmount - goal.currentAmount;
                    weeklyNeeded = (remaining / (daysLeft / 7));
                  }
                }

                return Dismissible(
                  key: Key(goal.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    Provider.of<SavingGoalsProvider>(context, listen: false).deleteGoal(goal.id);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GlassmorphicCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(_getCategoryIcon(goal.category), color: Color(goal.color), size: 24),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        goal.name,
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        goal.category ?? 'General',
                                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (isCompleted)
                                const Icon(Icons.check_circle, color: Colors.greenAccent)
                              else
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                                  onPressed: () => _showContributeDialog(goal),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '₹${goal.currentAmount.toStringAsFixed(0)} / ₹${goal.targetAmount.toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(color: Color(goal.color), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation(Color(goal.color)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (isCompleted)
                            const Text('Goal Achieved! 🎉', style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold))
                          else ...[
                            if (goal.targetDate != null) ...[
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month, color: Colors.white38, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Target: ${DateFormat('MMM d, yyyy').format(goal.targetDate!)} (${daysLeft ?? 0} days left)',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                              if (weeklyNeeded != null && weeklyNeeded > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Need to save ₹${weeklyNeeded.toStringAsFixed(0)} per week',
                                    style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ] else
                              Text(
                                '₹${(goal.targetAmount - goal.currentAmount).toStringAsFixed(0)} more to go',
                                style: const TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [100, 500, 1000].map((amt) => InkWell(
                                onTap: () => Provider.of<SavingGoalsProvider>(context, listen: false).contribute(goal.id, amt.toDouble()),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Text(
                                    '+₹$amt',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              )).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGoalDialog,
        tooltip: 'Add Savings Goal',
        child: const Icon(Icons.add),
      ),
    );
  }
}
