/// A-Z by display name only, ignoring case and surrounding whitespace.
/// Keep equal names in their original order and never mutate the source list.
List<T> sortedByName<T>(Iterable<T> items, String Function(T) nameOf) {
  final entries = items.indexed.toList()
    ..sort((first, second) {
      final order = nameOf(first.$2)
          .trim()
          .toLowerCase()
          .compareTo(nameOf(second.$2).trim().toLowerCase());
      return order != 0 ? order : first.$1.compareTo(second.$1);
    });
  return entries.map((entry) => entry.$2).toList();
}
