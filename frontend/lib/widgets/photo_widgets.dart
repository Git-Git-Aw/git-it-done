import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../utils/photo_picker.dart';
import 'common.dart';

/// Lets the person pick a photo (gallery, and camera on phones) and shows a preview.
class PhotoField extends StatelessWidget {
  const PhotoField({
    super.key,
    required this.photo,
    required this.onChanged,
    this.label = 'Photo',
  });

  final PickedPhoto? photo;
  final ValueChanged<PickedPhoto?> onChanged;
  final String label;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final picked = await pickPhoto(source);
      if (picked != null) onChanged(picked);
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (current != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(current.bytes, height: 160, fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pick(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(current == null ? 'Choose photo' : 'Choose another'),
            ),
            if (cameraSupported)
              OutlinedButton.icon(
                onPressed: () => _pick(context, ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take photo'),
              ),
            if (current != null)
              TextButton.icon(
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.close),
                label: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }
}

String _photoUrl(String path) {
  return path.startsWith('http') ? path : '${AppConfig.apiBaseUrl}$path';
}

/// A small picture stored on the server (receipt or repair photo). Tap to enlarge.
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto(this.path, {super.key, this.size = 110});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = _photoUrl(path);
    return InkWell(
      onTap: () => showPhotoDialog(context, path),
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: size,
            height: size,
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

/// Shows a photo from the server in a large pop-up.
Future<void> showPhotoDialog(BuildContext context, String path) {
  final url = _photoUrl(path);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton.filledTonal(
              tooltip: 'Close',
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    ),
  );
}
