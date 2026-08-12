import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/category.dart';
import '../models/transaction.dart' as app;
import '../models/enums.dart';
import '../models/user_profile.dart';
import '../models/recurring_transaction.dart';
import '../services/recurring_service.dart';
import '../utils/constants.dart';
import 'database_interface.dart';

class DatabaseService implements DatabaseInterface {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _createTables,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        is_default INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL CHECK(amount > 0),
        description TEXT DEFAULT '',
        date TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        currency TEXT DEFAULT 'KZT',
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(type)');
    await db.execute('CREATE INDEX idx_transactions_category ON transactions(category_id)');

    await db.execute('''
      CREATE TABLE recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL CHECK(amount > 0),
        description TEXT DEFAULT '',
        category_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
        frequency TEXT NOT NULL CHECK(frequency IN ('weekly', 'monthly', 'yearly')),
        start_date TEXT NOT NULL,
        next_date TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    final batch = db.batch();
    for (final category in DefaultCategories.all) {
      batch.insert('categories', category.toMap());
    }
    await batch.commit();
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE user_profile_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          currency TEXT DEFAULT 'KZT',
          created_at TEXT NOT NULL,
          updated_at TEXT
        )
      ''');
      await db.execute('''
        INSERT INTO user_profile_new (id, name, currency, created_at, updated_at)
        SELECT id, name, currency, created_at, updated_at FROM user_profile
      ''');
      await db.execute('DROP TABLE user_profile');
      await db.execute('ALTER TABLE user_profile_new RENAME TO user_profile');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE recurring_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL CHECK(amount > 0),
          description TEXT DEFAULT '',
          category_id INTEGER NOT NULL,
          type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
          frequency TEXT NOT NULL CHECK(frequency IN ('weekly', 'monthly', 'yearly')),
          start_date TEXT NOT NULL,
          next_date TEXT NOT NULL,
          is_active INTEGER DEFAULT 1,
          created_at TEXT NOT NULL,
          FOREIGN KEY (category_id) REFERENCES categories (id)
        )
      ''');
    }
  }

  @override
  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'name');
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  @override
  Future<List<Category>> getCategoriesByType(TransactionType type) async {
    final db = await database;
    final maps = await db.query('categories', where: 'type = ?', whereArgs: [type.value], orderBy: 'name');
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  @override
  Future<int> insertTransaction(app.Transaction transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  @override
  Future<List<app.Transaction>> getTransactions({int? limit, String? orderBy = 'date DESC'}) async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: orderBy, limit: limit);
    return maps.map((map) => app.Transaction.fromMap(map)).toList();
  }

  @override
  Future<int> updateTransaction(app.Transaction transaction) async {
    final db = await database;
    return await db.update('transactions', transaction.toMap(), where: 'id = ?', whereArgs: [transaction.id]);
  }

  @override
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<double> getTotalBalance() async {
    final db = await database;
    final incomeResult = await db.rawQuery("SELECT SUM(amount) as total FROM transactions WHERE type = 'income'");
    final totalIncome = (incomeResult.first['total'] as double?) ?? 0.0;
    final expenseResult = await db.rawQuery("SELECT SUM(amount) as total FROM transactions WHERE type = 'expense'");
    final totalExpense = (expenseResult.first['total'] as double?) ?? 0.0;
    return totalIncome - totalExpense;
  }

  @override
  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    final maps = await db.query('user_profile', limit: 1);
    if (maps.isEmpty) return null;
    return UserProfile.fromMap(maps.first);
  }

  @override
  Future<int> saveUserProfile(UserProfile profile) async {
    final db = await database;
    final existing = await getUserProfile();
    if (existing != null) {
      return await db.update('user_profile', profile.copyWith(id: existing.id).toMap(), where: 'id = ?', whereArgs: [existing.id]);
    } else {
      return await db.insert('user_profile', profile.toMap());
    }
  }

  @override
  Future<int> importTransactions(List<app.Transaction> transactions) async {
    if (transactions.isEmpty) return 0;
    final db = await database;
    final batch = db.batch();
    for (final t in transactions) {
      batch.insert('transactions', t.toMap());
    }
    final results = await batch.commit(noResult: false);
    return results.length;
  }

  @override
  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    final db = await database;
    final maps = await db.query('recurring_transactions', orderBy: 'next_date ASC');
    return maps.map((m) => RecurringTransaction.fromMap(m)).toList();
  }

  @override
  Future<int> insertRecurringTransaction(RecurringTransaction recurring) async {
    final db = await database;
    return await db.insert('recurring_transactions', recurring.toMap());
  }

  @override
  Future<int> updateRecurringTransaction(RecurringTransaction recurring) async {
    final db = await database;
    return await db.update(
      'recurring_transactions',
      recurring.toMap(),
      where: 'id = ?',
      whereArgs: [recurring.id],
    );
  }

  @override
  Future<int> deleteRecurringTransaction(int id) async {
    final db = await database;
    return await db.delete('recurring_transactions', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> applyDueRecurring() async {
    final recurring = await getRecurringTransactions();
    var created = 0;

    for (final item in recurring) {
      if (!item.isActive || item.id == null) continue;
      final txs = RecurringService.transactionsToCreate(item);
      if (txs.isEmpty) continue;

      for (final t in txs) {
        await insertTransaction(t);
        created++;
      }
      await updateRecurringTransaction(RecurringService.afterApply(item));
    }
    return created;
  }

  @override
  Future<void> resetAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('recurring_transactions');
    await db.delete('user_profile');
    await db.delete('categories', where: 'is_default = ?', whereArgs: [0]);
  }
}
