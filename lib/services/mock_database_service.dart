import '../models/category.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart' as app;
import '../models/enums.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';
import 'database_interface.dart';
import 'recurring_service.dart';

class MockDatabaseService implements DatabaseInterface {
  static final MockDatabaseService _instance = MockDatabaseService._internal();
  factory MockDatabaseService() => _instance;
  MockDatabaseService._internal();

  final List<Category> _categories = [];
  final List<app.Transaction> _transactions = [];
  final List<RecurringTransaction> _recurring = [];
  UserProfile? _userProfile;
  bool _initialized = false;

  Future<void> _init() async {
    if (_initialized) return;
    int id = 1;
    for (final cat in DefaultCategories.all) {
      _categories.add(cat.copyWith(id: id++));
    }
    _initialized = true;
  }

  @override
  Future<List<Category>> getCategories() async {
    await _init();
    return List.from(_categories);
  }

  @override
  Future<List<Category>> getCategoriesByType(TransactionType type) async {
    await _init();
    return _categories.where((c) => c.type == type).toList();
  }

  @override
  Future<int> insertTransaction(app.Transaction transaction) async {
    await _init();
    final id = _transactions.length + 1;
    _transactions.add(transaction.copyWith(id: id));
    return id;
  }

  @override
  Future<List<app.Transaction>> getTransactions({int? limit, String? orderBy = 'date DESC'}) async {
    await _init();
    final sorted = List<app.Transaction>.from(_transactions)..sort((a, b) => b.date.compareTo(a.date));
    if (limit != null && limit > 0) return sorted.take(limit).toList();
    return sorted;
  }

  @override
  Future<int> updateTransaction(app.Transaction transaction) async {
    await _init();
    final idx = _transactions.indexWhere((t) => t.id == transaction.id);
    if (idx != -1) {
      _transactions[idx] = transaction;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteTransaction(int id) async {
    await _init();
    final idx = _transactions.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _transactions.removeAt(idx);
      return 1;
    }
    return 0;
  }

  @override
  Future<double> getTotalBalance() async {
    await _init();
    double inc = 0, exp = 0;
    for (final t in _transactions) {
      if (t.type == TransactionType.income) {
        inc += t.amount;
      } else {
        exp += t.amount;
      }
    }
    return inc - exp;
  }

  @override
  Future<UserProfile?> getUserProfile() async {
    await _init();
    return _userProfile;
  }

  @override
  Future<int> saveUserProfile(UserProfile profile) async {
    await _init();
    _userProfile = profile.copyWith(id: 1);
    return 1;
  }

  @override
  Future<int> importTransactions(List<app.Transaction> transactions) async {
    await _init();
    var count = 0;
    for (final t in transactions) {
      final id = _transactions.length + 1;
      _transactions.add(t.copyWith(id: id));
      count++;
    }
    return count;
  }

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    await _init();
    final sorted = List<RecurringTransaction>.from(_recurring)
      ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
    return sorted;
  }

  @override
  Future<int> insertRecurringTransaction(RecurringTransaction recurring) async {
    await _init();
    final id = _recurring.length + 1;
    _recurring.add(recurring.copyWith(id: id));
    return id;
  }

  @override
  Future<int> updateRecurringTransaction(RecurringTransaction recurring) async {
    await _init();
    final idx = _recurring.indexWhere((r) => r.id == recurring.id);
    if (idx != -1) {
      _recurring[idx] = recurring;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteRecurringTransaction(int id) async {
    await _init();
    final idx = _recurring.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _recurring.removeAt(idx);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> applyDueRecurring() async {
    await _init();
    var created = 0;
    for (var i = 0; i < _recurring.length; i++) {
      final item = _recurring[i];
      if (!item.isActive) continue;
      final txs = RecurringService.transactionsToCreate(item);
      if (txs.isEmpty) continue;
      for (final t in txs) {
        await insertTransaction(t);
        created++;
      }
      _recurring[i] = RecurringService.afterApply(item);
    }
    return created;
  }

  @override
  Future<void> resetAllData() async {
    _transactions.clear();
    _recurring.clear();
    _userProfile = null;
  }
}
