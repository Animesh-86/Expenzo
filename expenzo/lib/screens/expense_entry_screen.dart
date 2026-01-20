import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../providers/expenses_provider.dart';
import '../providers/categories_provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/budgets_provider.dart';
import '../providers/recurring_expenses_provider.dart';
import '../models/recurring_expense.dart';

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

  // Recurring state
  bool _isRecurring = false;
  String _frequency = 'Monthly'; // Daily, Weekly, Monthly, Yearly

  @override
  void initState() {
    super.initState();
    if (widget.initialExpense != null) {
      _amountController.text = widget.initialExpense!.amount.toString();
      _descriptionController.text = widget.initialExpense!.description;
      _selectedDate = widget.initialExpense!.date;
      _selectedCategoryId = widget.initialExpense!.category;
    } else {
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
      final amount = double.parse(_amountController.text);

      // Handle Recurring Expense
      if (_isRecurring && widget.initialExpense == null) {
        final recurringProvider = Provider.of<RecurringExpensesProvider>(
          context,
          listen: false,
        );
        final recurring = RecurringExpense(
          id: const Uuid().v4(),
          amount: amount,
          category: _selectedCategoryId!,
          description: _descriptionController.text,
          recurrence: _frequency.toLowerCase(),
          startDate: _selectedDate,
          nextDueDate: _selectedDate, // Starts immediately/on selected date
        );
        recurringProvider.addRecurring(recurring);

        // Also add the first instance as a regular expense immediately?
        // Typically yes, if the start date is today or past.
        // For now, let's just add the recurring rule. The background job checks for due expenses.
        // Actually, let's trigger the check immediately after adding.

        // Let's also add it as a one-time expense right now so the user sees it immediately
        final expense = Expense(
          id: const Uuid().v4(),
          amount: amount,
          category: _selectedCategoryId!,
          description: _descriptionController.text,
          date: _selectedDate,
        );

        final provider = Provider.of<ExpensesProvider>(context, listen: false);
        final budgetsProvider = Provider.of<BudgetsProvider>(
          context,
          listen: false,
        );
        provider.addExpense(
          expense,
          budgetsProvider: budgetsProvider,
        ); // Add the first one

        Navigator.of(context).pop();
        return;
      }

      // Normal Expense Logic
      final expense = Expense(
        id: widget.initialExpense?.id ?? const Uuid().v4(),
        amount: amount,
        category: _selectedCategoryId!,
        description: _descriptionController.text,
        date: _selectedDate,
      );
      final provider = Provider.of<ExpensesProvider>(context, listen: false);
      final budgetsProvider = Provider.of<BudgetsProvider>(
        context,
        listen: false,
      );

      // Budget check logic... (same as before)
      final categoryBudgetObj = budgetsProvider.getBudgetObject(
        _selectedCategoryId!,
      );
      if (categoryBudgetObj != null && categoryBudgetObj.amount > 0) {
        // crude check for now, can be improved to match period
        // simple check: just notify based on monthly logic for now or skip complex check here
        // reusing existing provider logic is better which is called inside addExpense
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
          : SingleChildScrollView(
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

                        // Recurring Toggle (Only for new expenses)
                        if (widget.initialExpense == null) ...[
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text(
                              'Recurring Expense',
                              style: TextStyle(color: Colors.white),
                            ),
                            value: _isRecurring,
                            onChanged: (val) =>
                                setState(() => _isRecurring = val),
                            activeColor: Colors.blueAccent,
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_isRecurring)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: DropdownButtonFormField<String>(
                                value: _frequency,
                                items: ['Daily', 'Weekly', 'Monthly', 'Yearly']
                                    .map(
                                      (f) => DropdownMenuItem(
                                        value: f,
                                        child: Text(f),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null)
                                    setState(() => _frequency = val);
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Frequency',
                                ),
                              ),
                            ),
                        ],

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
