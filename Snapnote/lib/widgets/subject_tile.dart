import 'package:flutter/material.dart';

import '../models/subject.dart';

class SubjectTile extends StatelessWidget {
  const SubjectTile({
    super.key,
    required this.subject,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Subject subject;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(subject.name),
      subtitle: Text('Created ${_formatDate(subject.createdAt)}'),
      onTap: onTap,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
