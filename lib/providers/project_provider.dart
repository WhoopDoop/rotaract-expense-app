import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/project.dart';

class ProjectProvider extends ChangeNotifier {
  final Box _box = Hive.box('projects');
  final _uuid = const Uuid();
  String? _currentUserId;

  // Called whenever the signed-in user changes (including sign-out -> null).
  void updateCurrentUser(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      notifyListeners();
    }
  }

  List<Project> get projects {
    if (_currentUserId == null) return [];
    final list = _box.values
        .map((e) => Project.fromMap(e as Map))
        .where((p) => p.ownerId == _currentUserId)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Project createProject(String name) {
    if (_currentUserId == null) {
      throw Exception('Cannot create a project: no signed-in user.');
    }
    final project = Project(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
      ownerId: _currentUserId!,
    );
    _box.put(project.id, project.toMap());
    notifyListeners();
    return project;
  }

  void deleteProject(String id) {
    _box.delete(id);
    notifyListeners();
  }
}