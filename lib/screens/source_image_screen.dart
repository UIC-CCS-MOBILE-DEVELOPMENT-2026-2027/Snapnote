import 'package:flutter/material.dart';

import '../widgets/zoomable_image.dart';

/// Full-screen, zoomable view of the photo an entry was transcribed from.
class SourceImageScreen extends StatelessWidget {
  const SourceImageScreen({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Original photo'),
      ),
      body: SafeArea(child: ZoomableImage(path: path)),
    );
  }
}
