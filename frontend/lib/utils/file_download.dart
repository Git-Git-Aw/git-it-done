// Saving a file works differently on the web and on other platforms, so the
// right version is chosen when the app is built.
export 'file_download_stub.dart' if (dart.library.js_interop) 'file_download_web.dart';
