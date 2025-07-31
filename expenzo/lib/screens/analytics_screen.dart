import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/category.dart';
import '../providers/expenses_provider.dart';
import '../providers/categories_provider.dart';
import '../providers/budgets_provider.dart';
import '../theme.dart';
import 'budget_management_screen.dart';
import 'recurring_expenses_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool showPie = true;
  bool showLine = true;
  bool showBar = true;
  bool showInsights = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      showPie = prefs.getBool('showPie') ?? true;
      showLine = prefs.getBool('showLine') ?? true;
      showBar = prefs.getBool('showBar') ?? true;
      showInsights = prefs.getBool('showInsights') ?? true;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showPie', showPie);
    await prefs.setBool('showLine', showLine);
    await prefs.setBool('showBar', showBar);
    await prefs.setBool('showInsights', showInsights);
  }

  void _showCustomizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'Customize Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              value: showPie,
              onChanged: (val) => setState(() => showPie = val),
              title: const Text(
                'Show Category Pie Chart',
                style: TextStyle(color: Colors.white),
              ),
            ),
            SwitchListTile(
              value: showLine,
              onChanged: (val) => setState(() => showLine = val),
              title: const Text(
                'Show Expense Trend (Line Chart)',
                style: TextStyle(color: Colors.white),
              ),
            ),
            SwitchListTile(
              value: showBar,
              onChanged: (val) => setState(() => showBar = val),
              title: const Text(
                'Show Bar Chart',
                style: TextStyle(color: Colors.white),
              ),
            ),
            SwitchListTile(
              value: showInsights,
              onChanged: (val) => setState(() => showInsights = val),
              title: const Text(
                'Show AI Insights',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _savePrefs();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.blueAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Customize Dashboard',
            onPressed: _showCustomizeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Set Budgets',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BudgetManagementScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.repeat),
            tooltip: 'Recurring Expenses',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RecurringExpensesScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Monthly'),
            Tab(text: 'Weekly'),
            Tab(text: 'Yearly'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MonthlyAnalyticsTab(
            showPie: showPie,
            showLine: showLine,
            showBar: showBar,
            showInsights: showInsights,
          ),
          _WeeklyAnalyticsTab(
            showPie: showPie,
            showLine: showLine,
            showBar: showBar,
            showInsights: showInsights,
          ),
          _YearlyAnalyticsTab(
            showPie: showPie,
            showLine: showLine,
            showBar: showBar,
            showInsights: showInsights,
          ),
          _TrendsAnalyticsTab(
            showPie: showPie,
            showLine: showLine,
            showBar: showBar,
            showInsights: showInsights,
          ),
        ],
      ),
    );
  }
}

class _MonthlyAnalyticsTab extends StatelessWidget {
  final bool showPie;
  final bool showLine;
  final bool showBar;
  final bool showInsights;

  const _MonthlyAnalyticsTab({
    required this.showPie,
    required this.showLine,
    required this.showBar,
    required this.showInsights,
  });

  @override
  Widget build(BuildContext context) {
    final expenses = Provider.of<ExpensesProvider>(context).expenses;
    final categories = {
      for (var c in Provider.of<CategoriesProvider>(context).categories)
        c.id: c,
    };
    final budgetsProvider = Provider.of<BudgetsProvider>(context);
    final now = DateTime.now();
    final monthExpenses = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
    final total = monthExpenses.fold<double>(0, (sum, e) => sum + e.amount);

    // Spending by category
    final Map<String, double> byCategory = {};
    for (final e in monthExpenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }

    // Spending by day
    final Map<int, double> byDay = {};
    for (final e in monthExpenses) {
      final day = e.date.day;
      byDay[day] = (byDay[day] ?? 0) + e.amount;
    }

    // Budget progress summary
    final totalBudget = budgetsProvider.totalBudget ?? 0;
    final totalProgress = totalBudget > 0
        ? (total / totalBudget).clamp(0.0, 1.0)
        : 0.0;
    Color getProgressColor(double progress) {
      if (progress >= 1.0) return Colors.redAccent;
      if (progress >= 0.8) return Colors.orangeAccent;
      return Colors.greenAccent;
    }

    return _AnalyticsTabContent(
      key: ValueKey('monthly'),
      total: total,
      byCategory: byCategory,
      byX: byDay,
      xLabel: 'Day',
      categories: categories,
      xMax: DateTime(now.year, now.month + 1, 0).day,
      topWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (totalBudget > 0)
            GlassmorphicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Budget Progress',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: totalProgress > 1.0 ? 1.0 : totalProgress,
                    minHeight: 12,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(
                      getProgressColor(totalProgress),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${total.toStringAsFixed(0)} / ₹${totalBudget.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (totalProgress >= 1.0)
                        Row(
                          children: const [
                            Icon(
                              Icons.warning,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Over budget!',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ],
                        )
                      else if (totalProgress >= 0.8)
                        Row(
                          children: const [
                            Icon(
                              Icons.warning,
                              color: Colors.orangeAccent,
                              size: 18,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Near limit',
                              style: TextStyle(color: Colors.orangeAccent),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          ...byCategory.entries.map((entry) {
            final budget = budgetsProvider.getBudgetForCategory(entry.key) ?? 0;
            if (budget <= 0) return const SizedBox.shrink();
            final progress = (entry.value / budget).clamp(0.0, 1.0);
            final cat = categories[entry.key];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassmorphicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          cat != null
                              ? IconData(cat.icon, fontFamily: 'MaterialIcons')
                              : Icons.category,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cat?.name ?? 'Unknown',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress > 1.0 ? 1.0 : progress,
                      minHeight: 10,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                        getProgressColor(progress),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${entry.value.toStringAsFixed(0)} / ₹${budget.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        if (progress >= 1.0)
                          Row(
                            children: const [
                              Icon(
                                Icons.warning,
                                color: Colors.redAccent,
                                size: 16,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Over budget!',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        else if (progress >= 0.8)
                          Row(
                            children: const [
                              Icon(
                                Icons.warning,
                                color: Colors.orangeAccent,
                                size: 16,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Near limit',
                                style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _WeeklyAnalyticsTab extends StatelessWidget {
  final bool showPie;
  final bool showLine;
  final bool showBar;
  final bool showInsights;

  const _WeeklyAnalyticsTab({
    required this.showPie,
    required this.showLine,
    required this.showBar,
    required this.showInsights,
  });

  @override
  Widget build(BuildContext context) {
    final expenses = Provider.of<ExpensesProvider>(context).expenses;
    final categories = {
      for (var c in Provider.of<CategoriesProvider>(context).categories)
        c.id: c,
    };
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    final weekExpenses = expenses
        .where(
          (e) => !e.date.isBefore(startOfWeek) && !e.date.isAfter(endOfWeek),
        )
        .toList();
    final total = weekExpenses.fold<double>(0, (sum, e) => sum + e.amount);

    // Spending by category
    final Map<String, double> byCategory = {};
    for (final e in weekExpenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }

    // Spending by weekday (1=Mon, 7=Sun)
    final Map<int, double> byWeekday = {};
    for (final e in weekExpenses) {
      final weekday = e.date.weekday;
      byWeekday[weekday] = (byWeekday[weekday] ?? 0) + e.amount;
    }

    return _AnalyticsTabContent(
      key: ValueKey('weekly'),
      total: total,
      byCategory: byCategory,
      byX: byWeekday,
      xLabel: 'Weekday',
      categories: categories,
      xMax: 7,
    );
  }
}

class _YearlyAnalyticsTab extends StatelessWidget {
  final bool showPie;
  final bool showLine;
  final bool showBar;
  final bool showInsights;

  const _YearlyAnalyticsTab({
    required this.showPie,
    required this.showLine,
    required this.showBar,
    required this.showInsights,
  });

  @override
  Widget build(BuildContext context) {
    final expenses = Provider.of<ExpensesProvider>(context).expenses;
    final categories = {
      for (var c in Provider.of<CategoriesProvider>(context).categories)
        c.id: c,
    };
    final now = DateTime.now();
    final yearExpenses = expenses
        .where((e) => e.date.year == now.year)
        .toList();
    final total = yearExpenses.fold<double>(0, (sum, e) => sum + e.amount);

    // Spending by category
    final Map<String, double> byCategory = {};
    for (final e in yearExpenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }

    // Spending by month (1=Jan, 12=Dec)
    final Map<int, double> byMonth = {};
    for (final e in yearExpenses) {
      final month = e.date.month;
      byMonth[month] = (byMonth[month] ?? 0) + e.amount;
    }

    return _AnalyticsTabContent(
      key: ValueKey('yearly'),
      total: total,
      byCategory: byCategory,
      byX: byMonth,
      xLabel: 'Month',
      categories: categories,
      xMax: 12,
    );
  }
}

class _AnalyticsTabContent extends StatefulWidget {
  final double total;
  final Map<String, double> byCategory;
  final Map<int, double> byX;
  final String xLabel;
  final Map<String, Category> categories;
  final int xMax;
  final Widget? topWidget;

  const _AnalyticsTabContent({
    required this.total,
    required this.byCategory,
    required this.byX,
    required this.xLabel,
    required this.categories,
    required this.xMax,
    this.topWidget,
    super.key,
  });

  @override
  State<_AnalyticsTabContent> createState() => _AnalyticsTabContentState();
}

class _AnalyticsTabContentState extends State<_AnalyticsTabContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pieRotation;

  bool get isTrendsTab =>
      (widget.key is ValueKey && (widget.key as ValueKey).value == 'trends');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pieRotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant _AnalyticsTabContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.byX != oldWidget.byX ||
        widget.byCategory != oldWidget.byCategory) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const List<Color> chartColors = [
    Color(0xFF1976D2), // Blue
    Color(0xFF388E3C), // Green
    Color(0xFFFBC02D), // Yellow
    Color(0xFFD32F2F), // Red
    Color(0xFF7B1FA2), // Purple
    Color(0xFF0288D1), // Light Blue
    Color(0xFF388E3C), // Green
    Color(0xFFF57C00), // Orange
    Color(0xFF455A64), // Blue Grey
    Color(0xFF0097A7), // Cyan
    Color(0xFFAFB42B), // Lime
    Color(0xFF5D4037), // Brown
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.topWidget != null) widget.topWidget!,
            GlassmorphicCard(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Spending',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₹${widget.total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (widget.byCategory.isNotEmpty && !isTrendsTab) ...[
              Text(
                'Spending by Category',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: Builder(
                  builder: (context) {
                    final pieKey = ValueKey(
                      widget.byCategory.hashCode.toString() +
                          (widget.key?.toString() ?? ''),
                    );
                    print(
                      'PieChart rebuilt with key: ' +
                          pieKey.toString() +
                          ' and data: ' +
                          widget.byCategory.toString(),
                    );
                    return RotationTransition(
                      turns: _pieRotation,
                      child: PieChart(
                        key: pieKey,
                        PieChartData(
                          sections: widget.byCategory.entries.map((entry) {
                            final cat = widget.categories[entry.key];
                            final color =
                                chartColors[widget.byCategory.keys
                                        .toList()
                                        .indexOf(entry.key) %
                                    chartColors.length];
                            return PieChartSectionData(
                              value: entry.value,
                              title: '',
                              color: color,
                              radius: 60,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              badgeWidget: null,
                            );
                          }).toList(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 32,
                          startDegreeOffset: 180,
                        ),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeInOutCubic,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Legend
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: widget.byCategory.entries.map((entry) {
                  final color =
                      chartColors[widget.byCategory.keys.toList().indexOf(
                            entry.key,
                          ) %
                          chartColors.length];
                  final cat = widget.categories[entry.key];
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        cat?.name ?? 'Other',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '₹${entry.value.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            if (widget.byX.isNotEmpty) ...[
              Text(
                'Spending by ${widget.xLabel}',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: widget.xLabel == 'Weekday'
                      ? MediaQuery.of(context).size.width
                      : widget.xMax * 28.0, // 28px per bar for clarity
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 20,
                        getDrawingHorizontalLine: (value) =>
                            FlLine(color: Colors.white12, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) {
                              if (value % 1 != 0) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                value.toInt().toString(), // No ₹ symbol
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (widget.xLabel == 'Month') {
                                const months = [
                                  'Jan',
                                  'Feb',
                                  'Mar',
                                  'Apr',
                                  'May',
                                  'Jun',
                                  'Jul',
                                  'Aug',
                                  'Sep',
                                  'Oct',
                                  'Nov',
                                  'Dec',
                                ];
                                if (value >= 1 && value <= 12) {
                                  return Text(
                                    months[value.toInt() - 1],
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  );
                                }
                              }
                              if (widget.xLabel == 'Weekday') {
                                const days = [
                                  'Mon',
                                  'Tue',
                                  'Wed',
                                  'Thu',
                                  'Fri',
                                  'Sat',
                                  'Sun',
                                ];
                                if (value >= 1 && value <= 7) {
                                  return Text(
                                    days[value.toInt() - 1],
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10,
                                    ),
                                  );
                                }
                              }
                              return Text(
                                '${value.toInt()}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      barGroups: List.generate(widget.xMax, (i) {
                        final x = i + 1;
                        final y = widget.byX[x] ?? 0.0;
                        final color = chartColors[i % chartColors.length];
                        return BarChartGroupData(
                          x: x,
                          barRods: [
                            BarChartRodData(
                              toY: y,
                              color: color,
                              width: 16,
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                colors: [
                                  color.withOpacity(0.8),
                                  color.withOpacity(0.5),
                                ],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderSide: BorderSide(
                                color: Colors.white12,
                                width: 1,
                              ),
                            ),
                          ],
                          showingTooltipIndicators: [],
                        );
                      }),
                      barTouchData: BarTouchData(enabled: false),
                    ),
                    swapAnimationDuration: Duration.zero,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendsAnalyticsTab extends StatelessWidget {
  final bool showPie;
  final bool showLine;
  final bool showBar;
  final bool showInsights;

  const _TrendsAnalyticsTab({
    required this.showPie,
    required this.showLine,
    required this.showBar,
    required this.showInsights,
  });

  @override
  Widget build(BuildContext context) {
    final expenses = Provider.of<ExpensesProvider>(context).expenses;
    final categories = {
      for (var c in Provider.of<CategoriesProvider>(context).categories)
        c.id: c,
    };
    final now = DateTime.now();

    // This month and last month
    final thisMonth = DateTime(now.year, now.month);
    final lastMonth = DateTime(
      now.month == 1 ? now.year - 1 : now.year,
      now.month == 1 ? 12 : now.month - 1,
    );
    final thisMonthExpenses = expenses
        .where(
          (e) =>
              e.date.year == thisMonth.year && e.date.month == thisMonth.month,
        )
        .toList();
    final lastMonthExpenses = expenses
        .where(
          (e) =>
              e.date.year == lastMonth.year && e.date.month == lastMonth.month,
        )
        .toList();
    final thisMonthTotal = thisMonthExpenses.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );
    final lastMonthTotal = lastMonthExpenses.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );
    final monthChange = lastMonthTotal == 0
        ? null
        : ((thisMonthTotal - lastMonthTotal) / lastMonthTotal) * 100;

    // This week and last week
    final startOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
    final endOfLastWeek = startOfThisWeek.subtract(const Duration(days: 1));
    final thisWeekExpenses = expenses
        .where((e) => !e.date.isBefore(startOfThisWeek) && !e.date.isAfter(now))
        .toList();
    final lastWeekExpenses = expenses
        .where(
          (e) =>
              !e.date.isBefore(startOfLastWeek) &&
              !e.date.isAfter(endOfLastWeek),
        )
        .toList();
    final thisWeekTotal = thisWeekExpenses.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );
    final lastWeekTotal = lastWeekExpenses.fold<double>(
      0,
      (sum, e) => sum + e.amount,
    );
    final weekChange = lastWeekTotal == 0
        ? null
        : ((thisWeekTotal - lastWeekTotal) / lastWeekTotal) * 100;

    // Category trends (month)
    final Map<String, double> thisMonthByCat = {};
    final Map<String, double> lastMonthByCat = {};
    for (final e in thisMonthExpenses) {
      thisMonthByCat[e.category] = (thisMonthByCat[e.category] ?? 0) + e.amount;
    }
    for (final e in lastMonthExpenses) {
      lastMonthByCat[e.category] = (lastMonthByCat[e.category] ?? 0) + e.amount;
    }
    final Set<String> allCats = {
      ...thisMonthByCat.keys,
      ...lastMonthByCat.keys,
    };
    final List<_CategoryTrend> catTrends = allCats.map((catId) {
      final thisVal = thisMonthByCat[catId] ?? 0;
      final lastVal = lastMonthByCat[catId] ?? 0;
      final change = lastVal == 0
          ? null
          : ((thisVal - lastVal) / lastVal) * 100;
      return _CategoryTrend(
        category: categories[catId]?.name ?? 'Unknown',
        icon: categories[catId]?.icon ?? Icons.category.codePoint,
        thisMonth: thisVal,
        lastMonth: lastVal,
        change: change,
      );
    }).toList();
    catTrends.sort((a, b) => (b.change ?? 0).compareTo(a.change ?? 0));

    // --- AI Insights (heuristics) ---
    final List<String> insights = [];
    if (monthChange != null && monthChange.abs() > 10) {
      if (monthChange > 0) {
        insights.add(
          "You spent  ${monthChange.abs().toStringAsFixed(1)}% more this month than last month.",
        );
      } else {
        insights.add(
          "Great job! You spent  ${monthChange.abs().toStringAsFixed(1)}% less this month than last month.",
        );
      }
    }
    if (catTrends.isNotEmpty &&
        catTrends.first.change != null &&
        catTrends.first.change!.abs() > 20) {
      final t = catTrends.first;
      if (t.change! > 0) {
        insights.add(
          "Your spending on  ${t.category} increased by  ${t.change!.abs().toStringAsFixed(1)}% this month.",
        );
      } else {
        insights.add(
          "You reduced your spending on  ${t.category} by  ${t.change!.abs().toStringAsFixed(1)}% this month.",
        );
      }
    }
    if (thisMonthByCat.isNotEmpty) {
      final mostFrequent = thisMonthByCat.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      insights.add(
        "Most of your spending this month was on  ${categories[mostFrequent.key]?.name ?? 'Unknown'}.",
      );
    }
    if (thisMonthExpenses.isNotEmpty) {
      final biggest = thisMonthExpenses.reduce(
        (a, b) => a.amount > b.amount ? a : b,
      );
      final catName = categories[biggest.category]?.name ?? 'Unknown';
      insights.add(
        "Your largest expense this month was ₹  ${biggest.amount.toStringAsFixed(2)} on $catName ( ${biggest.date.toLocal().toString().split(' ')[0]}).",
      );
    }
    if (thisMonthExpenses.isNotEmpty) {
      final daysSoFar = now.day;
      final avgPerDay = thisMonthTotal / daysSoFar;
      final projected = avgPerDay * DateTime(now.year, now.month + 1, 0).day;
      insights.add(
        "At your current pace, you'll spend about ₹  ${projected.toStringAsFixed(0)} this month.",
      );
    }
    if (thisMonthExpenses.length > 3) {
      final avg = thisMonthTotal / thisMonthExpenses.length;
      final unusual = thisMonthExpenses
          .where((e) => e.amount > 2 * avg)
          .toList();
      for (final e in unusual) {
        final catName = categories[e.category]?.name ?? 'Unknown';
        insights.add(
          "Unusually high expense: ₹  ${e.amount.toStringAsFixed(2)} on $catName ( ${e.date.toLocal().toString().split(' ')[0]}).",
        );
      }
    }
    if (monthChange != null && monthChange > 10) {
      insights.add(
        "Tip: Try setting a budget for your top spending categories to save more next month.",
      );
    }
    if (thisMonthByCat.length <= 2 && thisMonthTotal > 0) {
      insights.add(
        "Most of your spending is concentrated in just  ${thisMonthByCat.length} categories. Consider diversifying.",
      );
    }

    return _AnalyticsTabContent(
      key: ValueKey('trends'),
      total: thisMonthTotal,
      byCategory: thisMonthByCat,
      byX: const {}, // No x-axis bar/line chart for trends by default
      xLabel: '',
      categories: categories,
      xMax: 1,
      topWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassmorphicCard(
            child: Column(
              children: [
                const Text(
                  'This Month vs Last Month',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'This Month',
                          style: TextStyle(color: Colors.white54),
                        ),
                        Text(
                          '₹${thisMonthTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          'Last Month',
                          style: TextStyle(color: Colors.white54),
                        ),
                        Text(
                          '₹${lastMonthTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          'Change',
                          style: TextStyle(color: Colors.white54),
                        ),
                        if (monthChange == null)
                          const Text(
                            '-',
                            style: TextStyle(
                              color: Colors.white38,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        else ...[
                          Icon(
                            monthChange > 0
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: monthChange > 0
                                ? Colors.redAccent
                                : Colors.greenAccent,
                            size: 18,
                          ),
                          Text(
                            '${monthChange.abs().toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: monthChange > 0
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GlassmorphicCard(
            child: Column(
              children: [
                const Text(
                  'This Week vs Last Week',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'This Week',
                          style: TextStyle(color: Colors.white54),
                        ),
                        Text(
                          '₹${thisWeekTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          'Last Week',
                          style: TextStyle(color: Colors.white54),
                        ),
                        Text(
                          '₹${lastWeekTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          'Change',
                          style: TextStyle(color: Colors.white54),
                        ),
                        if (weekChange == null)
                          const Text(
                            '-',
                            style: TextStyle(
                              color: Colors.white38,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        else ...[
                          Icon(
                            weekChange > 0
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: weekChange > 0
                                ? Colors.redAccent
                                : Colors.greenAccent,
                            size: 18,
                          ),
                          Text(
                            '${weekChange.abs().toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: weekChange > 0
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Top Category Trends (Month)',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...catTrends.map(
            (trend) => ListTile(
              leading: Icon(
                IconData(trend.icon, fontFamily: 'MaterialIcons'),
                color: Colors.white70,
              ),
              title: Text(
                trend.category,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'This: ₹${trend.thisMonth.toStringAsFixed(2)}  Last: ₹${trend.lastMonth.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white54),
              ),
              trailing: trend.change == null
                  ? const Text(
                      '-',
                      style: TextStyle(
                        color: Colors.white38,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          trend.change! > 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: trend.change! > 0
                              ? Colors.redAccent
                              : Colors.greenAccent,
                          size: 18,
                        ),
                        Text(
                          '${trend.change!.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: trend.change! > 0
                                ? Colors.redAccent
                                : Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTrend {
  final String category;
  final int icon;
  final double thisMonth;
  final double lastMonth;
  final double? change;
  _CategoryTrend({
    required this.category,
    required this.icon,
    required this.thisMonth,
    required this.lastMonth,
    required this.change,
  });
}
