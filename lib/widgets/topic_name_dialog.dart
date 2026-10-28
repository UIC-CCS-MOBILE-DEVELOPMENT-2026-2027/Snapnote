import 'package:flutter/material.dart';

/// Asks for a topic name (used for both creating and renaming).
///
/// [existingNames] are the names that are already taken (exclude the topic's
/// own current name when renaming); comparison is case-insensitive.
/// Returns the trimmed name, or null if the user cancels.
Future<String?> showTopicNameDialog(
  BuildContext context, {
  String? initialName,
  required List<String> existingNames,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TopicNameDialog(
      initialName: initialName,
      existingNames: existingNames,
    ),
  );
}

class _TopicNameDialog extends StatefulWidget {
  const _TopicNameDialog({this.initialName, required this.existingNames});

  final String? initialName;
  final List<String> existingNames;

  @override
  State<_TopicNameDialog> createState() => _TopicNameDialogState();
}

class _TopicNameDialogState extends State<_TopicNameDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  bool get _isRename => widget.initialName != null;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a topic name');
      return;
    }
    final taken = widget.existingNames
        .any((n) => n.trim().toLowerCase() == name.toLowerCase());
    if (taken) {
      setState(() => _errorText = 'You already have a topic with that name');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isRename ? 'Rename topic' : 'New topic'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'e.g. Quadratic Equations',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText != null) setState(() => _errorText = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isRename ? 'Rename' : 'Create'),
        ),
      ],
    );
  }
}
