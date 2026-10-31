/// Windows and Android: there is no browser download, so this returns false
/// and the caller copies the text to the clipboard instead.
Future<bool> downloadTextFile(String filename, String content) async => false;
