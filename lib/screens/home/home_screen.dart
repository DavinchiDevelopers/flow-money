import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../models/category.dart';
import '../../models/recurring_transaction.dart';
import '../../services/database_interface.dart';
import '../../services/database_service.dart';
import '../../services/mock_database_service.dart';
import '../../services/recurring_service.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/empty_state.dart';
import '../transactions/add_transaction_screen.dart';
import '../transactions/transactions_list_screen.dart';
import '../statistics/statistics_screen.dart';
import '../settings/settings_screen.dart';
import '../recurring/recurring_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DatabaseInterface _db;
  double _balance = 0;
  List<Transaction> _recent = [];
  List<Category> _categories = [];
  int _dueRecurring = 0;
  bool _loading = true;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _db = kIsWeb ? MockDatabaseService() : DatabaseService();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.getTotalBalance(),
        _db.getTransactions(limit: 5),
        _db.getCategories(),
        _db.getRecurringTransactions(),
      ]);
      final recurring = results[3] as List<RecurringTransaction>;
      setState(() {
        _balance = results[0] as double;
        _recent = results[1] as List<Transaction>;
        _categories = results[2] as List<Category>;
        _dueRecurring = RecurringService.countDue(recurring);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Category? _categoryFor(int id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  Future<void> _addTransaction() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _editTransaction(Transaction t) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddTransactionScreen(transaction: t)),
    );
    if (result == true) _load();
  }

  Future<void> _deleteTransaction(Transaction t) async {
    await _db.deleteTransaction(t.id!);
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _db.insertTransaction(t);
              _load();
            },
          ),
        ),
      );
    }
  }

  Future<void> _applyDue() async {
    setState(() => _applying = true);
    try {
      final count = await _db.applyDueRecurring();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(count > 0 ? 'Applied $count transaction(s)' : 'Nothing to apply')),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FlowMoney', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => _push(const StatisticsScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _push(const SettingsScreen()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
                  BalanceCard(balance: _balance),
                  if (_dueRecurring > 0) ...[
                    const SizedBox(height: 16),
                    _DueBanner(
                      count: _dueRecurring,
                      applying: _applying,
                      onApply: _applyDue,
                      onViewAll: () => _push(const RecurringListScreen()),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _QuickActions(
                    onAddTransaction: _addTransaction,
                    onAllTransactions: () => _push(const TransactionsListScreen()),
                    onRecurring: () => _push(const RecurringListScreen()),
                    onStatistics: () => _push(const StatisticsScreen()),
                  ),
                  const SizedBox(height: 28),
                  _RecentSection(
                    transactions: _recent,
                    categoryFor: _categoryFor,
                    onEdit: _editTransaction,
                    onDelete: _deleteTransaction,
                    onViewAll: () => _push(const TransactionsListScreen()),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTransaction,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DueBanner extends StatelessWidget {
  final int count;
  final bool applying;
  final VoidCallback onApply;
  final VoidCallback onViewAll;

  const _DueBanner({
    required this.count,
    required this.applying,
    required this.onApply,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withAlpha((cs.primary.a * 0.08 * 255.0).round().clamp(0, 255)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withAlpha((cs.primary.a * 0.2 * 255.0).round().clamp(0, 255))),
      ),
      child: Row(
        children: [
          Icon(Icons.repeat_rounded, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count recurring ready',
                  style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary),
                ),
                Text(
                  'Tap Apply to add them to your balance',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onViewAll, child: const Text('View')),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: applying ? null : onApply,
            child: applying
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onAddTransaction;
  final VoidCallback onAllTransactions;
  final VoidCallback onRecurring;
  final VoidCallback onStatistics;

  const _QuickActions({
    required this.onAddTransaction,
    required this.onAllTransactions,
    required this.onRecurring,
    required this.onStatistics,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            _ActionButton(icon: Icons.add_circle_outline, label: 'Add', color: cs.primary, onTap: onAddTransaction),
            const SizedBox(width: 12),
            _ActionButton(icon: Icons.receipt_long_outlined, label: 'History', color: cs.tertiary, onTap: onAllTransactions),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _ActionButton(icon: Icons.repeat_rounded, label: 'Recurring', color: cs.secondary, onTap: onRecurring),
            const SizedBox(width: 12),
            _ActionButton(icon: Icons.bar_chart_rounded, label: 'Stats', color: Colors.teal, onTap: onStatistics),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withAlpha((color.a * 0.08 * 255.0).round().clamp(0, 255)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha((color.a * 0.15 * 255.0).round().clamp(0, 255))),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSection extends StatelessWidget {
  final List<Transaction> transactions;
  final Category? Function(int) categoryFor;
  final void Function(Transaction) onEdit;
  final void Function(Transaction) onDelete;
  final VoidCallback onViewAll;

  const _RecentSection({
    required this.transactions,
    required this.categoryFor,
    required this.onEdit,
    required this.onDelete,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (transactions.isNotEmpty)
              TextButton(onPressed: onViewAll, child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions yet',
            subtitle: 'Tap + to add your first transaction',
          )
        else
          ...transactions.map((t) => TransactionTile(
            transaction: t,
            category: categoryFor(t.categoryId),
            onTap: () => onEdit(t),
            onDelete: () => onDelete(t),
          )),
      ],
    );
  }
}
