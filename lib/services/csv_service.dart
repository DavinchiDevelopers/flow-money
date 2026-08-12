import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/enums.dart';
import '../models/transaction.dart';

class CsvParseResult {
  final List<Transaction> transactions;
  final int skipped;
  final List<String> errors;

  const CsvParseResult({
    required this.transactions,
    required this.skipped,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
  int get imported => transactions.length;
}

class CsvService {
  CsvService._();

  static const _header = 'date,type,category,amount,description';

  static String exportTransactions(
    List<Transaction> transactions,
    List<Category> categories,
  ) {
    final categoryById = {for (final c in categories) c.id!: c};
    final sorted = List<Transaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));

    final buffer = StringBuffer('$_header\n');
    for (final t in sorted) {
      final category = categoryById[t.categoryId];
      buffer.writeln([
        DateFormat('yyyy-MM-dd').format(t.date),
        t.type.value,
        _escape(category?.name ?? 'Unknown'),
        t.amount.toStringAsFixed(0),
        _escape(t.description),
      ].join(','));
    }
    return buffer.toString();
  }

  static CsvParseResult parseTransactions(String content, List<Category> categories) {
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      return const CsvParseResult(transactions: [], skipped: 0, errors: ['File is empty']);
    }

    final header = _parseLine(lines.first).map((c) => c.toLowerCase()).toList();
    if (!_isValidHeader(header)) {
      return const CsvParseResult(
        transactions: [],
        skipped: 0,
        errors: ['Invalid CSV header. Expected: date,type,category,amount,description'],
      );
    }

    final transactions = <Transaction>[];
    final errors = <String>[];
    var skipped = 0;

    for (var i = 1; i < lines.length; i++) {
      final row = _parseLine(lines[i]);
      if (row.length < 4) {
        skipped++;
        errors.add('Row ${i + 1}: not enough columns');
        continue;
      }

      final dateStr = row[0].trim();
      final typeStr = row[1].trim().toLowerCase();
      final categoryName = row[2].trim();
      final amountStr = row[3].trim().replaceAll(' ', '');
      final description = row.length > 4 ? row[4].trim() : '';

      final date = DateTime.tryParse(dateStr);
      if (date == null) {
        skipped++;
        errors.add('Row ${i + 1}: invalid date "$dateStr"');
        continue;
      }

      if (typeStr != 'income' && typeStr != 'expense') {
        skipped++;
        errors.add('Row ${i + 1}: type must be income or expense');
        continue;
      }

      final type = TransactionType.fromString(typeStr);
      final amount = double.tryParse(amountStr);
      if (amount == null || amount <= 0) {
        skipped++;
        errors.add('Row ${i + 1}: invalid amount');
        continue;
      }

      final category = _findCategory(categories, categoryName, type);
      if (category?.id == null) {
        skipped++;
        errors.add('Row ${i + 1}: category not found');
        continue;
      }

      transactions.add(Transaction(
        amount: amount,
        description: description.isEmpty ? category!.name : description,
        date: date,
        categoryId: category!.id!,
        type: type,
        createdAt: DateTime.now(),
      ));
    }

    return CsvParseResult(transactions: transactions, skipped: skipped, errors: errors);
  }

  static Category? _findCategory(
    List<Category> categories,
    String name,
    TransactionType type,
  ) {
    try {
      return categories.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase() && c.type == type,
      );
    } catch (_) {
      try {
        return categories.firstWhere(
          (c) => c.type == type && c.name.toLowerCase() == 'other',
        );
      } catch (_) {
        for (final c in categories) {
          if (c.type == type) return c;
        }
        return null;
      }
    }
  }

  static bool _isValidHeader(List<String> header) {
    if (header.length < 4) return false;
    return header[0] == 'date' &&
        header[1] == 'type' &&
        header[2] == 'category' &&
        header[3] == 'amount';
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static List<String> _parseLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }
}
