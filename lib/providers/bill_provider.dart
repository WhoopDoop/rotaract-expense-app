import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/bill.dart';

class BillProvider extends ChangeNotifier {
  final Box _box = Hive.box('bills');
  final _uuid = const Uuid();

  List<Bill> billsForProject(String projectId) {
    final list = _box.values
        .map((e) => Bill.fromMap(e as Map))
        .where((b) => b.projectId == projectId)
        .toList();
    list.sort((a, b) => a.billNo.compareTo(b.billNo));
    return list;
  }

  // Groups bills by category, preserving first-seen order.
  Map<String, List<Bill>> groupedByCategory(String projectId) {
    final bills = billsForProject(projectId);
    final Map<String, List<Bill>> grouped = {};
    for (final bill in bills) {
      grouped.putIfAbsent(bill.category, () => []).add(bill);
    }
    return grouped;
  }

  int nextBillNo(String projectId) {
    final bills = billsForProject(projectId);
    if (bills.isEmpty) return 1;
    return bills.map((b) => b.billNo).reduce((a, b) => a > b ? a : b) + 1;
  }

  void addBill(Bill bill) {
    _box.put(bill.id, bill.toMap());
    notifyListeners();
  }

  void updateBill(Bill bill) {
    _box.put(bill.id, bill.toMap());
    notifyListeners();
  }

  void deleteBill(String id) {
    _box.delete(id);
    notifyListeners();
  }
}