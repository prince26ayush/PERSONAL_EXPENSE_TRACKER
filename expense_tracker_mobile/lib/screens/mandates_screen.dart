import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/expense_provider.dart';
import '../database/database_helper.dart';

class MandatesScreen extends ConsumerWidget {
  const MandatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mandatesAsync = ref.watch(mandatesProvider);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recurring Mandates & EMIs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddMandateDialog(context, ref),
          ),
        ],
      ),
      body: mandatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (mandates) {
          if (mandates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.subscriptions_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No mandates registered.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showAddMandateDialog(context, ref),
                    child: const Text('Add Mandate'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mandates.length,
            itemBuilder: (context, index) {
              final m = mandates[index];
              final isDebited = m['status'] == 'DEBITED';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['name'] as String,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Debit: ${m['debit_day_of_month']}th • ${m['source_name']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Route: ${m['method_name']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currency.format(m['amount']),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          isDebited
                              ? const Chip(
                                  label: Text(
                                    'DEBITED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: Colors.green,
                                  visualDensity: VisualDensity.compact,
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () => _markDebited(
                                    context,
                                    ref,
                                    m['id'] as int,
                                    m['name'] as String,
                                  ),
                                  child: const Text('Mark Debited'),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _markDebited(
    BuildContext context,
    WidgetRef ref,
    int mandateId,
    String name,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    final mRes = await db.query(
      'mandates',
      where: 'id = ?',
      whereArgs: [mandateId],
    );
    final mandate = mRes.first;
    final amount = (mandate['amount'] as num).toDouble();
    final sourceId = mandate['source_account_id'] as int;
    final methodId = mandate['payment_method_id'] as int;
    final category = mandate['category'] as String;

    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance - ? WHERE id = ?',
        [amount, sourceId],
      );
      int txId = await txn.insert('transactions', {
        'type': 'EXPENSE',
        'total_amount': amount,
        'my_share_amount': amount,
        'source_account_id': sourceId,
        'payment_method_id': methodId,
        'category': category,
        'notes': 'Auto-debit mandate: $name',
      });
      await txn.update(
        'mandate_logs',
        {
          'status': 'DEBITED',
          'transaction_id': txId,
          'debited_at': DateTime.now().toIso8601String(),
        },
        where: 'mandate_id = ? AND month_year = ?',
        whereArgs: [mandateId, currentMonth],
      );
    });

    ref.invalidate(mandatesProvider);
    ref.read(dashboardProvider.notifier).refreshDashboard();
  }

  void _showAddMandateDialog(BuildContext context, WidgetRef ref) async {
    final db = await DatabaseHelper.instance.database;
    final methods = await db.query('payment_methods');
    final accounts = await db.query('accounts');

    if (!context.mounted) return;

    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: '5');
    int? methodId = methods.isNotEmpty ? methods.first['id'] as int : null;
    int? sourceId = accounts.isNotEmpty ? accounts.first['id'] as int : null;
    String category = 'Subscriptions';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Mandate / EMI'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mandate Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Debit Day of Month (1-31)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: methodId,
                  decoration: const InputDecoration(
                    labelText: 'Payment Route',
                    border: OutlineInputBorder(),
                  ),
                  items: methods
                      .map(
                        (m) => DropdownMenuItem<int>(
                          value: m['id'] as int,
                          child: Text(m['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setDialogState(() => methodId = val),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: sourceId,
                  decoration: const InputDecoration(
                    labelText: 'Funding Account',
                    border: OutlineInputBorder(),
                  ),
                  items: accounts
                      .map(
                        (a) => DropdownMenuItem<int>(
                          value: a['id'] as int,
                          child: Text(a['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setDialogState(() => sourceId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amtCtrl.text) ?? 0.0;
                final day = int.tryParse(dayCtrl.text) ?? 1;
                if (nameCtrl.text.trim().isEmpty ||
                    amt <= 0 ||
                    methodId == null ||
                    sourceId == null)
                  return;

                await db.insert('mandates', {
                  'name': nameCtrl.text.trim(),
                  'amount': amt,
                  'debit_day_of_month': day,
                  'payment_method_id': methodId,
                  'source_account_id': sourceId,
                  'category': category,
                  'is_active': 1,
                });

                ref.invalidate(mandatesProvider);
                ref.read(dashboardProvider.notifier).refreshDashboard();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save Mandate'),
            ),
          ],
        ),
      ),
    );
  }
}
