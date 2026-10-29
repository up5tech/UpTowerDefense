/// Which enemy a tower prefers when several are in range.
///
/// The MVP ships these two; the enum makes the choice explicit data on the
/// tower instance rather than a behaviour flag sprinkled through the session.
enum TargetingPolicy {
  /// Furthest along the route: kills the leak threat first.
  first,

  /// Highest current health: wears down the durable target first.
  strongest,
}
