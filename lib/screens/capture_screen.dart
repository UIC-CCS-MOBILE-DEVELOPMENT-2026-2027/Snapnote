import 'dart:io';

import 'package:flutter/material.dart';

import '../services/image_storage_service.dart';
import 'entry_editor_screen.dart';
import '../models/entry.dart';

/// Lets the user take a photo or pick one from the gallery, preview it, and
/// confirm before handing it off to [EntryEditorScreen] for transcription.
///
/// Permissions: image_picker triggers the OS camera/photo-library
/// permission prompts itself at pick time — no extra request code is
/// needed here. However the *declarations* still have to be added by hand:
///   - iOS: add NSCameraUsageDescription and NSPhotoLibraryUsageDescription
///     to ios/Runner/Info.plist
///   - Android: add <uses-permission android:name="android.permission.CAMERA"/>
///     (and, on API < 33, READ_EXTERNAL_STORAGE) to
///     android/app/src/main/AndroidManifest.xml
/// Without those, the OS will silently deny the request or crash on some
/// versions rather than showing a prompt.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.subjectId,
    this.existingEntry,
    this.initialTopicId,
  });

  final int subjectId;
  final Entry? existingEntry;

  /// Topic to file a brand-new entry under (ignored for existing entries).
  final int? initialTopicId;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _imageService = ImageStorageService();

  File? _selectedImage;
  bool _isPicking = false;
  String? _error;

  Future<void> _pick(Future<File?> Function() pick) async {
    setState(() {
      _isPicking = true;
      _error = null;
    });
    try {
      final file = await pick();
      // file is null when the user backs out of the camera/gallery UI —
      // that's a normal cancel, not an error, so just stay on this screen.
      setState(() => _selectedImage = file);
    } catch (e) {
      setState(() => _error = 'Could not get that photo: $e');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _retake() {
    setState(() {
      _selectedImage = null;
      _error = null;
    });
  }

  void _confirm() {
    final image = _selectedImage;
    if (image == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditorScreen(
          subjectId: widget.subjectId,
          existingEntry: widget.existingEntry,
          initialTopicId: widget.initialTopicId,
          initialImagePath: image.path,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture Photo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _selectedImage == null ? _buildPickerView() : _buildPreviewView(),
      ),
    );
  }

  Widget _buildPickerView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Text(_error!),
          ),
        ],
        const Icon(Icons.photo_camera_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          'Take a photo of your notes, or choose an existing one',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _isPicking ? null : () => _pick(_imageService.pickFromCamera),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Take Photo'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isPicking ? null : () => _pick(_imageService.pickFromGallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose from Gallery'),
        ),
        if (_isPicking) ...[
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ],
    );
  }

  Widget _buildPreviewView() {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.contain,
              width: double.infinity,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _retake,
                icon: const Icon(Icons.refresh),
                label: const Text('Retake / Choose again'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _confirm,
                icon: const Icon(Icons.check),
                label: const Text('Use this photo'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
