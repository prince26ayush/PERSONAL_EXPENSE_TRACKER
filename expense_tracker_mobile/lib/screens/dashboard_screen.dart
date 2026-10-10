import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/expense_provider.dart';
import '../database/database_helper.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Expense Tracker & Ledger',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(dashboardProvider.notifier).refreshDashboard(),
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (data) => RefreshIndicator(
          onRefresh: () =>
              ref.read(dashboardProvider.notifier).refreshDashboard(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- Master Net Worth Card ---
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NET RECONCILED WORTH',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currency.format(data.netWorth),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                      const Divider(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSummaryItem(
                            'Liquid Assets',
                            currency.format(data.totalLiquid),
                            Colors.green,
                          ),
                          _buildSummaryItem(
                            'Receivables',
                            currency.format(data.totalReceivable),
                            Colors.blue,
                          ),
                          _buildSummaryItem(
                            'Card Dues',
                            currency.format(data.totalLiabilities),
                            Colors.redAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Accounts Horizontal Scroll ---
              const Text(
                'Source Accounts',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: data.accounts.length,
                  itemBuilder: (context, index) {
                    final acc = data.accounts[index];
                    final bal = (acc['current_balance'] as num).toDouble();
                    final isNegative = bal < 0;
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.only(right: 12),
                      child: Container(
                        width: 170,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              acc['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              acc['type'] as String,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currency.format(bal),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isNegative ? Colors.red : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // --- Recent Transactions ---
              const Text(
                'Recent Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (data.recentTransactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No transactions logged yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...data.recentTransactions.map((tx) {
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: const Icon(
                          Icons.receipt_long,
                          color: Colors.blue,
                        ),
                      ),
                      title: Text(
                        tx['category'] ?? 'Expense',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${tx['source_name']} • ${tx['method_name']}\n${tx['notes'] ?? ''}',
                      ),
                      trailing: Text(
                        '-${currency.format(tx['total_amount'])}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      isThreeLine:
                          tx['notes'] != null &&
                          tx['notes'].toString().isNotEmpty,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickExpenseModal(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add / Split'),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // --- Modal to Log Expense or Split Bill ---
  void _showQuickExpenseModal(BuildContext context, WidgetRef ref) async {
    final db = await DatabaseHelper.instance.database;
    final methods = await db.query('payment_methods');
    final friends = await db.query('friends');
    final accounts = await db.query('accounts');

    if (!context.mounted) return;

    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String category = 'Food & Dining';
    int? selectedMethodId = methods.isNotEmpty
        ? methods.first['id'] as int
        : null;
    int? overrideAccountId;
    bool isSplit = false;
    final selectedFriendsShares = <int, TextEditingController>{};

    for (var f in friends) {
      selectedFriendsShares[f['id'] as int] = TextEditingController();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final currentMethod = methods.firstWhere(
              (m) => m['id'] == selectedMethodId,
              orElse: () => methods.first,
            );
            final requiresPrompt =
                currentMethod['requires_account_prompt'] == 1;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Record Expense',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Total Bill Amount (₹)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          [
                                'Food & Dining',
                                'Groceries',
                                'Fuel & Travel',
                                'Subscriptions',
                                'Utilities',
                                'Leisure',
                              ]
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                      onChanged: (val) => setModalState(() => category = val!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedMethodId,
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
                      onChanged: (val) {
                        setModalState(() {
                          selectedMethodId = val;
                          overrideAccountId = null;
                        });
                      },
                    ),
                    if (requiresPrompt) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: overrideAccountId,
                        decoration: const InputDecoration(
                          labelText: 'Select Bank Source',
                          border: OutlineInputBorder(),
                        ),
                        items: accounts
                            .where((a) => a['type'] == 'SAVINGS')
                            .map(
                              (a) => DropdownMenuItem<int>(
                                value: a['id'] as int,
                                child: Text(a['name'] as String),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setModalState(() => overrideAccountId = val),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Split this bill with friends?'),
                      value: isSplit,
                      onChanged: (val) => setModalState(() => isSplit = val),
                    ),
                    if (isSplit) ...[
                      const Divider(),
                      const Text(
                        'Friends Split Allocation (₹)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...friends.map((f) {
                        final fId = f['id'] as int;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(f['name'] as String),
                              ),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: selectedFriendsShares[fId],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'Share (₹)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          final total =
                              double.tryParse(amountController.text) ?? 0.0;
                          if (total <= 0 || selectedMethodId == null) return;

                          if (isSplit) {
                            double friendsSum = 0.0;
                            List<Map<String, dynamic>> splits = [];
                            selectedFriendsShares.forEach((fId, ctrl) {
                              final share = double.tryParse(ctrl.text) ?? 0.0;
                              if (share > 0) {
                                friendsSum += share;
                                splits.add({'friend_id': fId, 'share': share});
                              }
                            });

                            final myShare = total - friendsSum;
                            await DatabaseHelper.instance.logSplitExpense(
                              totalAmount: total,
                              myShare: myShare,
                              category: category,
                              paymentMethodId: selectedMethodId!,
                              friendSplits: splits,
                              overrideAccountId: overrideAccountId,
                              notes: notesController.text,
                            );
                          } else {
                            await DatabaseHelper.instance.logExpense(
                              amount: total,
                              category: category,
                              paymentMethodId: selectedMethodId!,
                              overrideAccountId: overrideAccountId,
                              notes: notesController.text,
                            );
                          }

                          ref
                              .read(dashboardProvider.notifier)
                              .refreshDashboard();
                          ref.invalidate(friendsLedgerProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Confirm & Deduct Balance'),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
