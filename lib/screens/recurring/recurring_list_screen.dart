import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/category.dart';
import '../../models/recurring_transaction.dart';
import '../../models/enums.dart';
import '../../services/database_interface.dart';
import '../../services/database_service.dart';
import '../../services/mock_database_service.dart';
import '../../services/recurring_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../widgets/empty_state.dart';
import 'add_recurring_screen.dart';

class RecurringListScreen extends StatefulWidget {
  const RecurringListScreen({super.key});

  @override
  State<RecurringListScreen> createState() => _RecurringListScreenState();
}

class _RecurringListScreenState extends State<RecurringListScreen> {
  late final DatabaseInterface _db;
  List<RecurringTransaction> _items = [];
  List<Category> _categories = [];
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
        _db.getRecurringTransactions(),
        _db.getCategories(),
      ]);
      setState(() {
        _items = results[0] as List<RecurringTransaction>;
        _categories = results[1] as List<Category>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Category? _catFor(int id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to apply recurring transactions')),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _toggleActive(RecurringTransaction item) async {
    await _db.updateRecurringTransaction(item.copyWith(isActive: !item.isActive));
    _load();
  }

  Future<void> _delete(RecurringTransaction item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recurring?'),
        content: const Text('This will not remove past transactions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || item.id == null) return;
    await _db.deleteRecurringTransaction(item.id!);
    _load();
  }

  Future<void> _edit(RecurringTransaction item) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddRecurringScreen(recurring: item)),
    );
    if (result == true) _load();
  }

  Future<void> _add() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddRecurringScreen()),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final dueCount = RecurringService.countDue(_items);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (dueCount > 0)
            TextButton(
              onPressed: _applying ? null : _applyDue,
              child: _applying
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Apply ($dueCount)'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? EmptyState(
                  icon: Icons.repeat_rounded,
                  title: 'No recurring transactions',
                  subtitle: 'Set up salary, rent, or subscriptions',
                  actionLabel: 'Add Recurring',
                  onAction: _add,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    return _RecurringTile(
                      item: item,
                      category: _catFor(item.categoryId),
                      onTap: () => _edit(item),
                      onToggle: () => _toggleActive(item),
                      onDelete: () => _delete(item),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecurringTile extends StatelessWidget {
  final RecurringTransaction item;
  final Category? category;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RecurringTile({
    required this.item,
    required this.category,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = category != null
        ? Color(int.parse('0xFF${category!.colorHex.substring(1)}'))
        : Colors.grey;
    final isIncome = item.type == TransactionType.income;
    final amountColor = isIncome ? AppTheme.incomeColor : AppTheme.expenseColor;

    return Dismissible(
      key: Key('recurring_${item.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isDue ? Theme.of(context).colorScheme.primary : Colors.grey.shade200,
              width: item.isDue ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withAlpha((color.a * 0.12 * 255.0).round().clamp(0, 255)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(AppConstants.iconFor(category?.icon ?? 'more_horiz'), color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description.isNotEmpty ? item.description : category?.name ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: item.isActive ? null : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.frequency.displayName} · Next ${DateFormat('MMM d').format(item.nextDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (item.isDue)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Ready to apply',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppConstants.formatAmountSigned(item.amount, item.type),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: amountColor),
                  ),
                  Switch(
                    value: item.isActive,
                    onChanged: (_) => onToggle(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
