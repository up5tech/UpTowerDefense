/// Raised when a content asset cannot be read, decoded, or validated.
///
/// Carries every validation issue so a broken file reports the whole list
/// instead of failing one rule at a time.
class ContentLoadException implements Exception {
  const ContentLoadException(
    this.assetPath,
    this.message, {
    this.issues = const [],
  });

  /// Asset that failed to load, useful in developer-facing diagnostics.
  final String assetPath;

  /// Short description of the failure.
  final String message;

  /// Individual validation problems, when the failure was content-related.
  final List<String> issues;

  @override
  String toString() {
    final details = issues.isEmpty ? '' : '\n- ${issues.join('\n- ')}';
    return 'ContentLoadException($assetPath): $message$details';
  }
}
