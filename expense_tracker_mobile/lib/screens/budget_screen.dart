import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/expense_provider.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(tickProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF6366F1)),
            tooltip: 'Set Budget',
            onPressed: () {
              stateAsync.whenData((data) {
                if (data.categories.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Create at least one category first!'),
                    ),
                  );
                  return;
                }
                _showSetBudgetDialog(context, ref, data.categories);
              });
            },
          ),
        ],
      ),
      body: stateAsync.when(
        data: (data) => data.budgets.isEmpty
            ? const Center(
                child: Text(
                  'No budgets set for this month. Tap + to set one!',
                  style: TextStyle(color: Colors.white54),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: data.budgets.length,
                itemBuilder: (context, index) {
                  final b = data.budgets[index];
                  final limit = (b['monthly_limit'] as num).toDouble();
                  final spent = (b['spent'] as num).toDouble();
                  final progress = limit > 0
                      ? (spent / limit).clamp(0.0, 1.0)
                      : 0.0;
                  final isOver = spent > limit;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                b['category_name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => ref
                                    .read(tickProvider.notifier)
                                    .deleteBudget(b['id']),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: const Color(0xFF242A3D),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isOver
                                  ? Colors.redAccent
                                  : const Color(0xFF10B981),
                            ),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Spent: ₹${spent.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                'Limit: ₹${limit.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showSetBudgetDialog(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> categories,
  ) {
    String selectedCategory = categories.first['name'];
    final limitCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Set Monthly Budget'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: categories
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c['name'],
                        child: Text(c['name']),
                      ),
                    )
                    .toList(),
                onChanged: (val) =>
                    setModalState(() => selectedCategory = val!),
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Monthly Limit (₹)',
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
                final limit = double.tryParse(limitCtrl.text);
                if (limit != null && limit > 0) {
                  ref
                      .read(tickProvider.notifier)
                      .setBudget(selectedCategory, limit);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Budget'),
            ),
          ],
        ),
      ),
    );
  }
}
