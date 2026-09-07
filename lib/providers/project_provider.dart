import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/project.dart';

class ProjectProvider extends ChangeNotifier {
  final Box _box = Hive.box('projects');
  final _uuid = const Uuid();

  List<Project> get projects {
    final list = _box.values
        .map((e) => Project.fromMap(e as Map))
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Project createProject(String name) {
    final project = Project(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
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