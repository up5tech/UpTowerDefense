/// Outcome of validating one part of the content set.
///
/// Every problem is reported, not just the first, so an author can fix a file in
/// one pass.
class ValidationResult {
  const ValidationResult(this.issues);

  /// Human-readable problems, empty when the content is valid.
  final List<String> issues;

  /// Whether the content can be used.
  bool get isValid => issues.isEmpty;
}
