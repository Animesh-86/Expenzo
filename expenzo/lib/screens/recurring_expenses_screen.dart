import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recurring_expense.dart';
import '../providers/recurring_expenses_provider.dart';
import '../providers/categories_provider.dart';
import '../theme.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart' as widgets;
import '../main.dart';
import 'package:timezone/timezone.dart' as tz;

// Helper function to get IconData from codePoint - uses constant Icons for tree-shaking
IconData getIconFromCodePoint(int codePoint) {
  // Map common code points to constant Icons
  switch (codePoint) {
    case 0xe57a: // Icons.fastfood
      return Icons.fastfood;
    case 0xe53d: // Icons.directions_car
      return Icons.directions_car;
    case 0xe59c: // Icons.shopping_cart
      return Icons.shopping_cart;
    case 0xe227: // Icons.receipt
      return Icons.receipt;
    case 0xe030: // Icons.movie
      return Icons.movie;
    case 0xe3b0: // Icons.local_hospital
      return Icons.local_hospital;
    case 0xe80c: // Icons.school
      return Icons.school;
    case 0xe8cc: // Icons.local_grocery_store
      return Icons.local_grocery_store;
    case 0xe1a0: // Icons.lightbulb
      return Icons.lightbulb;
    case 0xe88a: // Icons.home
      return Icons.home;
    case 0xe263: // Icons.account_balance_wallet
      return Icons.account_balance_wallet;
    case 0xe112: // Icons.card_giftcard
      return Icons.card_giftcard;
    case 0xe14c: // Icons.category
      return Icons.category;
    default:
      return Icons.category; // fallback
  }
}

class RecurringExpensesScreen extends StatelessWidget {
  const RecurringExpensesScreen({super.key});

  void _showRecurringDialog(BuildContext context, {RecurringExpense? exp}) {
    final categories = Provider.of<CategoriesProvider>(
      context,
      listen: false,
    ).categories;
    final amountController = TextEditingController(
      text: exp?.amount.toString() ?? '',
    );
    final descController = TextEditingController(text: exp?.description ?? '');
    String? selectedCategory =
        exp?.category ?? (categories.isNotEmpty ? categories.first.id : null);
    String recurrence = exp?.recurrence ?? 'monthly';
    DateTime nextDueDate =
        exp?.nextDueDate ?? DateTime.now().add(const Duration(days: 30));
    bool reminder = false;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          content: GlassmorphicCard(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    items: categories
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat.id,
                            child: Row(
                              children: [
                                Icon(
                                  getIconFromCodePoint(cat.icon),
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 8),
                                Text(cat.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => selectedCategory = val,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: recurrence,
                    items: const [
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text('Monthly'),
                      ),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    ],
                    onChanged: (val) => recurrence = val ?? 'monthly',
                    decoration: const InputDecoration(labelText: 'Recurrence'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Next Due: ${nextDueDate.toLocal().toString().split(' ')[0]}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: nextDueDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) nextDueDate = picked;
                        },
                        child: const Text('Pick Date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: reminder,
                        onChanged: (val) {
                          reminder = val ?? false;
                          (context as widgets.Element).markNeedsBuild();
                        },
                      ),
                      const Text('Set Reminder'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || selectedCategory == null) return;
                      final provider = Provider.of<RecurringExpensesProvider>(
                        context,
                        listen: false,
                      );
                      final newExp = RecurringExpense(
                        id: exp?.id ?? const Uuid().v4(),
                        amount: amount,
                        category: selectedCategory!,
                        description: descController.text,
                        startDate: exp?.startDate ?? DateTime.now(),
                        recurrence: recurrence,
                        nextDueDate: nextDueDate,
                        endDate: exp?.endDate,
                      );
                      if (exp == null) {
                        provider.addRecurring(newExp);
                      } else {
                        provider.updateRecurring(newExp);
                      }
                      Navigator.of(context).pop();
                      if (reminder) {
                        await flutterLocalNotificationsPlugin.zonedSchedule(
                          exp?.hashCode ??
                              DateTime.now().millisecondsSinceEpoch,
                          'Recurring Expense Reminder',
                          'Your recurring expense is due soon!',
                          tz.TZDateTime.from(nextDueDate, tz.local),
                          NotificationDetails(
                            android: AndroidNotificationDetails(
                              'recurring',
                              'Recurring',
                              importance: Importance.max,
                              color: const Color(0xFF1976D2),
                            ),
                          ),
                          androidScheduleMode:
                              AndroidScheduleMode.exactAllowWhileIdle,
                          matchDateTimeComponents: DateTimeComponents.time,
                        );
                      }
                    },
                    child: Text(exp == null ? 'Add' : 'Update'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<RecurringExpensesProvider>(context);
    final categories = Provider.of<CategoriesProvider>(context).categories;
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Expenses')),
      body: ListView.builder(
        itemCount: provider.recurringExpenses.length,
        itemBuilder: (context, index) {
          final exp = provider.recurringExpenses[index];
          final cat = categories.firstWhere(
            (c) => c.id == exp.category,
            orElse: () => Category(
              id: '',
              name: 'Unknown',
              icon: Icons.category.codePoint,
              isCustom: false,
              color: 0xFF9E9E9E, // Use a default grey color int
            ),
          );
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 6.0,
              horizontal: 12.0,
            ),
            child: GlassmorphicCard(
              child: ListTile(
                leading: Icon(
                  getIconFromCodePoint(cat.icon),
                  color: Colors.white70,
                ),
                title: Text(
                  exp.description,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${exp.amount.toStringAsFixed(2)} • ${cat.name}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      'Next: ${exp.nextDueDate.toLocal().toString().split(' ')[0]} (${exp.recurrence})',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => _showRecurringDialog(context, exp: exp),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => provider.deleteRecurring(exp.id),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRecurringDialog(context),
        tooltip: 'Add Recurring Expense',
        child: const Icon(Icons.add),
      ),
    );
  }
}
