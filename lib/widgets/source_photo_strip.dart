import 'dart:io';

import 'package:flutter/material.dart';

/// A compact row shown in the editor when an entry has a source photo:
/// a thumbnail (tap for full-screen zoom) and a toggle that splits the
/// editor so the photo and the transcription can be compared together.
class SourcePhotoStrip extends StatelessWidget {
  const SourcePhotoStrip({
    super.key,
    required this.path,
    required this.compareActive,
    required this.onOpenFullScreen,
    required this.onToggleCompare,
  });

  final String path;
  final bool compareActive;
  final VoidCallback onOpenFullScreen;
  final VoidCallback onToggleCompare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          InkWell(
            onTap: onOpenFullScreen,
            borderRadius: BorderRadius.circular(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(path),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                cacheWidth: 192,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: scheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: onOpenFullScreen,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Original photo',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      'Tap to view full screen',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Tooltip(
            message: compareActive ? 'Hide comparison' : 'Compare with text',
            child: IconButton.filledTonal(
              isSelected: compareActive,
              icon: const Icon(Icons.vertical_split_rounded),
              selectedIcon: const Icon(Icons.close_fullscreen_rounded),
              onPressed: onToggleCompare,
            ),
          ),
        ],
      ),
    );
  }
}
