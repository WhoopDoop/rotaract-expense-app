import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';
import 'add_edit_bill_screen.dart';

class ProjectDetailScreen extends StatelessWidget {
  final Project project;
  const ProjectDetailScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final billProvider = context.watch<BillProvider>();
    final grouped = billProvider.groupedByCategory(project.id);

    // Category -> total amount
    final categoryTotals = {
      for (final entry in grouped.entries)
        entry.key: entry.value.fold<double>(0, (sum, b) => sum + b.amount)
    };
    final grandTotal = categoryTotals.values.fold<double>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: Text(project.name)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (grouped.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No bills yet. Tap "Add a Bill" to start.')),
            ),
          for (final category in grouped.keys) ...[
            Text(category,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _CategoryTable(
              bills: grouped[category]!,
              total: categoryTotals[category]!,
              onEdit: (bill) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditBillScreen(
                    projectId: project.id,
                    existingBill: bill,
                  ),
                ),
              ),
              onDelete: (bill) => billProvider.deleteBill(bill.id),
            ),
            const SizedBox(height: 20),
          ],
          if (grouped.isNotEmpty) ...[
            Text('TOTAL',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _TotalTable(categoryTotals: categoryTotals, grandTotal: grandTotal),
          ],
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddEditBillScreen(projectId: project.id),
          ),
        ),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('ADD A BILL'),
      ),
    );
  }
}

class _CategoryTable extends StatelessWidget {
  final List<Bill> bills;
  final double total;
  final void Function(Bill) onEdit;
  final void Function(Bill) onDelete;

  const _CategoryTable({
    required this.bills,
    required this.total,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade400),
      columnWidths: const {
        0: FixedColumnWidth(36),
        1: FlexColumnWidth(2.5),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1.2),
        5: FlexColumnWidth(1.2),
        6: FixedColumnWidth(70),
      },
      children: [
        _headerRow(['S.No.', 'Item', 'Price', 'Qty', 'Amount', 'Bill No.', '']),
        for (int i = 0; i < bills.length; i++)
          _dataRow(context, i + 1, bills[i]),
        _totalRow(total),
      ],
    );
  }

  TableRow _headerRow(List<String> labels) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.deepOrange.shade50),
      children: labels
          .map((l) => Padding(
                padding: const EdgeInsets.all(6),
                child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold)),
              ))
          .toList(),
    );
  }

  TableRow _dataRow(BuildContext context, int sNo, Bill bill) {
    return TableRow(children: [
      _cell('$sNo'),
      _cell(bill.item),
      _cell(bill.price.toStringAsFixed(2)),
      _cell(bill.quantity.toStringAsFixed(bill.quantity % 1 == 0 ? 0 : 2)),
      _cell(bill.amount.toStringAsFixed(2)),
      _cell('${bill.billNo}'),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => onEdit(bill),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18),
            onPressed: () => onDelete(bill),
          ),
        ],
      ),
    ]);
  }

  TableRow _totalRow(double total) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: [
        _cell(''),
        _cell(''),
        _cell(''),
        _cell('Total', bold: true),
        _cell(total.toStringAsFixed(2), bold: true),
        _cell(''),
        _cell(''),
      ],
    );
  }

  Widget _cell(String text, {bool bold = false}) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(text,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );
}

class _TotalTable extends StatelessWidget {
  final Map<String, double> categoryTotals;
  final double grandTotal;

  const _TotalTable({required this.categoryTotals, required this.grandTotal});

  @override
  Widget build(BuildContext context) {
    final entries = categoryTotals.entries.toList();
    return Table(
      border: TableBorder.all(color: Colors.grey.shade400),
      columnWidths: const {
        0: FixedColumnWidth(50),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(1.5),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.deepOrange.shade50),
          children: const [
            Padding(padding: EdgeInsets.all(6), child: Text('S.no.', style: TextStyle(fontWeight: FontWeight.bold))),
            Padding(padding: EdgeInsets.all(6), child: Text('Details', style: TextStyle(fontWeight: FontWeight.bold))),
            Padding(padding: EdgeInsets.all(6), child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        for (int i = 0; i < entries.length; i++)
          TableRow(children: [
            Padding(padding: const EdgeInsets.all(6), child: Text('${i + 1}')),
            Padding(padding: const EdgeInsets.all(6), child: Text(entries[i].key)),
            Padding(padding: const EdgeInsets.all(6), child: Text(entries[i].value.toStringAsFixed(2))),
          ]),
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade200),
          children: [
            const Padding(padding: EdgeInsets.all(6), child: Text('')),
            const Padding(padding: EdgeInsets.all(6), child: Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold))),
            Padding(padding: const EdgeInsets.all(6), child: Text(grandTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      ],
    );
  }
}