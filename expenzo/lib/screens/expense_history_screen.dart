import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Main app import to access global functions like scanAndExtractSms
import '../main.dart';

// Models
import '../models/expense.dart';
import '../models/category.dart';

// Providers
import '../providers/expenses_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/recurring_expenses_provider.dart';

// Screens
import 'expense_entry_screen.dart';
import 'analytics_screen.dart';
// import 'recurring_expenses_screen.dart';
import 'profile_screen.dart';

class _Goal {
  String name;
  double target;
  String categoryId;
  DateTime? deadline;
  _Goal({
    required this.name,
    required this.target,
    required this.categoryId,
    this.deadline,
  });
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final List<_Goal> _goals = [];
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedCategoryId;
  final Set<_Goal> _notifiedGoals = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLastMonthGoals());
  }

  Future<void> _checkLastMonthGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastMonthKey =
        '${lastMonth.year}-${lastMonth.month.toString().padLeft(2, '0')}';
    final shown = prefs.getStringList('goal_congrats_$lastMonthKey') ?? [];
    final expenses = Provider.of<ExpensesProvider>(
      context,
      listen: false,
    ).expenses;
    for (final goal in _goals) {
      final spent = expenses
          .where(
            (e) =>
                e.category == goal.categoryId &&
                e.date.year == lastMonth.year &&
                e.date.month == lastMonth.month,
          )
          .fold<double>(0, (sum, e) => sum + e.amount);
      if (spent <= goal.target && !shown.contains(goal.name)) {
        // Show congrats dialog and notification
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Goal Achieved!'),
            content: Text(
              'Congratulations! You stayed under your goal for "${goal.name}" last month.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        showBudgetNotification(
          'Goal Achieved!',
          'Congratulations! You stayed under your goal for "${goal.name}" last month.',
        );
        shown.add(goal.name);
        await prefs.setStringList('goal_congrats_$lastMonthKey', shown);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _addGoal() {
    if (_formKey.currentState!.validate() && _selectedCategoryId != null) {
      setState(() {
        _goals.add(
          _Goal(
            name: _nameController.text.trim(),
            target: double.parse(_amountController.text),
            categoryId: _selectedCategoryId!,
          ),
        );
        _nameController.clear();
        _amountController.clear();
        _selectedCategoryId = null;
      });
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = Provider.of<CategoriesProvider>(context).categories;
    final expenses = Provider.of<ExpensesProvider>(context).expenses;
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Goal Name',
                            hintText: 'e.g. Vacation',
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Enter a name'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Target (₹)',
                            hintText: '10000',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty)
                              return 'Enter amount';
                            final n = double.tryParse(val);
                            if (n == null || n <= 0)
                              return 'Enter valid amount';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addGoal,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat.id,
                            child: Row(
                              children: [
                                Icon(
                                  IconData(
                                    cat.icon,
                                    fontFamily: 'MaterialIcons',
                                  ),
                                  color: Color(cat.color),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(cat.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategoryId = val),
                    validator: (val) => val == null ? 'Select category' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _goals.isEmpty
                  ? const Center(
                      child: Text(
                        'No goals yet. Add your first goal!',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _goals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final goal = _goals[index];
                        final uncategorized = Category(
                          id: 'uncat',
                          name: 'Uncategorized',
                          icon: Icons.category.codePoint,
                          isCustom: false,
                          color: 0xFF9E9E9E,
                        );
                        final cat = categories.firstWhere(
                          (c) => c.id == goal.categoryId,
                          orElse: () => uncategorized,
                        );
                        final spent = expenses
                            .where((e) => e.category == goal.categoryId)
                            .fold<double>(0, (sum, e) => sum + e.amount);
                        final progressRaw = spent / goal.target;
                        final progress = progressRaw.clamp(0.0, 1.0);
                        if (progressRaw >= 1.0 &&
                            !_notifiedGoals.contains(goal)) {
                          _notifiedGoals.add(goal);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Goal Completed!'),
                                content: Text(
                                  'Congratulations! You have completed your goal: "${goal.name}"',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            // Optionally, show a local notification
                            showBudgetNotification(
                              'Goal Completed!',
                              'Congratulations! You have completed your goal: "${goal.name}"',
                            );
                          });
                        }
                        return Card(
                          color: Colors.black.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        if (cat != null)
                                          Icon(
                                            IconData(
                                              cat.icon,
                                              fontFamily: 'MaterialIcons',
                                            ),
                                            color: Color(cat.color),
                                            size: 18,
                                          ),
                                        const SizedBox(width: 6),
                                        Text(
                                          goal.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.amber,
                                            size: 20,
                                          ),
                                          tooltip: 'Edit Goal',
                                          onPressed: () => _showEditGoalDialog(
                                            goal,
                                            categories,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          tooltip: 'Delete Goal',
                                          onPressed: () => _deleteGoal(index),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '₹${goal.target.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Colors.blueAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (goal.deadline != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 2,
                                    ),
                                    child: Text(
                                      'Deadline: ${DateFormat('yyyy-MM-dd').format(goal.deadline!)}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  backgroundColor: Colors.white12,
                                  valueColor: const AlwaysStoppedAnimation(
                                    Colors.greenAccent,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Progress: ${(progress * 100).toStringAsFixed(1)}%  (Spent: ₹${spent.toStringAsFixed(0)})',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteGoal(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal'),
        content: const Text('Are you sure you want to delete this goal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _goals.removeAt(index);
      });
    }
  }

  void _showEditGoalDialog(_Goal goal, List<Category> categories) {
    final nameController = TextEditingController(text: goal.name);
    final amountController = TextEditingController(
      text: goal.target.toStringAsFixed(0),
    );
    String? selectedCategoryId = goal.categoryId;
    DateTime? selectedDeadline = goal.deadline;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Goal Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Target (₹)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat.id,
                          child: Row(
                            children: [
                              Icon(
                                IconData(cat.icon, fontFamily: 'MaterialIcons'),
                                color: Color(cat.color),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(cat.name),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => selectedCategoryId = val,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Deadline:', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDeadline ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365 * 10),
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              selectedDeadline = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            selectedDeadline != null
                                ? DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(selectedDeadline!)
                                : 'No deadline',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  goal.name = nameController.text.trim();
                  goal.target =
                      double.tryParse(amountController.text) ?? goal.target;
                  goal.categoryId = selectedCategoryId ?? goal.categoryId;
                  goal.deadline = selectedDeadline;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

/// Enum for defining how expenses should be sorted.
enum SortOption { date, amount, category }

/// This is the main screen after login, showing expense history and navigation.
class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  // State variables for filtering, sorting, and UI
  SortOption _sortOption = SortOption.date;
  int _selectedIndex = 0;
  String _searchQuery = '';
  String? _selectedCategoryId;

  // State for the custom zoom/grouping functionality
  String _zoomLevel = 'day'; // 'year', 'day', 'month'
  final int _selectedYear = DateTime.now().year;
  final int _selectedMonth = DateTime.now().month;

  final ScrollController _scrollController = ScrollController();
  final Set<_Goal> _notifiedGoals = {};

  @override
  void initState() {
    super.initState();
    // This is the correct place for one-time setup operations.
    // It runs after the first frame is rendered, ensuring context is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize background tasks like SMS scanning and recurring expense checks.
      final recProvider = Provider.of<RecurringExpensesProvider>(
        context,
        listen: false,
      );
      recProvider.processDueRecurringExpenses(context);
      scanAndExtractSms(context);
    });
  }

  /// Sorts a list of expenses based on the current `_sortOption`.
  List<Expense> _sortExpenses(List<Expense> expenses) {
    final sorted = List<Expense>.from(expenses);
    switch (_sortOption) {
      case SortOption.date:
        sorted.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortOption.amount:
        sorted.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case SortOption.category:
        // Assumes categories provider is available to resolve names if needed,
        // but sorting by ID is faster.
        sorted.sort((a, b) => a.category.compareTo(b.category));
        break;
    }
    return sorted;
  }

  /// Handles taps on the bottom navigation bar.
  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Returns the appropriate screen widget based on the selected nav bar index.
  Widget _getScreenForIndex(int index) {
    switch (index) {
      case 0:
        return _buildExpenseHistoryView();
      case 1:
        return const AnalyticsScreen();
      case 2:
        return const GoalsScreen();
      case 3:
        return const ProfileScreen();
      default:
        return _buildExpenseHistoryView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense History'), centerTitle: true),
      body: _getScreenForIndex(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.flag), label: 'Goals'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExpenseEntryScreen()),
                );
              },
              tooltip: 'Add Expense',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// Builds the main view for the expense history tab.
  Widget _buildExpenseHistoryView() {
    final expensesProvider = Provider.of<ExpensesProvider>(context);
    final categoriesProvider = Provider.of<CategoriesProvider>(context);

    // Handle case where categories haven't loaded yet.
    if (categoriesProvider.categories.isEmpty) {
      return _buildCategoryLoadingView(categoriesProvider);
    }

    final categoriesMap = {
      for (var c in categoriesProvider.categories) c.id: c,
    };

    // Apply filtering and sorting to the expenses list.
    final filteredExpenses = _sortExpenses(expensesProvider.expenses)
        .where(
          (e) =>
              (_searchQuery.isEmpty ||
                  e.description.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  (categoriesMap[e.category]?.name.toLowerCase() ?? '')
                      .contains(_searchQuery.toLowerCase())) &&
              (_selectedCategoryId == null ||
                  e.category == _selectedCategoryId),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildFilterControls(categoriesProvider),
          const SizedBox(height: 12),
          _buildZoomControls(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _buildGroupedExpenseList(filteredExpenses, categoriesMap),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the view that shows when categories are not available.
  Widget _buildCategoryLoadingView(CategoriesProvider categoriesProvider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No categories found. Initializing defaults...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              // ADDED: Confirmation dialog to prevent accidental data loss.
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Reset'),
                  content: const Text(
                    'Are you sure you want to delete all app data? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'Reset',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true && mounted) {
                await Future.wait([
                  Hive.box('expenses').clear(),
                  Hive.box('categories').clear(),
                  Hive.box('budgets').clear(),
                  Hive.box('recurring_expenses').clear(),
                ]);
                await categoriesProvider.initializeDefaults();
                // No need to call setState, provider will notify listeners.
              }
            },
            child: const Text('Reset App Data'),
          ),
        ],
      ),
    );
  }

  /// Builds the list of expenses, grouped according to the current zoom level.
  Widget _buildGroupedExpenseList(
    List<Expense> expenses,
    Map<String, Category> categoriesMap,
  ) {
    if (expenses.isEmpty) {
      return const Center(
        child: Text(
          'No expenses found.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    switch (_zoomLevel) {
      case 'year':
        return _buildYearlyView(expenses, categoriesMap);
      case 'month':
        return _buildMonthlyView(expenses, categoriesMap, _selectedYear);
      case 'day':
        return _buildDailyView(
          expenses,
          categoriesMap,
          _selectedYear,
          _selectedMonth,
        );
      default:
        return const Center(
          child: Text(
            'Invalid view state.',
            style: TextStyle(color: Colors.white70),
          ),
        );
    }
  }

  /// Builds the yearly grouped view.
  Widget _buildYearlyView(
    List<Expense> expenses,
    Map<String, Category> categoriesMap,
  ) {
    Map<int, List<Expense>> yearGroups = {};
    for (final e in expenses) {
      yearGroups.putIfAbsent(e.date.year, () => []).add(e);
    }

    final years = yearGroups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      controller: _scrollController,
      itemCount: years.length,
      itemBuilder: (context, index) {
        final year = years[index];
        final expensesForYear = yearGroups[year]!;
        final total = expensesForYear.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );

        return _buildGroupExpansionTile(
          title: _buildGlassGroupHeader(
            title: year.toString(),
            total: '₹${total.toStringAsFixed(0)}',
          ),
          children: [
            _buildMonthlyView(
              expensesForYear,
              categoriesMap,
              year,
              isSubLevel: true,
            ),
          ],
        );
      },
    );
  }

  /// Builds the monthly grouped view.
  Widget _buildMonthlyView(
    List<Expense> expenses,
    Map<String, Category> categoriesMap,
    int year, {
    bool isSubLevel = false,
  }) {
    Map<int, List<Expense>> monthGroups = {};
    for (final e in expenses.where((exp) => exp.date.year == year)) {
      monthGroups.putIfAbsent(e.date.month, () => []).add(e);
    }

    final months = monthGroups.keys.toList()..sort((a, b) => b.compareTo(a));
    if (months.isEmpty) {
      return const Center(
        child: Text(
          'No expenses for this period.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      controller: isSubLevel ? null : _scrollController,
      shrinkWrap: isSubLevel,
      physics: isSubLevel ? const NeverScrollableScrollPhysics() : null,
      itemCount: months.length,
      itemBuilder: (context, index) {
        final month = months[index];
        final monthName = DateFormat('MMMM').format(DateTime(year, month));
        final expensesForMonth = monthGroups[month]!;
        final total = expensesForMonth.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );

        if (isSubLevel) {
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            title: Text(
              monthName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            trailing: Text(
              '₹${total.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          );
        }

        return _buildGroupExpansionTile(
          title: _buildGlassGroupHeader(
            title: '$monthName $year',
            total: '₹${total.toStringAsFixed(0)}',
          ),
          children: expensesForMonth
              .map((e) => _buildExpenseListTile(e, categoriesMap[e.category]))
              .toList(),
        );
      },
    );
  }

  /// Builds the daily grouped view.
  Widget _buildDailyView(
    List<Expense> expenses,
    Map<String, Category> categoriesMap,
    int year,
    int month,
  ) {
    Map<int, List<Expense>> dayGroups = {};
    for (final e in expenses.where(
      (exp) => exp.date.year == year && exp.date.month == month,
    )) {
      dayGroups.putIfAbsent(e.date.day, () => []).add(e);
    }

    final days = dayGroups.keys.toList()..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) {
      return const Center(
        child: Text(
          'No expenses for this period.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final date = DateTime(year, month, day);
        final expensesForDay = dayGroups[day]!;
        final total = expensesForDay.fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );

        return _buildGroupExpansionTile(
          title: _buildGlassGroupHeader(
            title: DateFormat('EEEE, MMM d, yyyy').format(date),
            total: '₹${total.toStringAsFixed(0)}',
            isSubHeader: true,
          ),
          children: expensesForDay
              .map((e) => _buildExpenseListTile(e, categoriesMap[e.category]))
              .toList(),
        );
      },
    );
  }

  /// A reusable widget for the glassmorphic group headers.
  Widget _buildGlassGroupHeader({
    required String title,
    required String total,
    bool isSubHeader = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSubHeader ? 16 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                        blurRadius: 6,
                        color: Colors.black54,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    total,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black38,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A reusable wrapper for the ExpansionTile to keep styling consistent.
  Widget _buildGroupExpansionTile({
    required Widget title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: title,
        children: children
            .map(
              (child) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: child,
              ),
            )
            .toList(),
      ),
    );
  }

  /// Builds a single list tile for an expense item.
  Widget _buildExpenseListTile(Expense e, Category? cat) {
    final dateLabel = DateFormat('MMM d').format(e.date);
    return Card(
      color: Colors.black.withOpacity(0.3),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // Icon and category name vertically aligned
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: cat != null
                      ? Color(cat.color)
                      : Colors.blueAccent,
                  child: Icon(
                    cat != null
                        ? IconData(cat.icon, fontFamily: 'MaterialIcons')
                        : Icons.category,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 48,
                  child: Text(
                    cat?.name ?? 'Uncategorized',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Name (description)
            Expanded(
              flex: 3,
              child: Text(
                e.description,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Date in the middle
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dateLabel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            // Cost (amount)
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '₹${e.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the row containing search, filter, and sort controls.
  Widget _buildFilterControls(CategoriesProvider categoriesProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search expenses...',
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 8,
            ),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Category Filter Dropdown
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String?>(
                value: _selectedCategoryId,
                dropdownColor: Colors.black87,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  isDense: true,
                ),
                icon: const Icon(
                  Icons.filter_list,
                  color: Colors.white,
                  size: 18,
                ),
                hint: const Text(
                  'All Categories',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text(
                      'All Categories',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  ...categoriesProvider.categories.map(
                    (cat) => DropdownMenuItem(
                      value: cat.id,
                      child: Row(
                        children: [
                          Icon(
                            IconData(cat.icon, fontFamily: 'MaterialIcons'),
                            color: Color(cat.color),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cat.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
            ),
            const SizedBox(width: 8),
            // Sort By Dropdown
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<SortOption>(
                value: _sortOption,
                dropdownColor: Colors.black87,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  isDense: true,
                ),
                icon: const Icon(Icons.sort, color: Colors.white, size: 18),
                isExpanded: true,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                items: const [
                  DropdownMenuItem(value: SortOption.date, child: Text('Date')),
                  DropdownMenuItem(
                    value: SortOption.amount,
                    child: Text('Amount'),
                  ),
                  DropdownMenuItem(
                    value: SortOption.category,
                    child: Text('Category'),
                  ),
                ],
                onChanged: (val) => setState(() => _sortOption = val!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the toggle buttons for changing the zoom/grouping level.
  Widget _buildZoomControls() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1.2,
                ),
              ),
              child: ToggleButtons(
                isSelected: [
                  _zoomLevel == 'year',
                  _zoomLevel == 'day',
                  _zoomLevel == 'month',
                ],
                onPressed: (index) {
                  setState(() {
                    if (index == 0) _zoomLevel = 'year';
                    if (index == 1) _zoomLevel = 'day';
                    if (index == 2) _zoomLevel = 'month';
                  });
                },
                borderRadius: BorderRadius.circular(16),
                selectedColor: Colors.black,
                fillColor: Theme.of(
                  context,
                ).colorScheme.secondary.withOpacity(0.85),
                color: Colors.white,
                borderColor: Colors.transparent,
                selectedBorderColor: Colors.transparent,
                constraints: const BoxConstraints(minHeight: 36, minWidth: 70),
                children: ['Year', 'Day', 'Month']
                    .map(
                      (label) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(label),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
