import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/expenses_provider.dart';
import '../providers/categories_provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/budgets_provider.dart';

class ExpenseEntryScreen extends StatefulWidget {
  final Expense? initialExpense;
  const ExpenseEntryScreen({super.key, this.initialExpense});

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    if (widget.initialExpense != null) {
      _amountController.text = widget.initialExpense!.amount.toString();
      _descriptionController.text = widget.initialExpense!.description;
      _selectedDate = widget.initialExpense!.date;
      _selectedCategoryId = widget.initialExpense!.category;
    } else {
      // Set default category if available
      final categories = Provider.of<CategoriesProvider>(
        context,
        listen: false,
      ).categories;
      if (categories.isNotEmpty) {
        _selectedCategoryId = categories.first.id;
      } else {
        _selectedCategoryId = null;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate() && _selectedCategoryId != null) {
      final expense = Expense(
        id: widget.initialExpense?.id ?? const Uuid().v4(),
        amount: double.parse(_amountController.text),
        category: _selectedCategoryId!,
        description: _descriptionController.text,
        date: _selectedDate,
      );
      final provider = Provider.of<ExpensesProvider>(context, listen: false);
      final budgetsProvider = Provider.of<BudgetsProvider>(
        context,
        listen: false,
      );
      final categoryBudget = budgetsProvider.getBudgetForCategory(
        _selectedCategoryId!,
      );
      final categoryExpenses = provider.expenses
          .where((e) => e.category == _selectedCategoryId!)
          .fold<double>(0, (sum, e) => sum + e.amount);
      if (categoryBudget != null && categoryBudget > 0) {
        final percent = (categoryExpenses + expense.amount) / categoryBudget;
        if (percent >= 1.0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have exceeded your budget for this category!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        } else if (percent >= 0.8) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You are nearing your budget limit for this category.',
              ),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      }
      if (widget.initialExpense == null) {
        provider.addExpense(expense, budgetsProvider: budgetsProvider);
      } else {
        provider.updateExpense(expense, budgetsProvider: budgetsProvider);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = Provider.of<CategoriesProvider>(context).categories;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.initialExpense == null ? 'Add Expense' : 'Edit Expense',
        ),
        centerTitle: true,
      ),
      body: categories.isEmpty
          ? Center(
              child: Text(
                'No categories found. Please add a category first.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedCategoryId,
                          items: categories
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat.id,
                                  child: Text(cat.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedCategoryId = val),
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          validator: (value) =>
                              value == null ? 'Select a category' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Date: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedDate = picked;
                                  });
                                }
                              },
                              child: const Text('Pick Date'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: categories.isEmpty ? null : _submit,
                          child: Text(
                            widget.initialExpense == null
                                ? 'Add Expense'
                                : 'Update Expense',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
