import 'enums.dart';

class RecurringTransaction {
  final int? id;
  final double amount;
  final String description;
  final int categoryId;
  final TransactionType type;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime nextDate;
  final bool isActive;
  final DateTime createdAt;

  const RecurringTransaction({
    this.id,
    required this.amount,
    required this.description,
    required this.categoryId,
    required this.type,
    required this.frequency,
    required this.startDate,
    required this.nextDate,
    this.isActive = true,
    required this.createdAt,
  });

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String? ?? '',
      categoryId: map['category_id'] as int,
      type: TransactionType.fromString(map['type'] as String),
      frequency: RecurringFrequency.fromString(map['frequency'] as String),
      startDate: DateTime.parse(map['start_date'] as String),
      nextDate: DateTime.parse(map['next_date'] as String),
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'description': description,
      'category_id': categoryId,
      'type': type.value,
      'frequency': frequency.value,
      'start_date': startDate.toIso8601String(),
      'next_date': nextDate.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  RecurringTransaction copyWith({
    int? id,
    double? amount,
    String? description,
    int? categoryId,
    TransactionType? type,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? nextDate,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextDate: nextDate ?? this.nextDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isDue {
    if (!isActive) return false;
    final today = _dateOnly(DateTime.now());
    return !_dateOnly(nextDate).isAfter(today);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
