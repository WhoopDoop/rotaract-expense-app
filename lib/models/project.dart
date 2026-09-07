class Project {
  final String id;
  final String name;
  final DateTime createdAt;

  Project({required this.id, required this.name, required this.createdAt});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Project.fromMap(Map<dynamic, dynamic> map) {
    return Project(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}