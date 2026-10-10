import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tick_expense_tracker_v2.db');
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

  Future<void> _createDB(Database db, int version) async {
    // 1. Accounts / Sources (Initialized at 0.00)
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL,
        current_balance REAL NOT NULL DEFAULT 0.00
      )
    ''');

    // 2. Payment Methods
    await db.execute('''
      CREATE TABLE payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
      )
    ''');

    // 3. Dynamic Categories
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        icon_name TEXT DEFAULT 'category',
        color_hex TEXT DEFAULT '0xFF6366F1'
      )
    ''');

    // 4. Budgets
    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL,
        monthly_limit REAL NOT NULL,
        month_year TEXT NOT NULL,
        UNIQUE(category_name, month_year),
        FOREIGN KEY (category_name) REFERENCES categories (name) ON UPDATE CASCADE ON DELETE CASCADE
      )
    ''');

    // 5. Transactions
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_account_id INTEGER NOT NULL,
        payment_method_id INTEGER,
        category_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        type TEXT NOT NULL DEFAULT 'EXPENSE',
        notes TEXT,
        transaction_date TEXT NOT NULL,
        FOREIGN KEY (source_account_id) REFERENCES accounts (id) ON DELETE RESTRICT,
        FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id) ON DELETE SET NULL,
        FOREIGN KEY (category_name) REFERENCES categories (name) ON UPDATE CASCADE ON DELETE RESTRICT
      )
    ''');

    // Seed default baseline sources with ₹0.00
    await db.rawInsert(
      "INSERT INTO accounts (name, type, current_balance) VALUES ('Cash Wallet', 'CASH', 0.00)",
    );
    await db.rawInsert(
      "INSERT INTO accounts (name, type, current_balance) VALUES ('Primary Bank', 'SAVINGS', 0.00)",
    );

    // Seed default payment methods linked to accounts
    await db.rawInsert(
      "INSERT INTO payment_methods (account_id, name, type) VALUES (1, 'Cash In Hand', 'CASH')",
    );
    await db.rawInsert(
      "INSERT INTO payment_methods (account_id, name, type) VALUES (2, 'UPI / GPay', 'UPI')",
    );
    await db.rawInsert(
      "INSERT INTO payment_methods (account_id, name, type) VALUES (2, 'Debit Card', 'DEBIT_CARD')",
    );

    // Seed default starter categories
    final defaultCategories = [
      'Food & Dining',
      'Groceries',
      'Fuel & Travel',
      'Bills & Utilities',
      'Entertainment',
      'Shopping',
      'Health & Medical',
      'Investments',
    ];
    for (var cat in defaultCategories) {
      await db.rawInsert("INSERT INTO categories (name) VALUES (?)", [cat]);
    }
  }

  // --- Account CRUD ---
  Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await database;
    return await db.query('accounts', orderBy: 'id ASC');
  }

  Future<int> addAccount(
    String name,
    String type,
    double initialBalance,
  ) async {
    final db = await database;
    return await db.insert('accounts', {
      'name': name,
      'type': type,
      'current_balance': initialBalance,
    });
  }

  Future<int> updateAccount(
    int id,
    String name,
    String type,
    double balance,
  ) async {
    final db = await database;
    return await db.update(
      'accounts',
      {'name': name, 'type': type, 'current_balance': balance},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;
    return await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }

  // --- Payment Method CRUD ---
  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT pm.id, pm.name, pm.type, pm.account_id, a.name AS account_name
      FROM payment_methods pm
      LEFT JOIN accounts a ON pm.account_id = a.id
      ORDER BY pm.id ASC
    ''');
  }

  Future<int> addPaymentMethod(int accountId, String name, String type) async {
    final db = await database;
    return await db.insert('payment_methods', {
      'account_id': accountId,
      'name': name,
      'type': type,
    });
  }

  Future<int> updatePaymentMethod(
    int id,
    int accountId,
    String name,
    String type,
  ) async {
    final db = await database;
    return await db.update(
      'payment_methods',
      {'account_id': accountId, 'name': name, 'type': type},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePaymentMethod(int id) async {
    final db = await database;
    return await db.delete('payment_methods', where: 'id = ?', whereArgs: [id]);
  }

  // --- Category CRUD ---
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories', orderBy: 'name ASC');
  }

  Future<int> addCategory(String name) async {
    final db = await database;
    return await db.insert('categories', {'name': name});
  }

  Future<int> updateCategory(int id, String oldName, String newName) async {
    final db = await database;
    return await db.transaction((txn) async {
      final res = await txn.update(
        'categories',
        {'name': newName},
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'budgets',
        {'category_name': newName},
        where: 'category_name = ?',
        whereArgs: [oldName],
      );
      await txn.update(
        'transactions',
        {'category_name': newName},
        where: 'category_name = ?',
        whereArgs: [oldName],
      );
      return res;
    });
  }

  Future<int> deleteCategory(int id, String categoryName) async {
    final db = await database;
    return await db.transaction((txn) async {
      await txn.delete(
        'budgets',
        where: 'category_name = ?',
        whereArgs: [categoryName],
      );
      return await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  // --- Budget CRUD ---
  Future<List<Map<String, dynamic>>> getBudgets(String monthYear) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT 
        b.id, b.category_name, b.monthly_limit,
        COALESCE(SUM(t.total_amount), 0.0) AS spent
      FROM budgets b
      LEFT JOIN transactions t 
        ON b.category_name = t.category_name 
        AND strftime('%Y-%m', t.transaction_date) = b.month_year
        AND t.type = 'EXPENSE'
      WHERE b.month_year = ?
      GROUP BY b.id, b.category_name, b.monthly_limit
    ''',
      [monthYear],
    );
  }

  Future<int> setBudget(
    String categoryName,
    double limit,
    String monthYear,
  ) async {
    final db = await database;
    return await db.rawInsert(
      '''
      INSERT INTO budgets (category_name, monthly_limit, month_year)
      VALUES (?, ?, ?)
      ON CONFLICT(category_name, month_year) 
      DO UPDATE SET monthly_limit = excluded.monthly_limit
    ''',
      [categoryName, limit, monthYear],
    );
  }

  Future<int> deleteBudget(int id) async {
    final db = await database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }
}
