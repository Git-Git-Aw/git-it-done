import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';

/// The backend accepts images up to 5 MB.
const int maxPhotoBytes = 5 * 1024 * 1024;

/// A photo chosen from the gallery or taken with the camera.
class PickedPhoto {
  PickedPhoto({required this.bytes, required this.name, required this.contentType});

  final Uint8List bytes;
  final String name;

  /// image/jpeg, image/png, or image/webp (the only types the backend accepts).
  final String contentType;
}

/// The camera button is only shown on phones. Web and Windows use the gallery
/// (file chooser).
bool get cameraSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

String _contentTypeFor(XFile file) {
  final mime = file.mimeType;
  if (mime != null && (mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/webp')) {
    return mime;
  }
  final name = file.name.toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Returns null when the person closes the picker without choosing.
/// Throws [ApiException] (a readable message) when the image is too big.
Future<PickedPhoto?> pickPhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    imageQuality: 85,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > maxPhotoBytes) {
    throw ApiException('That image is larger than 5 MB. Please choose a smaller photo.');
  }
  return PickedPhoto(bytes: bytes, name: file.name, contentType: _contentTypeFor(file));
}
