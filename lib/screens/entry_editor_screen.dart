import 'dart:io';

import 'package:flutter/material.dart';

import '../data/entry_repository.dart';
import '../models/entry.dart';
import '../services/gemini_transcription_service.dart';
import '../widgets/latex_content_view.dart';
import '../widgets/source_photo_strip.dart';
import '../widgets/zoomable_image.dart';
import 'capture_screen.dart';
import 'source_image_screen.dart';

/// Create a new entry or edit an existing one.
///
/// The screen intentionally keeps export/share actions as UI-only controls
/// for now. Their actual integrations can be added later without changing
/// the visual flow.
class EntryEditorScreen extends StatefulWidget {
  const EntryEditorScreen({
    super.key,
    required this.subjectId,
    this.existingEntry,
    this.initialImagePath,
  });

  final int subjectId;
  final Entry? existingEntry;
  final String? initialImagePath;

  @override
  State<EntryEditorScreen> createState() => _EntryEditorScreenState();
}

class _EntryEditorScreenState extends State<EntryEditorScreen> {
  final _repo = EntryRepository();
  final _transcriptionService = GeminiTranscriptionService();

  late final TextEditingController _contentController;
  String? _sourceImagePath;
  bool _showPreview = false;
  bool _showCompare = false;
  bool _isTranscribing = false;
  String? _error;

  bool get _isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    _contentController =
        TextEditingController(text: widget.existingEntry?.content ?? '');
    _sourceImagePath = widget.existingEntry?.sourceImagePath;

    final initialPath = widget.initialImagePath;
    if (initialPath != null) {
      _transcribeFile(File(initialPath));
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _transcribeFile(File file) async {
    setState(() {
      _error = null;
      _isTranscribing = true;
    });
    try {
      final text = await _transcriptionService.transcribeImage(file);
      if (!mounted) return;
      setState(() {
        _sourceImagePath = file.path;
        if (_contentController.text.trim().isEmpty) {
          _contentController.text = text;
        } else {
          _contentController.text = '${_contentController.text}\n\n$text';
        }
      });
    } on TranscriptionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isTranscribing = false);
    }
  }

  void _openSourceImage(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SourceImageScreen(path: path)),
    );
  }

  Future<void> _addAnotherPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          subjectId: widget.subjectId,
          existingEntry: widget.existingEntry,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    try {
      if (_isEditing) {
        await _repo.update(
          widget.existingEntry!,
          newContent: content,
          newSourceImagePath: _sourceImagePath,
        );
      } else {
        await _repo.create(
          subjectId: widget.subjectId,
          content: content,
          sourceImagePath: _sourceImagePath,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save entry — try again")),
        );
      }
      return;
    }

    if (mounted) Navigator.pop(context);
  }

  void _showMoreMenu() {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.sizeOf(context).width - 190,
        kToolbarHeight + MediaQuery.paddingOf(context).top + 4,
        12,
        0,
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: const [
        PopupMenuItem(
          value: 'save',
          child: ListTile(
            leading: Icon(Icons.save_alt_rounded),
            title: Text('Save as'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          child: ListTile(
            leading: Icon(Icons.copy_all_rounded),
            title: Text('Copy all'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: ListTile(
            leading: Icon(Icons.ios_share_rounded),
            title: Text('Share'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (!mounted || value == null) return;
      if (value == 'save') _showSaveAsSheet();
      if (value == 'share') _showShareSheet();
      // Copy all is intentionally visual-only for this UI pass.
    });
  }

  void _showSaveAsSheet() {
    _showOptionSheet(
      title: 'Save as',
      subtitle: 'Choose a format',
      options: const [
        _SheetOption('DOCX', '.docx', Icons.description_rounded),
        _SheetOption('TXT', '.txt', Icons.notes_rounded),
        _SheetOption('JSON', '.json', Icons.data_object_rounded),
        _SheetOption('JAR', '.jar', Icons.inventory_2_rounded),
      ],
    );
  }

  void _showShareSheet() {
    _showOptionSheet(
      title: 'Share',
      subtitle: 'Choose an app',
      options: const [
        _SheetOption('Messenger', 'Facebook Messenger', Icons.chat_rounded),
        _SheetOption('Google Chat', 'Google Chats', Icons.forum_rounded),
        _SheetOption('Discord', 'Discord', Icons.gamepad_rounded),
        _SheetOption('Email', 'Email', Icons.email_rounded),
      ],
    );
  }

  void _showOptionSheet({
    required String title,
    required String subtitle,
    required List<_SheetOption> options,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 18),
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, index) {
                      final option = options[index];
                      return SizedBox(
                        width: 104,
                        child: Material(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(option.icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(option.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sourcePath = _sourceImagePath;
    // The photo file can be gone (e.g. app data partly cleared); only offer
    // the viewer when it's actually on disk.
    final hasSourceImage = sourcePath != null && File(sourcePath).existsSync();
    final showCompare = hasSourceImage && _showCompare;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 4,
        title: Text(_isEditing ? 'Edit Note' : 'New Note', style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Tooltip(
            message: 'Add another page',
            child: IconButton.filledTonal(
              icon: const Icon(Icons.add_rounded),
              onPressed: _addAnotherPage,
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: _showPreview ? 'Edit' : 'Reading mode',
            child: IconButton(
              icon: Icon(_showPreview ? Icons.edit_rounded : Icons.menu_book_rounded),
              onPressed: () => setState(() => _showPreview = !_showPreview),
            ),
          ),
          Tooltip(
            message: 'More',
            child: IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: _showMoreMenu,
            ),
          ),
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.check_rounded),
            onPressed: _save,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (_isTranscribing)
            const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(_error!),
            ),
          if (hasSourceImage)
            SourcePhotoStrip(
              path: sourcePath!,
              compareActive: showCompare,
              onOpenFullScreen: () => _openSourceImage(sourcePath!),
              onToggleCompare: () =>
                  setState(() => _showCompare = !_showCompare),
            ),
          if (showCompare)
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ColoredBox(
                    color: Colors.black,
                    child: ZoomableImage(path: sourcePath!),
                  ),
                ),
              ),
            ),
          Expanded(
            flex: showCompare ? 3 : 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _showPreview
                    ? Container(
                        key: const ValueKey('preview'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: SingleChildScrollView(
                          child: LatexContentView(content: _contentController.text),
                        ),
                      )
                    : Container(
                        key: const ValueKey('editor'),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                        child: TextField(
                          controller: _contentController,
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          style: const TextStyle(fontSize: 16, height: 1.55),
                          decoration: const InputDecoration(
                            hintText: 'Your transcribed notes will appear here…',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetOption {
  const _SheetOption(this.label, this.semanticName, this.icon);
  final String label;
  final String semanticName;
  final IconData icon;
}
