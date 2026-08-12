enum TransactionType {
  income('income', 'Income'),
  expense('expense', 'Expense');

  const TransactionType(this.value, this.displayName);

  final String value;
  final String displayName;

  static TransactionType fromString(String value) {
    return TransactionType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TransactionType.expense,
    );
  }
}

enum FilterPeriod {
  week('week', 'Week'),
  month('month', 'Month'),
  year('year', 'Year'),
  all('all', 'All Time');

  const FilterPeriod(this.value, this.displayName);

  final String value;
  final String displayName;
}

enum RecurringFrequency {
  weekly('weekly', 'Weekly'),
  monthly('monthly', 'Monthly'),
  yearly('yearly', 'Yearly');

  const RecurringFrequency(this.value, this.displayName);

  final String value;
  final String displayName;

  static RecurringFrequency fromString(String value) {
    return RecurringFrequency.values.firstWhere(
      (f) => f.value == value,
      orElse: () => RecurringFrequency.monthly,
    );
  }
}
