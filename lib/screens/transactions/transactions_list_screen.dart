import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/enums.dart';
import '../../models/category.dart';
import '../../models/transaction.dart';
import '../../services/database_interface.dart';
import '../../services/database_service.dart';
import '../../services/mock_database_service.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/empty_state.dart';
import 'add_transaction_screen.dart';

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  late final DatabaseInterface _db;
  List<Transaction> _all = [];
  List<Category> _categories = [];
  bool _loading = true;
  TransactionType? _typeFilter;
  FilterPeriod _period = FilterPeriod.all;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _db = kIsWeb ? MockDatabaseService() : DatabaseService();
    _load();
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_db.getTransactions(), _db.getCategories()]);
      setState(() { _all = results[0] as List<Transaction>; _categories = results[1] as List<Category>; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Category? _catFor(int id) {
    try { return _categories.firstWhere((c) => c.id == id); } catch (_) { return null; }
  }

  List<Transaction> get _filtered {
    var list = List<Transaction>.from(_all);
    if (_typeFilter != null) list = list.where((t) => t.type == _typeFilter).toList();
    if (_query.isNotEmpty) list = list.where((t) => t.description.toLowerCase().contains(_query.toLowerCase())).toList();
    final now = DateTime.now();
    list = switch (_period) {
      FilterPeriod.week => list.where((t) => t.date.isAfter(now.subtract(const Duration(days: 7)))).toList(),
      FilterPeriod.month => list.where((t) => t.date.isAfter(DateTime(now.year, now.month - 1, now.day))).toList(),
      FilterPeriod.year => list.where((t) => t.date.isAfter(DateTime(now.year - 1, now.month, now.day))).toList(),
      FilterPeriod.all => list,
    };
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Map<String, List<Transaction>> get _grouped {
    final map = <String, List<Transaction>>{};
    for (final t in _filtered) {
      final key = DateFormat('yyyy-MM-dd').format(t.date);
      (map[key] ??= []).add(t);
    }
    return map;
  }

  Future<void> _edit(Transaction t) async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AddTransactionScreen(transaction: t)));
    if (r == true) _load();
  }

  Future<void> _delete(Transaction t) async {
    await _db.deleteTransaction(t.id!);
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Transaction deleted'),
        action: SnackBarAction(label: 'Undo', onPressed: () async { await _db.insertTransaction(t); _load(); }),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () async {
            final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
            if (r == true) _load();
          }),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _Filters(
                  searchCtrl: _searchCtrl,
                  query: _query,
                  period: _period,
                  typeFilter: _typeFilter,
                  onQueryChanged: (v) => setState(() => _query = v),
                  onPeriodChanged: (p) => setState(() => _period = p),
                  onTypeChanged: (t) => setState(() => _typeFilter = t),
                  onClear: () => setState(() { _typeFilter = null; _period = FilterPeriod.all; _query = ''; _searchCtrl.clear(); }),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: _all.isEmpty ? 'No transactions yet' : 'No matches',
                          subtitle: _all.isEmpty ? 'Add your first transaction' : 'Try different filters',
                          actionLabel: _all.isEmpty ? 'Add Transaction' : 'Clear Filters',
                          onAction: _all.isEmpty ? () async {
                            final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
                            if (r == true) _load();
                          } : () => setState(() { _typeFilter = null; _period = FilterPeriod.all; _query = ''; _searchCtrl.clear(); }),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          itemCount: dates.length,
                          itemBuilder: (_, i) {
                            final key = dates[i];
                            final txs = grouped[key]!;
                            final date = DateTime.parse(key);
                            return _DayGroup(date: date, transactions: txs, catFor: _catFor, onEdit: _edit, onDelete: _delete);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _Filters extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String query;
  final FilterPeriod period;
  final TransactionType? typeFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<FilterPeriod> onPeriodChanged;
  final ValueChanged<TransactionType?> onTypeChanged;
  final VoidCallback onClear;

  const _Filters({
    required this.searchCtrl, required this.query, required this.period,
    required this.typeFilter, required this.onQueryChanged, required this.onPeriodChanged,
    required this.onTypeChanged, required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search transactions...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: query.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { searchCtrl.clear(); onQueryChanged(''); }) : null,
              isDense: true,
            ),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...FilterPeriod.values.map((p) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _Chip(label: p.displayName, selected: period == p, onTap: () => onPeriodChanged(p)),
                )),
                const SizedBox(width: 8),
                _Chip(label: 'All', selected: typeFilter == null, onTap: () => onTypeChanged(null)),
                const SizedBox(width: 6),
                _Chip(label: 'Income', selected: typeFilter == TransactionType.income, color: const Color(0xFF00B894), onTap: () => onTypeChanged(TransactionType.income)),
                const SizedBox(width: 6),
                _Chip(label: 'Expense', selected: typeFilter == TransactionType.expense, color: const Color(0xFFFF6B6B), onTap: () => onTypeChanged(TransactionType.expense)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c.withAlpha((c.a * 0.12 * 255.0).round().clamp(0, 255)) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c.withAlpha((c.a * 0.4 * 255.0).round().clamp(0, 255)) : Colors.grey.shade200),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, color: selected ? c : Colors.grey.shade600)),
      ),
    );
  }
}

class _DayGroup extends StatelessWidget {
  final DateTime date;
  final List<Transaction> transactions;
  final Category? Function(int) catFor;
  final void Function(Transaction) onEdit;
  final void Function(Transaction) onDelete;

  const _DayGroup({required this.date, required this.transactions, required this.catFor, required this.onEdit, required this.onDelete});

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(_label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
        ),
        ...transactions.map((t) => TransactionTile(
          transaction: t,
          category: catFor(t.categoryId),
          onTap: () => onEdit(t),
          onDelete: () => onDelete(t),
        )),
      ],
    );
  }
}
