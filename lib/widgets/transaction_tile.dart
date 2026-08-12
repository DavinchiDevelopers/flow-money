import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/enums.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.category,
    this.onTap,
    this.onDelete,
  });

  Color get _categoryColor {
    if (category == null) return Colors.grey;
    return Color(int.parse('0xFF${category!.colorHex.substring(1)}'));
  }

  String get _timeLabel {
    final now = DateTime.now();
    final d = transaction.date;
    if (DateFormat('yyyy-MM-dd').format(d) == DateFormat('yyyy-MM-dd').format(now)) {
      return 'Today, ${DateFormat('HH:mm').format(d)}';
    }
    if (now.difference(d).inDays == 1) {
      return 'Yesterday, ${DateFormat('HH:mm').format(d)}';
    }
    return DateFormat('MMM d, yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor;
    final isIncome = transaction.type == TransactionType.income;

    return Dismissible(
      key: Key('tx_${transaction.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Transaction'),
            content: const Text('Are you sure you want to delete this transaction?'),
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
        if (confirmed == true) onDelete?.call();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
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
                      transaction.description.isNotEmpty ? transaction.description : category?.name ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(_timeLabel, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
              Text(
                AppConstants.formatAmountSigned(transaction.amount, transaction.type),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isIncome ? AppTheme.incomeColor : AppTheme.expenseColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
