import 'dart:io';

import 'package:flutter/material.dart';

/// Shows a local image file with pinch-to-zoom, pan, and double-tap to zoom
/// in (or back out). Fills whatever space its parent gives it.
class ZoomableImage extends StatefulWidget {
  const ZoomableImage({super.key, required this.path});

  final String path;

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> {
  static const _doubleTapScale = 2.5;

  final _controller = TransformationController();
  Offset _doubleTapPosition = Offset.zero;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final isZoomedIn = _controller.value.getMaxScaleOnAxis() > 1.01;
    if (isZoomedIn) {
      _controller.value = Matrix4.identity();
      return;
    }
    // Zoom about the tapped point so it stays under the finger.
    final p = _doubleTapPosition;
    const s = _doubleTapScale;
    _controller.value =
        Matrix4.translationValues(-p.dx * (s - 1), -p.dy * (s - 1), 0)
            .multiplied(Matrix4.diagonal3Values(s, s, 1));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 6,
        child: SizedBox.expand(
          child: Image.file(
            File(widget.path),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            // Cap decode size so a 12MP camera photo doesn't balloon memory.
            cacheWidth: 2400,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text("Couldn't load the original photo"),
            ),
          ),
        ),
      ),
    );
  }
}
