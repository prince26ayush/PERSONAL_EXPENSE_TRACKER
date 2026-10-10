import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_helper.dart';

// --- State Models ---
class TickState {
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> paymentMethods;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> budgets;
  final double netWorth;
  final bool isLoading;

  TickState({
    this.accounts = const [],
    this.paymentMethods = const [],
    this.categories = const [],
    this.budgets = const [],
    this.netWorth = 0.0,
    this.isLoading = false,
  });

  TickState copyWith({
    List<Map<String, dynamic>>? accounts,
    List<Map<String, dynamic>>? paymentMethods,
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? budgets,
    double? netWorth,
    bool? isLoading,
  }) {
    return TickState(
      accounts: accounts ?? this.accounts,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      categories: categories ?? this.categories,
      budgets: budgets ?? this.budgets,
      netWorth: netWorth ?? this.netWorth,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// --- Notifier ---
class TickNotifier extends AsyncNotifier<TickState> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  @override
  Future<TickState> build() async {
    return await _fetchFullState();
  }

  Future<TickState> _fetchFullState() async {
    final now = DateTime.now();
    final monthYear = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    final accounts = await _db.getAccounts();
    final paymentMethods = await _db.getPaymentMethods();
    final categories = await _db.getCategories();
    final budgets = await _db.getBudgets(monthYear);

    double total = 0.0;
    for (var acc in accounts) {
      total += (acc['current_balance'] as num).toDouble();
    }

    return TickState(
      accounts: accounts,
      paymentMethods: paymentMethods,
      categories: categories,
      budgets: budgets,
      netWorth: total,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchFullState());
  }

  // Account Operations
  Future<void> addAccount(String name, String type, double balance) async {
    await _db.addAccount(name, type, balance);
    await refresh();
  }

  Future<void> updateAccount(
    int id,
    String name,
    String type,
    double balance,
  ) async {
    await _db.updateAccount(id, name, type, balance);
    await refresh();
  }

  Future<void> deleteAccount(int id) async {
    await _db.deleteAccount(id);
    await refresh();
  }

  // Payment Method Operations
  Future<void> addPaymentMethod(int accountId, String name, String type) async {
    await _db.addPaymentMethod(accountId, name, type);
    await refresh();
  }

  Future<void> updatePaymentMethod(
    int id,
    int accountId,
    String name,
    String type,
  ) async {
    await _db.updatePaymentMethod(id, accountId, name, type);
    await refresh();
  }

  Future<void> deletePaymentMethod(int id) async {
    await _db.deletePaymentMethod(id);
    await refresh();
  }

  // Category Operations
  Future<void> addCategory(String name) async {
    await _db.addCategory(name);
    await refresh();
  }

  Future<void> updateCategory(int id, String oldName, String newName) async {
    await _db.updateCategory(id, oldName, newName);
    await refresh();
  }

  Future<void> deleteCategory(int id, String name) async {
    await _db.deleteCategory(id, name);
    await refresh();
  }

  // Budget Operations
  Future<void> setBudget(String categoryName, double limit) async {
    final now = DateTime.now();
    final monthYear = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    await _db.setBudget(categoryName, limit, monthYear);
    await refresh();
  }

  Future<void> deleteBudget(int id) async {
    await _db.deleteBudget(id);
    await refresh();
  }
}

final tickProvider = AsyncNotifierProvider<TickNotifier, TickState>(() {
  return TickNotifier();
});
