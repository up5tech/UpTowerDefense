/// Raised when a content JSON file cannot be turned into a definition.
///
/// Messages name the offending field path (`buildPads[2].center`) so an author
/// can fix the file without reading a stack trace. The asset path is added by the
/// repository that loaded the file.
class ContentFormatException implements Exception {
  const ContentFormatException(this.message);

  final String message;

  @override
  String toString() => 'ContentFormatException: $message';
}
