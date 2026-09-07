class Bill {
  final String id;
  final String projectId;
  final String category;
  final String item;
  final double price;
  final double quantity;
  final int billNo;
  final String? imagePath; // local file path to the photo

  Bill({
    required this.id,
    required this.projectId,
    required this.category,
    required this.item,
    required this.price,
    required this.quantity,
    required this.billNo,
    this.imagePath,
  });

  double get amount => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'category': category,
      'item': item,
      'price': price,
      'quantity': quantity,
      'billNo': billNo,
      'imagePath': imagePath,
    };
  }

  factory Bill.fromMap(Map<dynamic, dynamic> map) {
    return Bill(
      id: map['id'],
      projectId: map['projectId'],
      category: map['category'],
      item: map['item'],
      price: (map['price'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      billNo: map['billNo'],
      imagePath: map['imagePath'],
    );
  }

  Bill copyWith({
    String? category,
    String? item,
    double? price,
    double? quantity,
    int? billNo,
    String? imagePath,
  }) {
    return Bill(
      id: id,
      projectId: projectId,
      category: category ?? this.category,
      item: item ?? this.item,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      billNo: billNo ?? this.billNo,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}