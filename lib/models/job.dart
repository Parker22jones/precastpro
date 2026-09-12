/// A project in the global Jobs view. Structures hang off a job by [id].
class Job {
  Job({
    required this.id,
    required this.name,
    required this.number,
    required this.contractor,
    required this.customer,
  });

  final String id;
  String name;
  String number;
  String contractor;
  String customer;

  /// Instant-search predicate used by the Jobs screen: name, number or
  /// contractor, case-insensitive.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        number.toLowerCase().contains(q) ||
        contractor.toLowerCase().contains(q);
  }
}
