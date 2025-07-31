import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/budgets_provider.dart';
import '../providers/categories_provider.dart';
import '../theme.dart';

class BudgetManagementScreen extends StatelessWidget {
  const BudgetManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final budgetsProvider = Provider.of<BudgetsProvider>(context);
    final categories = Provider.of<CategoriesProvider>(context).categories;
    final totalBudgetController = TextEditingController(
      text: budgetsProvider.totalBudget?.toStringAsFixed(0) ?? '',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Set Budgets')),
      body: categories.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 64,
                    color: Colors.blueAccent,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No categories yet!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add categories to set budgets and track your spending.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassmorphicCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Total Monthly Budget',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: totalBudgetController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '₹'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.save, color: Colors.greenAccent),
                        onPressed: () {
                          final val = double.tryParse(
                            totalBudgetController.text,
                          );
                          if (val != null) {
                            budgetsProvider.setBudget(null, val);
                            FocusScope.of(context).unfocus();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Category Budgets',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...categories.map((cat) {
                  final controller = TextEditingController(
                    text:
                        budgetsProvider
                            .getBudgetForCategory(cat.id)
                            ?.toStringAsFixed(0) ??
                        '',
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: GlassmorphicCard(
                      child: Row(
                        children: [
                          Icon(
                            IconData(cat.icon, fontFamily: 'MaterialIcons'),
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              cat.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: '₹'),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.save,
                              color: Colors.greenAccent,
                            ),
                            onPressed: () {
                              final val = double.tryParse(controller.text);
                              if (val != null) {
                                budgetsProvider.setBudget(cat.id, val);
                                FocusScope.of(context).unfocus();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
