import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/budgets_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/expenses_provider.dart';
import '../theme.dart';
import '../models/budget.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

IconData _getIconFromCodePoint(int codePoint) {
  return IconData(codePoint, fontFamily: 'MaterialIcons');
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  Widget build(BuildContext context) {
    final categories = Provider.of<CategoriesProvider>(context).categories;
    final budgetsProvider = Provider.of<BudgetsProvider>(context);
    final expensesProvider = Provider.of<ExpensesProvider>(context);

    // Calculate total spend for today and this month for the "Total Budget" card
    final now = DateTime.now();
    final allExpenses = expensesProvider.expenses;
    final monthSpend = allExpenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);

    final totalBudget = budgetsProvider.totalBudget ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Goals & Budgets')),
      body: categories.isEmpty
          ? const Center(
              child: Text(
                'Add categories first!',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Total Monthly Budget Card
                GlassmorphicCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Monthly Budget',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: Colors.blueAccent,
                            ),
                            onPressed: () => _showEditBudgetDialog(
                              context,
                              budgetsProvider,
                              null, // null category for total
                              'Total Budget',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildProgressBar(
                        current: monthSpend,
                        target: totalBudget,
                        label: 'Monthly Spend',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Category Goals',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),

                // List of Categories with Budgets
                ...categories.map((cat) {
                  final budgetObj = budgetsProvider.getBudgetObject(cat.id);
                  final budgetAmount = budgetObj?.amount ?? 0;
                  final period = budgetObj?.period ?? 'Monthly';

                  // Calculate spent based on period
                  double spent = 0;
                  if (budgetObj != null && budgetObj.period == 'Daily') {
                    spent = allExpenses
                        .where(
                          (e) =>
                              e.category == cat.id &&
                              e.date.year == now.year &&
                              e.date.month == now.month &&
                              e.date.day == now.day,
                        )
                        .fold(0.0, (sum, e) => sum + e.amount);
                  } else {
                    spent = allExpenses
                        .where(
                          (e) =>
                              e.category == cat.id &&
                              e.date.year == now.year &&
                              e.date.month == now.month,
                        )
                        .fold(0.0, (sum, e) => sum + e.amount);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GlassmorphicCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getIconFromCodePoint(cat.icon),
                                color: Color(cat.color),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  cat.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                budgetAmount > 0
                                    ? '${period} Goal'
                                    : 'No Goal Set',
                                style: TextStyle(
                                  color: budgetAmount > 0
                                      ? Colors.greenAccent
                                      : Colors.white24,
                                  fontSize: 12,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  size: 20,
                                  color: Colors.white70,
                                ),
                                onPressed: () => _showEditBudgetDialog(
                                  context,
                                  budgetsProvider,
                                  cat.id,
                                  cat.name,
                                ),
                              ),
                            ],
                          ),
                          if (budgetAmount > 0) ...[
                            const SizedBox(height: 8),
                            _buildProgressBar(
                              current: spent,
                              target: budgetAmount,
                              label: period == 'Daily'
                                  ? "Today's Spend"
                                  : "Month's Spend",
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildProgressBar({
    required double current,
    required double target,
    required String label,
  }) {
    if (target <= 0) {
      return const Text(
        'No budget set',
        style: TextStyle(color: Colors.white38),
      );
    }
    final progress = (current / target).clamp(0.0, 1.0);
    final isExceeded = current > target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Text(
              '₹${current.toStringAsFixed(0)} / ₹${target.toStringAsFixed(0)}',
              style: TextStyle(
                color: isExceeded ? Colors.redAccent : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.white10,
          color: isExceeded
              ? Colors.redAccent
              : (progress > 0.8 ? Colors.orangeAccent : Colors.greenAccent),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        if (current <= target && target > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Goal Achieved! (₹${(target - current).toStringAsFixed(0)} left)',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
            ),
          ),
        if (isExceeded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Exceeded by ₹${(current - target).toStringAsFixed(0)}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
          ),
      ],
    );
  }

  void _showEditBudgetDialog(
    BuildContext context,
    BudgetsProvider provider,
    String? categoryId,
    String name,
  ) {
    final existing = categoryId == null
        ? (provider.totalBudget == 0
              ? null
              : Budget(
                  amount: provider.totalBudget ?? 0,
                  categoryId: null,
                )) // pseudo-budget for total
        : provider.getBudgetObject(categoryId);

    final amountController = TextEditingController(
      text: existing?.amount.toStringAsFixed(0) ?? '',
    );
    String selectedPeriod = existing?.period ?? 'Monthly';

    // Total budget is typically Monthly, so maybe lock it or allow Daily too?
    // User request implies per-category flexibility. For Total, keeping it simple or flexible is fine.
    // Let's allow flexible for all.

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF232526),
          title: Text(
            'Set Goal for $name',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: selectedPeriod,
                dropdownColor: Colors.black87,
                isExpanded: true,
                style: const TextStyle(color: Colors.white),
                underline: Container(height: 1, color: Colors.white24),
                items: ['Daily', 'Monthly']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedPeriod = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountController.text);
                if (amt != null) {
                  provider.setBudget(categoryId, amt, period: selectedPeriod);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
