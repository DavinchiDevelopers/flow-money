import '../models/enums.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';

class RecurringService {
  RecurringService._();

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime advance(DateTime date, RecurringFrequency frequency) {
    switch (frequency) {
      case RecurringFrequency.weekly:
        return date.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        return DateTime(date.year, date.month + 1, date.day);
      case RecurringFrequency.yearly:
        return DateTime(date.year + 1, date.month, date.day);
    }
  }

  static List<Transaction> transactionsToCreate(RecurringTransaction recurring) {
    if (!recurring.isActive) return [];

    final today = dateOnly(DateTime.now());
    var next = dateOnly(recurring.nextDate);
    final created = <Transaction>[];

    while (!next.isAfter(today)) {
      created.add(Transaction(
        amount: recurring.amount,
        description: recurring.description,
        date: next,
        categoryId: recurring.categoryId,
        type: recurring.type,
        createdAt: DateTime.now(),
      ));
      next = dateOnly(advance(next, recurring.frequency));
    }
    return created;
  }

  static RecurringTransaction afterApply(RecurringTransaction recurring) {
    final today = dateOnly(DateTime.now());
    var next = dateOnly(recurring.nextDate);
    while (!next.isAfter(today)) {
      next = dateOnly(advance(next, recurring.frequency));
    }
    return recurring.copyWith(nextDate: next);
  }

  static int countDue(List<RecurringTransaction> items) {
    return items.where((r) => r.isDue).length;
  }
}
