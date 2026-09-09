class Project {
  final String id;
  final String name;
  final DateTime createdAt;
  final String ownerId;

  Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.ownerId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'ownerId': ownerId,
    };
  }

  factory Project.fromMap(Map<dynamic, dynamic> map) {
    return Project(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['createdAt']),
      ownerId: map['ownerId'] ?? '', // old data before this update won't have this
    );
  }
}