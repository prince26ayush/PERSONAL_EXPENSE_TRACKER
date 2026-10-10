import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/expense_provider.dart';
import '../database/database_helper.dart';

class SplitLedgerScreen extends ConsumerWidget {
  const SplitLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(friendsLedgerProvider);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Split Balances & Settle Up',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showAddFriendDialog(context, ref),
          ),
        ],
      ),
      body: ledgerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (friends) {
          if (friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No friends added yet.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showAddFriendDialog(context, ref),
                    child: const Text('Add Friend'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final f = friends[index];
              final net = (f['net_balance'] as num).toDouble();
              final isPositive = net > 0;
              final isSettled = net == 0;

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
                            f['name'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'UPI: ${f['upi_id'] ?? 'Not set'}',
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
                            isSettled
                                ? 'All Settled'
                                : (isPositive
                                      ? '+${currency.format(net)}'
                                      : currency.format(net)),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSettled
                                  ? Colors.grey
                                  : (isPositive ? Colors.green : Colors.red),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (!isSettled)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => _showSettleUpDialog(
                                context,
                                ref,
                                f['id'] as int,
                                f['name'] as String,
                                net,
                              ),
                              child: const Text('Settle Up'),
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

  void _showAddFriendDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final upiCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Friend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: upiCtrl,
              decoration: const InputDecoration(
                labelText: 'UPI ID (e.g. name@okhdfcbank)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final db = await DatabaseHelper.instance.database;
              await db.insert('friends', {
                'name': nameCtrl.text.trim(),
                'upi_id': upiCtrl.text.trim(),
              });
              ref.invalidate(friendsLedgerProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSettleUpDialog(
    BuildContext context,
    WidgetRef ref,
    int friendId,
    String name,
    double currentDue,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final accounts = await db.query(
      'accounts',
      where: "type IN ('SAVINGS', 'CASH')",
    );
    int? selectedDestAccId = accounts.isNotEmpty
        ? accounts.first['id'] as int
        : null;
    final amountCtrl = TextEditingController(
      text: currentDue.toStringAsFixed(2),
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Settle Up with $name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Received Amount (₹)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: selectedDestAccId,
                decoration: const InputDecoration(
                  labelText: 'Deposited Into Account',
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
                onChanged: (val) =>
                    setDialogState(() => selectedDestAccId = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amt <= 0 || selectedDestAccId == null) return;

                await DatabaseHelper.instance.settleUp(
                  friendId: friendId,
                  amount: amt,
                  destinationAccountId: selectedDestAccId!,
                );

                ref.invalidate(friendsLedgerProvider);
                ref.read(dashboardProvider.notifier).refreshDashboard();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Confirm Settle Up'),
            ),
          ],
        ),
      ),
    );
  }
}
