import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/fees_provider.dart';

class FeesScreen extends ConsumerWidget {
  const FeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feesList = ref.watch(feesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fees'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Filter by status
            },
          ),
        ],
      ),
      body: feesList.isEmpty
          ? const Center(child: Text('No fee records'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: feesList.length,
              itemBuilder: (context, index) {
                final fee = feesList[index];
                final statusColor = fee.status == 'paid'
                    ? Colors.green
                    : fee.status == 'overdue'
                        ? Colors.red
                        : Colors.orange;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.1),
                      child: Icon(Icons.receipt_long, color: statusColor),
                    ),
                    title: Text(
                        '${fee.studentName} - ${fee.feeType.toUpperCase()}'),
                    subtitle: Text(
                      '₹${fee.amount} • Due: ${fee.dueDate.day}/${fee.dueDate.month}/${fee.dueDate.year}',
                    ),
                    trailing: Chip(
                      label: Text(
                        fee.status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 10),
                      ),
                      backgroundColor: statusColor.withOpacity(0.1),
                    ),
                    onTap: () {
                      // TODO: Fee detail / payment
                    },
                  ),
                );
              },
            ),
    );
  }
}
