import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import 'project_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _createProject(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Expense Report'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Annual Day 2026'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              final project = context
                  .read<ProjectProvider>()
                  .createProject(controller.text.trim());
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectDetailScreen(project: project),
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectProvider>().projects;

    return Scaffold(
      appBar: AppBar(title: const Text('Expense Reports')),
      body: projects.isEmpty
          ? const Center(child: Text('No projects yet. Tap + to create one.'))
          : ListView.builder(
              itemCount: projects.length,
              itemBuilder: (ctx, i) {
                final project = projects[i];
                return ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text(project.name),
                  subtitle: Text(
                    'Created ${project.createdAt.toLocal().toString().split(' ').first}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      context.read<ProjectProvider>().deleteProject(project.id);
                    },
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectDetailScreen(project: project),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createProject(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}