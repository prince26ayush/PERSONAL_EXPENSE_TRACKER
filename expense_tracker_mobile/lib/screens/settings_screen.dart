import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/expense_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(tickProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Configuration')),
      body: stateAsync.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader(
              context,
              'Source Accounts & Balances',
              () => _showAddAccountDialog(context, ref),
            ),
            ...data.accounts.map(
              (acc) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    acc['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${acc['type']} • ₹${(acc['current_balance'] as num).toStringAsFixed(2)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () =>
                            _showEditAccountDialog(context, ref, acc),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => ref
                            .read(tickProvider.notifier)
                            .deleteAccount(acc['id']),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader(context, 'Payment Methods', () {
              if (data.accounts.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Add at least one Source Account first!'),
                  ),
                );
                return;
              }
              _showAddPaymentMethodDialog(context, ref, data.accounts);
            }),
            ...data.paymentMethods.map(
              (pm) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    pm['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${pm['type']} (Linked: ${pm['account_name'] ?? "Unknown"})',
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => ref
                        .read(tickProvider.notifier)
                        .deletePaymentMethod(pm['id']),
                  ),
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    VoidCallback onAdd,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle, color: Color(0xFF6366F1)),
          ),
        ],
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0.00');
    String type = 'SAVINGS';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Add Source Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'SAVINGS', child: Text('Savings')),
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'CREDIT', child: Text('Credit')),
                  DropdownMenuItem(
                    value: 'INVESTMENT',
                    child: Text('Investment'),
                  ),
                ],
                onChanged: (val) => setModalState(() => type = val!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: balanceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Initial Balance (₹)',
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
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  final bal = double.tryParse(balanceCtrl.text) ?? 0.0;
                  ref
                      .read(tickProvider.notifier)
                      .addAccount(nameCtrl.text.trim(), type, bal);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAccountDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> acc,
  ) {
    final nameCtrl = TextEditingController(text: acc['name']);
    final balanceCtrl = TextEditingController(
      text: acc['current_balance'].toString(),
    );
    String type = acc['type'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Edit Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'SAVINGS', child: Text('Savings')),
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                  DropdownMenuItem(value: 'CREDIT', child: Text('Credit')),
                  DropdownMenuItem(
                    value: 'INVESTMENT',
                    child: Text('Investment'),
                  ),
                ],
                onChanged: (val) => setModalState(() => type = val!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: balanceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Current Balance (₹)',
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
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  final bal = double.tryParse(balanceCtrl.text) ?? 0.0;
                  ref
                      .read(tickProvider.notifier)
                      .updateAccount(
                        acc['id'],
                        nameCtrl.text.trim(),
                        type,
                        bal,
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPaymentMethodDialog(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> accounts,
  ) {
    final nameCtrl = TextEditingController();
    String type = 'UPI';
    int selectedAccountId = accounts.first['id'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Add Payment Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Method Name (e.g. GPay, SBI Card)',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: selectedAccountId,
                items: accounts
                    .map(
                      (a) => DropdownMenuItem<int>(
                        value: a['id'],
                        child: Text(a['name']),
                      ),
                    )
                    .toList(),
                onChanged: (val) =>
                    setModalState(() => selectedAccountId = val!),
                decoration: const InputDecoration(
                  labelText: 'Linked Source Account',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                  DropdownMenuItem(
                    value: 'DEBIT_CARD',
                    child: Text('Debit Card'),
                  ),
                  DropdownMenuItem(
                    value: 'CREDIT_CARD',
                    child: Text('Credit Card'),
                  ),
                  DropdownMenuItem(
                    value: 'NET_BANKING',
                    child: Text('Net Banking'),
                  ),
                  DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                ],
                onChanged: (val) => setModalState(() => type = val!),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  ref
                      .read(tickProvider.notifier)
                      .addPaymentMethod(
                        selectedAccountId,
                        nameCtrl.text.trim(),
                        type,
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
