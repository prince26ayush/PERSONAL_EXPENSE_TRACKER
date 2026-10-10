import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';

// --- State Data Models ---
class MasterDashboardData {
  final double totalLiquid;
  final double totalReceivable;
  final double totalLiabilities;
  final double netWorth;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> recentTransactions;
  final List<Map<String, dynamic>> budgets;
  final int pendingMandatesCount;

  MasterDashboardData({
    required this.totalLiquid,
    required this.totalReceivable,
    required this.totalLiabilities,
    required this.netWorth,
    required this.accounts,
    required this.recentTransactions,
    required this.budgets,
    required this.pendingMandatesCount,
  });
}

// --- Modern Riverpod AsyncNotifier ---
class DashboardNotifier extends AsyncNotifier<MasterDashboardData> {
  @override
  Future<MasterDashboardData> build() async {
    return _fetchDashboard();
  }

  Future<MasterDashboardData> _fetchDashboard() async {
    final db = await DatabaseHelper.instance.database;
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    // 1. Fetch Accounts
    final accounts = await db.query('accounts');
    double liquid = 0.0;
    double liabilities = 0.0;

    for (var a in accounts) {
      final bal = (a['current_balance'] as num).toDouble();
      final type = a['type'] as String;
      if (type == 'CASH' || type == 'SAVINGS' || type == 'CUSTOM') {
        liquid += bal;
      } else if (type == 'CREDIT_CARD' && bal < 0) {
        liabilities += bal.abs();
      }
    }

    // 2. Fetch Net Receivables (Friends owing you)
    final splitRes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(s.share_amount), 0.0) - COALESCE(SUM(setl.amount), 0.0) AS receivable
      FROM expense_splits s
      LEFT JOIN (
        SELECT friend_id, SUM(amount) AS amount FROM settlements GROUP BY friend_id
      ) setl ON s.friend_id = setl.friend_id
      WHERE s.is_settled = 0
    ''');
    double receivable = 0.0;
    if (splitRes.isNotEmpty && splitRes.first['receivable'] != null) {
      receivable = (splitRes.first['receivable'] as num).toDouble();
      if (receivable < 0) receivable = 0.0;
    }

    // 3. Recent Transactions
    final txs = await db.rawQuery('''
      SELECT 
        t.id, t.transaction_date, t.category, t.total_amount, t.notes,
        a.name AS source_name, pm.name AS method_name
      FROM transactions t
      LEFT JOIN accounts a ON t.source_account_id = a.id
      LEFT JOIN payment_methods pm ON t.payment_method_id = pm.id
      ORDER BY t.id DESC
      LIMIT 10
    ''');

    // 4. Budgets
    final budgets = await db.rawQuery(
      '''
      SELECT 
        b.category, b.monthly_limit,
        COALESCE(spent.total_spent, 0.0) AS spent
      FROM budgets b
      LEFT JOIN (
        SELECT category, SUM(my_share_amount) AS total_spent
        FROM transactions
        WHERE type = 'EXPENSE' AND strftime('%Y-%m', transaction_date) = ?
        GROUP BY category
      ) spent ON b.category = spent.category
      WHERE b.month_year = ?
    ''',
      [currentMonth, currentMonth],
    );

    // 5. Pending Mandates Count
    final mandatesRes = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM mandate_logs
      WHERE month_year = ? AND status = 'PENDING'
    ''',
      [currentMonth],
    );
    int pendingMandates = 0;
    if (mandatesRes.isNotEmpty) {
      pendingMandates = (mandatesRes.first['count'] as num).toInt();
    }

    return MasterDashboardData(
      totalLiquid: liquid,
      totalReceivable: receivable,
      totalLiabilities: liabilities,
      netWorth: (liquid + receivable) - liabilities,
      accounts: accounts,
      recentTransactions: txs,
      budgets: budgets,
      pendingMandatesCount: pendingMandates,
    );
  }

  Future<void> refreshDashboard() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchDashboard());
  }
}

// Global Provider Definition
final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, MasterDashboardData>(() {
      return DashboardNotifier();
    });

// Friends & Split Ledger Provider
final friendsLedgerProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await DatabaseHelper.instance.database;
  return await db.rawQuery('''
    SELECT 
      f.id, f.name, f.phone, f.upi_id,
      COALESCE(owed.total_owed, 0.0) AS total_owed,
      COALESCE(settled.total_settled, 0.0) AS total_settled,
      (COALESCE(owed.total_owed, 0.0) - COALESCE(settled.total_settled, 0.0)) AS net_balance
    FROM friends f
    LEFT JOIN (
      SELECT friend_id, SUM(share_amount) AS total_owed
      FROM expense_splits GROUP BY friend_id
    ) owed ON f.id = owed.friend_id
    LEFT JOIN (
      SELECT friend_id, SUM(amount) AS total_settled
      FROM settlements GROUP BY friend_id
    ) settled ON f.id = settled.friend_id
  ''');
});

// Active Mandates Provider
final mandatesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await DatabaseHelper.instance.database;
  final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

  // Ensure current month logs are generated
  final activeMandates = await db.query('mandates', where: 'is_active = 1');
  for (var m in activeMandates) {
    await db.rawInsert(
      '''
      INSERT OR IGNORE INTO mandate_logs (mandate_id, month_year, status)
      VALUES (?, ?, 'PENDING')
    ''',
      [m['id'], currentMonth],
    );
  }

  return await db.rawQuery(
    '''
    SELECT 
      m.id, m.name, m.amount, m.debit_day_of_month, m.category,
      a.name AS source_name, pm.name AS method_name,
      COALESCE(ml.status, 'PENDING') AS status
    FROM mandates m
    LEFT JOIN accounts a ON m.source_account_id = a.id
    LEFT JOIN payment_methods pm ON m.payment_method_id = pm.id
    LEFT JOIN mandate_logs ml ON m.id = ml.mandate_id AND ml.month_year = ?
    WHERE m.is_active = 1
  ''',
    [currentMonth],
  );
});
