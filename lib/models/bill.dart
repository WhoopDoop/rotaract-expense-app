class BillItem {
  final String item;
  final double price;
  final double quantity;

  BillItem({required this.item, required this.price, required this.quantity});

  double get amount => price * quantity;

  Map<String, dynamic> toMap() => {
        'item': item,
        'price': price,
        'quantity': quantity,
      };

  factory BillItem.fromMap(Map<dynamic, dynamic> map) => BillItem(
        item: map['item'],
        price: (map['price'] as num).toDouble(),
        quantity: (map['quantity'] as num).toDouble(),
      );
}

class Bill {
  final String id;
  final String projectId;
  final String category;
  final int billNo;
  final List<BillItem> items;
  final String? imagePath;
  final String? driveFileId;

  Bill({
    required this.id,
    required this.projectId,
    required this.category,
    required this.billNo,
    required this.items,
    this.imagePath,
    this.driveFileId,
  });

  /// Total of all line items on this bill.
  double get amount => items.fold<double>(0, (sum, i) => sum + i.amount);

  Map<String, dynamic> toMap() => {
        'id': id,
        'projectId': projectId,
        'category': category,
        'billNo': billNo,
        'items': items.map((i) => i.toMap()).toList(),
        'imagePath': imagePath,
        'driveFileId': driveFileId,
      };

  factory Bill.fromMap(Map<dynamic, dynamic> map) {
    final rawItems = map['items'];
    final List<BillItem> items;
    if (rawItems != null) {
      items = (rawItems as List).map((e) => BillItem.fromMap(e as Map)).toList();
    } else {
      // Old format (before multi-item bills): one item stored directly on the bill.
      items = [
        BillItem(
          item: map['item'],
          price: (map['price'] as num).toDouble(),
          quantity: (map['quantity'] as num).toDouble(),
        ),
      ];
    }
    return Bill(
      id: map['id'],
      projectId: map['projectId'],
      category: map['category'],
      billNo: map['billNo'],
      items: items,
      imagePath: map['imagePath'],
      driveFileId: map['driveFileId'],
    );
  }
}