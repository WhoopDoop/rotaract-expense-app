import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/project.dart';
import '../models/bill.dart';
import '../providers/bill_provider.dart';
import '../providers/auth_provider.dart';
import '../services/docs_service.dart';
import '../services/drive_service.dart';
import 'add_edit_bill_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Project project;
  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  Future<void> _generateReport() async {
    final billProvider = context.read<BillProvider>();
    final auth = context.read<AuthProvider>();
    final grouped = billProvider.groupedByCategory(widget.project.id);

    if (grouped.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one bill first.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Generating your report...')),
          ],
        ),
      ),
    );

    try {
      final docsService = DocsService(auth.signInInstance);
      final driveService = DriveService(auth.signInInstance);

      final url = await docsService.generateReport(
        documentTitle: '${widget.project.name} - Expense Report',
        groupedBills: grouped,
        imageUrlBuilder: driveService.embeddableImageUrl,
      );

      if (mounted) Navigator.pop(context); // close loading dialog

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final billProvider = context.watch<BillProvider>();
    final grouped = billProvider.groupedByCategory(widget.project.id);

    final categoryTotals = {
      for (final entry in grouped.entries)
        entry.key: entry.value.fold<double>(0, (sum, b) => sum + b.amount)
    };
    final grandTotal = categoryTotals.values.fold<double>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Generate Report',
            onPressed: _generateReport,
          ),
        ],
      ),
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
                    projectId: widget.project.id,
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
            builder: (_) => AddEditBillScreen(projectId: widget.project.id),
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
    final rows = <TableRow>[
      _headerRow(['S.No.', 'Item', 'Price', 'Qty', 'Amount', 'Bill No.', '']),
    ];

    int sNo = 1;
    for (final bill in bills) {
      for (int j = 0; j < bill.items.length; j++) {
        rows.add(_dataRow(
          sNo: j == 0 ? sNo : null, // only the first row of a bill gets a number
          item: bill.items[j],
          bill: bill,
          isFirstRowOfBill: j == 0,
        ));
      }
      sNo++; // move to the next number once per bill, not per item
    }
    rows.add(_totalRow(total));

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
      children: rows,
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

  TableRow _dataRow({
    required int? sNo,
    required BillItem item,
    required Bill bill,
    required bool isFirstRowOfBill,
  }) {
    return TableRow(children: [
      _cell(sNo?.toString() ?? ''),
      _cell(item.item),
      _cell(item.price.toStringAsFixed(2)),
      _cell(item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 2)),
      _cell(item.amount.toStringAsFixed(2)),
      _cell(isFirstRowOfBill ? '${bill.billNo}' : ''),
      isFirstRowOfBill
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => onEdit(bill)),
                IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () => onDelete(bill)),
              ],
            )
          : const SizedBox.shrink(),
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