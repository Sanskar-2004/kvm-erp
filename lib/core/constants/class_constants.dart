/// Shared class ordering constants and utilities for KVM ERP.
/// All class dropdowns/filters should use these values for consistency.
class ClassConstants {
  ClassConstants._();

  /// The canonical ordered list of all classes in the school.
  static const allClasses = [
    'Nursery', 'KG1', 'KG2',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',
  ];

  /// Same list with "All" prepended, for filter dropdowns.
  static const allClassesWithAll = [
    'All', 'Nursery', 'KG1', 'KG2',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12',
  ];

  /// Returns a sort-friendly index for a class ID.
  /// Nursery = 0, KG1 = 1, KG2 = 2, 1 = 3, 2 = 4, ... 12 = 14
  /// Unknown classes get 999 so they sort last.
  static int classOrder(String classId) {
    final idx = allClasses.indexOf(classId);
    if (idx >= 0) return idx;
    // Try numeric fallback
    final num = int.tryParse(classId);
    if (num != null) return num + 2; // offset by pre-primary count
    return 999;
  }

  /// Comparator for sorting class IDs in school order.
  static int compareClasses(String a, String b) {
    return classOrder(a).compareTo(classOrder(b));
  }

  /// Sort a list of class IDs in proper school order.
  /// If `hasAll` is true, 'All' is always placed first.
  static List<String> sortClasses(List<String> classes, {bool hasAll = false}) {
    final sorted = List<String>.from(classes);
    sorted.sort((a, b) {
      if (a == 'All') return -1;
      if (b == 'All') return 1;
      return compareClasses(a, b);
    });
    return sorted;
  }
}
