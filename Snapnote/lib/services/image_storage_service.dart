import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Picks photos (camera or gallery) and copies them into the app's local
/// documents directory so entries keep working even if the original photo
/// is deleted from the system gallery. No image ever leaves the device
/// except the single upload made to Gemini for transcription.
class ImageStorageService {
  final ImagePicker _picker = ImagePicker();

  Future<File?> pickFromCamera() => _pickAndStore(ImageSource.camera);

  Future<File?> pickFromGallery() => _pickAndStore(ImageSource.gallery);

  Future<File?> _pickAndStore(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return null;

    final docsDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(docsDir.path, 'entry_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final ext = p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
    final fileName = '${DateTime.now().microsecondsSinceEpoch}$ext';
    final destPath = p.join(imagesDir.path, fileName);

    return File(picked.path).copy(destPath);
  }

  Future<void> deleteImage(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
