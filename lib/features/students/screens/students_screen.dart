import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/student_repository.dart';
import '../../dashboard/repositories/dashboard_repository.dart';
import '../../../../models/student_model.dart';
import '../../../core/constants/class_constants.dart';
import 'add_student_screen.dart';
import 'student_detail_screen.dart';

// Provides standard fetched students via lazy rendering
final studentsListProvider = FutureProvider.autoDispose<List<StudentModel>>((ref) async {
  return ref.watch(studentRepositoryProvider).getAllStudents(limit: 500, offset: 0);
});

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  String _selectedClass = 'All';
  String _selectedGender = 'All';
  String _selectedCategory = 'All';
  String _sortBy = 'Name';
  String _searchQuery = '';

  // Canonical filter options (not dynamically extracted)
  final List<String> _availableClasses = ClassConstants.allClassesWithAll;
  static const _availableGenders = ['All', 'Male', 'Female', 'Other'];
  static const _availableCategories = ['All', 'General', 'OBC', 'SC', 'ST', 'EWS', 'Others'];

  void _extractFilterOptions(List<StudentModel> students) {
    // Filter options are now canonical constants, no extraction needed
  }

  List<StudentModel> _applyFilters(List<StudentModel> students) {
    var filtered = students.where((s) {
      // Class filter
      if (_selectedClass != 'All' && s.classId != _selectedClass) return false;
      // Gender filter (case-insensitive)
      if (_selectedGender != 'All' && s.gender.toLowerCase() != _selectedGender.toLowerCase()) return false;
      // Category filter (case-insensitive)
      if (_selectedCategory != 'All' && (s.category ?? '').toLowerCase() != _selectedCategory.toLowerCase()) return false;
      // Search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery;
        return s.name.toLowerCase().contains(q) ||
               s.rollNumber.toLowerCase().contains(q) ||
               s.parentName.toLowerCase().contains(q) ||
               s.classId.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // Sort
    switch (_sortBy) {
      case 'Name':
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'Roll':
        filtered.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
      case 'Class':
        filtered.sort((a, b) {
          final cmp = ClassConstants.compareClasses(a.classId, b.classId);
          if (cmp != 0) return cmp;
          return a.name.compareTo(b.name);
        });
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('All Students'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddStudentScreen()),
          );
          if (result == true) {
            ref.invalidate(studentsListProvider);
            ref.invalidate(dashboardMetricsProvider);
          }
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Student'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: studentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (allStudents) {
          // Extract real filter options from data
          _extractFilterOptions(allStudents);

          // Validate selected filters still exist in data
          if (!_availableClasses.contains(_selectedClass)) _selectedClass = 'All';
          if (!_availableGenders.contains(_selectedGender)) _selectedGender = 'All';
          if (!_availableCategories.contains(_selectedCategory)) _selectedCategory = 'All';

          final filtered = _applyFilters(allStudents);

          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by name, roll, class, parent...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.withOpacity(0.15)),
                    ),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.04),
                  ),
                ),
              ),

              // Tappable Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    _buildTappableChip(
                      label: 'Class: $_selectedClass',
                      color: Colors.blue,
                      isActive: _selectedClass != 'All',
                      onTap: () => _showClassPicker(),
                    ),
                    const SizedBox(width: 6),
                    _buildTappableChip(
                      label: 'Gender: $_selectedGender',
                      color: Colors.purple,
                      isActive: _selectedGender != 'All',
                      onTap: () => _showGenderPicker(),
                    ),
                    const SizedBox(width: 6),
                    _buildTappableChip(
                      label: 'Category: $_selectedCategory',
                      color: Colors.teal,
                      isActive: _selectedCategory != 'All',
                      onTap: () => _showCategoryPicker(),
                    ),
                    const SizedBox(width: 6),
                    _buildTappableChip(
                      label: 'Sort: $_sortBy',
                      color: Colors.orange,
                      isActive: _sortBy != 'Name',
                      onTap: () => _showSortPicker(),
                    ),
                    if (_selectedClass != 'All' || _selectedGender != 'All' || _selectedCategory != 'All') ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedClass = 'All';
                          _selectedGender = 'All';
                          _selectedCategory = 'All';
                          _sortBy = 'Name';
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.red.withOpacity(0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.clear, size: 12, color: Colors.red),
                              SizedBox(width: 4),
                              Text('Clear', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Count Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.groups_rounded, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 8),
                    Text('Showing ${filtered.length} of ${allStudents.length} Students',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[700], fontSize: 13)),
                  ],
                ),
              ),

              // Student List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text('No students match filters', style: TextStyle(color: Colors.grey[500])),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => setState(() {
                                _selectedClass = 'All';
                                _selectedGender = 'All';
                                _selectedCategory = 'All';
                                _searchQuery = '';
                              }),
                              child: const Text('Clear all filters'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, index) {
                          final s = filtered[index];
                          return _StudentCard(
                            student: s,
                            index: index,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => StudentDetailScreen(student: s)),
                              );
                            },
                            onDelete: () => _confirmDelete(s),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Tappable filter chip ──
  Widget _buildTappableChip({
    required String label,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.15) : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color : color.withOpacity(0.15), width: isActive ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  // ── Popup pickers (appear near the chip) ──
  void _showClassPicker() {
    _showPopupPicker('Class', _availableClasses, _selectedClass, Colors.blue, (v) {
      setState(() => _selectedClass = v);
    });
  }

  void _showGenderPicker() {
    _showPopupPicker('Gender', _availableGenders, _selectedGender, Colors.purple, (v) {
      setState(() => _selectedGender = v);
    });
  }

  void _showCategoryPicker() {
    _showPopupPicker('Category', _availableCategories, _selectedCategory, Colors.teal, (v) {
      setState(() => _selectedCategory = v);
    });
  }

  void _showSortPicker() {
    _showPopupPicker('Sort', ['Name', 'Roll', 'Class'], _sortBy, Colors.orange, (v) {
      setState(() => _sortBy = v);
    });
  }

  void _showPopupPicker(String title, List<String> options, String current, Color color, void Function(String) onSelect) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Select $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = current == opt;
            return GestureDetector(
              onTap: () {
                onSelect(opt);
                Navigator.pop(ctx);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _confirmDelete(StudentModel s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Student?'),
        content: Text('Are you sure you want to remove ${s.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(studentRepositoryProvider).deleteStudentSoft(s.id);
      ref.invalidate(studentsListProvider);
      ref.invalidate(dashboardMetricsProvider);
    }
  }
}

// ── Student Card ──
class _StudentCard extends StatelessWidget {
  final StudentModel student;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _StudentCard({required this.student, required this.index, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isMale = student.gender.toLowerCase() == 'male';
    final genderColor = isMale ? Colors.blue : student.gender.toLowerCase() == 'female' ? Colors.pink : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: genderColor.withOpacity(0.1),
                child: Text(
                  student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                  style: TextStyle(fontWeight: FontWeight.bold, color: genderColor, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(student.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isMale ? Icons.male : student.gender.toLowerCase() == 'female' ? Icons.female : Icons.person,
                          size: 14, color: genderColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Roll: ${student.rollNumber} • Class ${student.classId} • Age ${student.age}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    if (student.parentName.isNotEmpty && student.parentName != 'Pending')
                      Text('Parent: ${student.parentName}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                  ],
                ),
              ),

              // Badges + Arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (student.category != null && student.category!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(student.category!, style: const TextStyle(fontSize: 9, color: Colors.teal, fontWeight: FontWeight.w600)),
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                        onPressed: onDelete,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
