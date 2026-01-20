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
import 'goals_screen.dart';
import 'profile_screen.dart';

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
  // final Set<_Goal> _notifiedGoals = {}; // REMOVED: Old goal logic

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
    return Dismissible(
      key: Key(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Delete Expense?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this expense?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        Provider.of<ExpensesProvider>(
          context,
          listen: false,
        ).deleteExpense(e.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${e.description}'),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () {
                // To implement undo, we'd need to re-add the expense.
                // For now, let's just notify.
                // A proper undo would require holding the expense object and re-adding it.
                Provider.of<ExpensesProvider>(
                  context,
                  listen: false,
                ).addExpense(e);
              },
            ),
          ),
        );
      },
      child: Card(
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
                          ? getIconFromCodePoint(cat.icon)
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
      ),
    );
  }

  /// Builds the row containing search, filter, and sort controls.
  Widget _buildFilterControls(CategoriesProvider categoriesProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Glassy Search Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search expenses...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Category Filter
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _selectedCategoryId,
                        dropdownColor: const Color(0xFF1E1E1E),
                        icon: const Icon(
                          Icons.filter_list,
                          color: Colors.white54,
                          size: 18,
                        ),
                        hint: const Text(
                          'Cat.',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text(
                              'All',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          ...categoriesProvider.categories.map(
                            (cat) => DropdownMenuItem(
                              value: cat.id,
                              child: Row(
                                children: [
                                  Icon(
                                    getIconFromCodePoint(cat.icon),
                                    color: Color(cat.color),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cat.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedCategoryId = val),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Sort By Filter
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<SortOption>(
                        value: _sortOption,
                        dropdownColor: const Color(0xFF1E1E1E),
                        icon: const Icon(
                          Icons.sort,
                          color: Colors.white54,
                          size: 18,
                        ),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(
                            value: SortOption.date,
                            child: Text('Date', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: SortOption.amount,
                            child: Text('Val.', style: TextStyle(fontSize: 14)),
                          ),
                          DropdownMenuItem(
                            value: SortOption.category,
                            child: Text('Cat.', style: TextStyle(fontSize: 14)),
                          ),
                        ],
                        onChanged: (val) => setState(() => _sortOption = val!),
                      ),
                    ),
                  ),
                ),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildZoomSegment('Year', 'year'),
                const SizedBox(width: 4),
                _buildZoomSegment('Month', 'month'),
                const SizedBox(width: 4),
                _buildZoomSegment('Day', 'day'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomSegment(String label, String value) {
    final isSelected = _zoomLevel == value;
    return GestureDetector(
      onTap: () => setState(() => _zoomLevel = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
