import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../services/database_interface.dart';
import '../../services/database_service.dart';
import '../../services/mock_database_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../widgets/empty_state.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with TickerProviderStateMixin {
  late final DatabaseInterface _db;
  late final TabController _tabCtrl;

  List<Transaction> _transactions = [];
  List<Category> _categories = [];
  bool _loading = true;
  FilterPeriod _period = FilterPeriod.month;

  double _totalIncome = 0, _totalExpense = 0;
  final Map<String, double> _expByCat = {};
  final Map<String, double> _incByCat = {};
  final List<FlSpot> _incSpots = [], _expSpots = [];

  @override
  void initState() {
    super.initState();
    _db = kIsWeb ? MockDatabaseService() : DatabaseService();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_db.getTransactions(), _db.getCategories()]);
      _transactions = results[0] as List<Transaction>;
      _categories = results[1] as List<Category>;
      _calc();
      setState(() => _loading = false);
    } catch (_) { setState(() => _loading = false); }
  }

  Category? _catFor(int id) {
    try { return _categories.firstWhere((c) => c.id == id); } catch (_) { return null; }
  }

  DateTime _startDate(DateTime now) => switch (_period) {
    FilterPeriod.week => now.subtract(const Duration(days: 7)),
    FilterPeriod.month => DateTime(now.year, now.month - 1, now.day),
    FilterPeriod.year => DateTime(now.year - 1, now.month, now.day),
    FilterPeriod.all => DateTime(2020, 1, 1),
  };

  void _calc() {
    final now = DateTime.now();
    final start = _startDate(now);
    final filtered = _transactions.where((t) => t.date.isAfter(start)).toList();

    _totalIncome = 0; _totalExpense = 0;
    _expByCat.clear(); _incByCat.clear();

    for (final t in filtered) {
      final name = _catFor(t.categoryId)?.name ?? 'Unknown';
      if (t.type == TransactionType.income) {
        _totalIncome += t.amount;
        _incByCat[name] = (_incByCat[name] ?? 0) + t.amount;
      } else {
        _totalExpense += t.amount;
        _expByCat[name] = (_expByCat[name] ?? 0) + t.amount;
      }
    }

    final incByDay = <String, double>{};
    final expByDay = <String, double>{};
    for (final t in filtered) {
      final key = DateFormat('yyyy-MM-dd').format(t.date);
      if (t.type == TransactionType.income) {
        incByDay[key] = (incByDay[key] ?? 0) + t.amount;
      } else {
        expByDay[key] = (expByDay[key] ?? 0) + t.amount;
      }
    }

    _incSpots.clear(); _expSpots.clear();
    var cur = start;
    int i = 0;
    while (cur.isBefore(now) || cur.isAtSameMomentAs(now)) {
      final key = DateFormat('yyyy-MM-dd').format(cur);
      _incSpots.add(FlSpot(i.toDouble(), incByDay[key] ?? 0));
      _expSpots.add(FlSpot(i.toDouble(), expByDay[key] ?? 0));
      cur = cur.add(const Duration(days: 1));
      i++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: 'Overview'), Tab(text: 'Expenses'), Tab(text: 'Income')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _PeriodSelector(period: _period, onChanged: (p) { setState(() => _period = p); _calc(); setState(() {}); }),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [_overviewTab(), _pieTab(_expByCat, 'Expenses by Category', Colors.red), _pieTab(_incByCat, 'Income by Category', Colors.green)],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _overviewTab() {
    final balance = _totalIncome - _totalExpense;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: _MetricCard(title: 'Income', value: AppConstants.formatAmount(_totalIncome), color: AppTheme.incomeColor, icon: Icons.arrow_upward)),
            const SizedBox(width: 12),
            Expanded(child: _MetricCard(title: 'Expenses', value: AppConstants.formatAmount(_totalExpense), color: AppTheme.expenseColor, icon: Icons.arrow_downward)),
          ],
        ),
        const SizedBox(height: 12),
        _MetricCard(title: 'Balance', value: AppConstants.formatAmount(balance), color: balance >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor, icon: balance >= 0 ? Icons.trending_up : Icons.trending_down),
        const SizedBox(height: 24),
        _lineChart(),
      ],
    );
  }

  Widget _lineChart() {
    if (_incSpots.isEmpty && _expSpots.isEmpty) {
      return const EmptyState(icon: Icons.show_chart, title: 'No chart data');
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Income vs Expenses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: LineChart(LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50, getTitlesWidget: (v, _) => v == 0 ? const Text('0', style: TextStyle(fontSize: 10)) : Text('${(v / 1000).toStringAsFixed(0)}k', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)))),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: _incSpots,
                  isCurved: true,
                  color: AppTheme.incomeColor,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.incomeColor.withAlpha((AppTheme.incomeColor.a * 0.08 * 255.0).round().clamp(0, 255)),
                  ),
                ),
                LineChartBarData(
                  spots: _expSpots,
                  isCurved: true,
                  color: AppTheme.expenseColor,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppTheme.expenseColor.withAlpha((AppTheme.expenseColor.a * 0.08 * 255.0).round().clamp(0, 255)),
                  ),
                ),
              ],
            )),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: AppTheme.incomeColor, label: 'Income'),
              const SizedBox(width: 20),
              _LegendDot(color: AppTheme.expenseColor, label: 'Expenses'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pieTab(Map<String, double> data, String title, MaterialColor colorScheme) {
    if (data.isEmpty) {
      return const EmptyState(icon: Icons.pie_chart_outline, title: 'No data for this period');
    }
    final total = data.values.fold(0.0, (s, v) => s + v);
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final shades = [600, 500, 400, 700, 300, 800, 200, 900];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              SizedBox(
                height: 220,
                child: PieChart(PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: entries.asMap().entries.map((e) {
                    final pct = (e.value.value / total * 100);
                    return PieChartSectionData(
                      color: colorScheme[shades[e.key % shades.length]]!,
                      value: e.value.value,
                      title: '${pct.toStringAsFixed(1)}%',
                      radius: 70,
                      titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    );
                  }).toList(),
                )),
              ),
              const SizedBox(height: 24),
              ...entries.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: colorScheme[shades[e.key % shades.length]]!, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.value.key, style: const TextStyle(fontSize: 14))),
                    Text(AppConstants.formatAmount(e.value.value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                  ],
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final FilterPeriod period;
  final ValueChanged<FilterPeriod> onChanged;

  const _PeriodSelector({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: FilterPeriod.values.map((p) => Expanded(
          child: GestureDetector(
            onTap: () => onChanged(p),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: period == p
                    ? Theme.of(context).colorScheme.primary.withAlpha((Theme.of(context).colorScheme.primary.a * 0.1 * 255.0).round().clamp(0, 255))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(p.displayName, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: period == p ? FontWeight.w700 : FontWeight.normal, color: period == p ? Theme.of(context).colorScheme.primary : Colors.grey.shade600)),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha((color.a * 0.06 * 255.0).round().clamp(0, 255)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha((color.a * 0.15 * 255.0).round().clamp(0, 255))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 6), Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500))]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
