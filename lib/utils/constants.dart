import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/enums.dart';

class AppConstants {
  AppConstants._();

  static const double minAmount = 1.0;
  static const double maxAmount = 99999999.0;
  static const int maxDescriptionLength = 100;
  static final DateTime minDate = DateTime(2020, 1, 1);
  static DateTime get maxDate => DateTime.now().add(const Duration(days: 1));

  static const String currency = '\u{20B8}';
  static const String currencyCode = 'KZT';

  static const String dbName = 'budget_app.db';
  static const int dbVersion = 3;

  static const Map<String, IconData> iconMap = {
    'restaurant': Icons.restaurant,
    'directions_bus': Icons.directions_bus,
    'home': Icons.home,
    'checkroom': Icons.checkroom,
    'local_hospital': Icons.local_hospital,
    'sports_esports': Icons.sports_esports,
    'school': Icons.school,
    'more_horiz': Icons.more_horiz,
    'payments': Icons.payments,
    'work': Icons.work,
    'card_giftcard': Icons.card_giftcard,
    'account_balance': Icons.account_balance,
  };

  static IconData iconFor(String name) => iconMap[name] ?? Icons.category;

  static String formatAmount(double amount) {
    final abs = amount.abs().toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < abs.length; i++) {
      if (i > 0 && (abs.length - i) % 3 == 0) buf.write(' ');
      buf.write(abs[i]);
    }
    return '$buf $currency';
  }

  static String formatAmountSigned(double amount, TransactionType type) {
    final sign = type == TransactionType.income ? '+' : '-';
    return '$sign${formatAmount(amount)}';
  }
}

class DefaultCategories {
  DefaultCategories._();

  static List<Category> get expense => [
    _cat('Food & Groceries', 'restaurant', '#FF6B6B', TransactionType.expense),
    _cat('Transport', 'directions_bus', '#4ECDC4', TransactionType.expense),
    _cat('Housing & Rent', 'home', '#45B7D1', TransactionType.expense),
    _cat('Clothing', 'checkroom', '#96CEB4', TransactionType.expense),
    _cat('Health', 'local_hospital', '#FFEAA7', TransactionType.expense),
    _cat('Entertainment', 'sports_esports', '#DDA0DD', TransactionType.expense),
    _cat('Education', 'school', '#FD79A8', TransactionType.expense),
    _cat('Other', 'more_horiz', '#A8A8A8', TransactionType.expense),
  ];

  static List<Category> get income => [
    _cat('Salary', 'payments', '#00B894', TransactionType.income),
    _cat('Side Job', 'work', '#00CEC9', TransactionType.income),
    _cat('Gifts', 'card_giftcard', '#E17055', TransactionType.income),
    _cat('Social Payments', 'account_balance', '#74B9FF', TransactionType.income),
    _cat('Other', 'more_horiz', '#81ECEC', TransactionType.income),
  ];

  static List<Category> get all => [...expense, ...income];

  static Category _cat(String name, String icon, String color, TransactionType type) {
    return Category(name: name, icon: icon, colorHex: color, type: type, createdAt: DateTime.now());
  }
}
