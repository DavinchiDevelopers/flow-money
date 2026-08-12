import '../models/category.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/enums.dart';
import '../models/user_profile.dart';

abstract class DatabaseInterface {
  Future<List<Category>> getCategories();
  Future<List<Category>> getCategoriesByType(TransactionType type);
  Future<int> insertTransaction(Transaction transaction);
  Future<List<Transaction>> getTransactions({int? limit, String? orderBy});
  Future<int> updateTransaction(Transaction transaction);
  Future<int> deleteTransaction(int id);
  Future<double> getTotalBalance();
  Future<UserProfile?> getUserProfile();
  Future<int> saveUserProfile(UserProfile profile);
  Future<int> importTransactions(List<Transaction> transactions);
  Future<List<RecurringTransaction>> getRecurringTransactions();
  Future<int> insertRecurringTransaction(RecurringTransaction recurring);
  Future<int> updateRecurringTransaction(RecurringTransaction recurring);
  Future<int> deleteRecurringTransaction(int id);
  Future<int> applyDueRecurring();
  Future<void> resetAllData();
}
