import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expense_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Accounts Table
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        type TEXT CHECK(type IN ('CASH', 'SAVINGS', 'CREDIT_CARD', 'CUSTOM')) NOT NULL,
        current_balance REAL NOT NULL DEFAULT 0.0,
        credit_limit REAL DEFAULT 0.0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. Payment Methods Table
    await db.execute('''
      CREATE TABLE payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        default_account_id INTEGER,
        requires_account_prompt INTEGER DEFAULT 0,
        FOREIGN KEY (default_account_id) REFERENCES accounts(id) ON DELETE RESTRICT
      )
    ''');

    // 3. Budgets Table
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        monthly_limit REAL NOT NULL,
        month_year TEXT NOT NULL,
        UNIQUE(category, month_year)
      )
    ''');

    // 4. Transactions Table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT CHECK(type IN ('EXPENSE', 'INCOME', 'TRANSFER', 'SETTLEMENT')) NOT NULL,
        total_amount REAL NOT NULL,
        my_share_amount REAL NOT NULL,
        source_account_id INTEGER,
        destination_account_id INTEGER,
        payment_method_id INTEGER,
        category TEXT,
        notes TEXT,
        transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (source_account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
        FOREIGN KEY (destination_account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE RESTRICT
      )
    ''');

    // 5. Friends Table
    await db.execute('''
      CREATE TABLE friends (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        phone TEXT,
        upi_id TEXT
      )
    ''');

    // 6. Expense Splits Table
    await db.execute('''
      CREATE TABLE expense_splits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        friend_id INTEGER NOT NULL,
        share_amount REAL NOT NULL,
        is_settled INTEGER DEFAULT 0,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
        FOREIGN KEY (friend_id) REFERENCES friends(id) ON DELETE RESTRICT
      )
    ''');

    // 7. Settlements Table
    await db.execute('''
      CREATE TABLE settlements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        friend_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        destination_account_id INTEGER NOT NULL,
        settled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (friend_id) REFERENCES friends(id) ON DELETE RESTRICT,
        FOREIGN KEY (destination_account_id) REFERENCES accounts(id) ON DELETE RESTRICT
      )
    ''');

    // 8. Mandates Table
    await db.execute('''
      CREATE TABLE mandates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        amount REAL NOT NULL,
        debit_day_of_month INTEGER NOT NULL CHECK(debit_day_of_month BETWEEN 1 AND 31),
        payment_method_id INTEGER NOT NULL,
        source_account_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        is_active INTEGER DEFAULT 1,
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id) ON DELETE RESTRICT,
        FOREIGN KEY (source_account_id) REFERENCES accounts(id) ON DELETE RESTRICT
      )
    ''');

    // 9. Mandate Logs Table
    await db.execute('''
      CREATE TABLE mandate_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mandate_id INTEGER NOT NULL,
        month_year TEXT NOT NULL,
        status TEXT CHECK(status IN ('PENDING', 'DEBITED', 'SKIPPED')) DEFAULT 'PENDING',
        transaction_id INTEGER,
        debited_at TIMESTAMP,
        UNIQUE(mandate_id, month_year),
        FOREIGN KEY (mandate_id) REFERENCES mandates(id) ON DELETE CASCADE,
        FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
      )
    ''');

    // Initial Seed of User's Actual Sources & Methods
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    final sources = [
      {'name': 'Cash Wallet', 'type': 'CASH', 'bal': 2000.0, 'limit': 0.0},
      {
        'name': 'HDFC Savings (Daily)',
        'type': 'SAVINGS',
        'bal': 10000.0,
        'limit': 0.0,
      },
      {
        'name': 'Indian Bank (EMI & Savings)',
        'type': 'SAVINGS',
        'bal': 15000.0,
        'limit': 0.0,
      },
      {
        'name': 'PNB (Personal Savings)',
        'type': 'SAVINGS',
        'bal': 25000.0,
        'limit': 0.0,
      },
      {
        'name': 'SBI Salary Account',
        'type': 'SAVINGS',
        'bal': 60000.0,
        'limit': 0.0,
      },
      {
        'name': 'IDFC Credit Card',
        'type': 'CREDIT_CARD',
        'bal': 0.0,
        'limit': 35000.0,
      },
      {
        'name': 'SBI Credit Card',
        'type': 'CREDIT_CARD',
        'bal': 0.0,
        'limit': 76000.0,
      },
    ];

    Map<String, int> accMap = {};
    for (var s in sources) {
      int id = await db.insert('accounts', {
        'name': s['name'],
        'type': s['type'],
        'current_balance': s['bal'],
        'credit_limit': s['limit'],
      });
      accMap[s['name'] as String] = id;
    }

    final methods = [
      {'name': 'Cash', 'acc_id': accMap['Cash Wallet'], 'prompt': 0},
      {
        'name': 'GPay - HDFC',
        'acc_id': accMap['HDFC Savings (Daily)'],
        'prompt': 0,
      },
      {
        'name': 'GPay - SBI - CC',
        'acc_id': accMap['SBI Credit Card'],
        'prompt': 0,
      },
      {
        'name': 'GPay - IDFC - CC',
        'acc_id': accMap['IDFC Credit Card'],
        'prompt': 0,
      },
      {
        'name': 'NetBanking / AutoDebit - Indian Bank',
        'acc_id': accMap['Indian Bank (EMI & Savings)'],
        'prompt': 0,
      },
      {
        'name': 'NetBanking - SBI Salary',
        'acc_id': accMap['SBI Salary Account'],
        'prompt': 0,
      },
      {'name': 'Debit Card', 'acc_id': null, 'prompt': 1},
    ];

    for (var m in methods) {
      await db.insert('payment_methods', {
        'name': m['name'],
        'default_account_id': m['acc_id'],
        'requires_account_prompt': m['prompt'],
      });
    }
  }

  // --- Core Atomic Business Logic Methods ---

  Future<void> logExpense({
    required double amount,
    required String category,
    required int paymentMethodId,
    int? overrideAccountId,
    String notes = '',
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Resolve funding account
      final methodRes = await txn.query(
        'payment_methods',
        where: 'id = ?',
        whereArgs: [paymentMethodId],
      );
      final method = methodRes.first;
      int sourceAccId = (method['requires_account_prompt'] == 1)
          ? overrideAccountId!
          : method['default_account_id'] as int;

      // 2. Deduct from account
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance - ? WHERE id = ?',
        [amount, sourceAccId],
      );

      // 3. Insert transaction
      await txn.insert('transactions', {
        'type': 'EXPENSE',
        'total_amount': amount,
        'my_share_amount': amount,
        'source_account_id': sourceAccId,
        'payment_method_id': paymentMethodId,
        'category': category,
        'notes': notes,
      });
    });
  }

  Future<void> logSplitExpense({
    required double totalAmount,
    required double myShare,
    required String category,
    required int paymentMethodId,
    required List<Map<String, dynamic>>
    friendSplits, // [{'friend_id': 1, 'share': 500.0}]
    int? overrideAccountId,
    String notes = '',
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final methodRes = await txn.query(
        'payment_methods',
        where: 'id = ?',
        whereArgs: [paymentMethodId],
      );
      int sourceAccId = (methodRes.first['requires_account_prompt'] == 1)
          ? overrideAccountId!
          : methodRes.first['default_account_id'] as int;

      // Deduct full amount from payer
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance - ? WHERE id = ?',
        [totalAmount, sourceAccId],
      );

      // Insert transaction with personal share
      int txId = await txn.insert('transactions', {
        'type': 'EXPENSE',
        'total_amount': totalAmount,
        'my_share_amount': myShare,
        'source_account_id': sourceAccId,
        'payment_method_id': paymentMethodId,
        'category': category,
        'notes': notes,
      });

      // Insert debt lines
      for (var f in friendSplits) {
        await txn.insert('expense_splits', {
          'transaction_id': txId,
          'friend_id': f['friend_id'],
          'share_amount': f['share'],
          'is_settled': 0,
        });
      }
    });
  }

  Future<void> settleUp({
    required int friendId,
    required double amount,
    required int destinationAccountId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // Credit destination account
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?',
        [amount, destinationAccountId],
      );

      // Insert settlement record
      await txn.insert('settlements', {
        'friend_id': friendId,
        'amount': amount,
        'destination_account_id': destinationAccountId,
      });

      // Mark debts as settled
      await txn.update(
        'expense_splits',
        {'is_settled': 1},
        where: 'friend_id = ? AND is_settled = 0',
        whereArgs: [friendId],
      );
    });
  }
}
