import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/student_repository.dart';
import '../../dashboard/repositories/dashboard_repository.dart';
import '../../../../models/student_model.dart';
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
  String _sortBy = 'Name'; // Name, Roll, Class
  String _searchQuery = '';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFilterSheet(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by name, roll number...',
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

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('Class: $_selectedClass', Colors.blue),
                const SizedBox(width: 6),
                _buildFilterChip('Gender: $_selectedGender', Colors.purple),
                const SizedBox(width: 6),
                _buildFilterChip('Sort: $_sortBy', Colors.orange),
              ],
            ),
          ),

          // Student Count Banner
          studentsAsync.when(
            data: (students) {
              final filtered = _applyFilters(students);
              return Container(
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
                    Text('${filtered.length} Students',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue[700], fontSize: 13)),
                    const Spacer(),
                    Text('Total: ${students.length}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Student List
          Expanded(
            child: studentsAsync.when(
              data: (students) {
                final filtered = _applyFilters(students);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('No students found', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, index) {
                    final s = filtered[index];
                    return _StudentCard(
                      student: s,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StudentDetailScreen(student: s)),
                      ),
                      onDelete: () async {
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
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  List<StudentModel> _applyFilters(List<StudentModel> students) {
    var filtered = students.where((s) {
      if (_selectedClass != 'All' && s.classId != _selectedClass) return false;
      if (_selectedGender != 'All' && s.gender.toLowerCase() != _selectedGender.toLowerCase()) return false;
      if (_selectedCategory != 'All' && (s.category ?? '').toLowerCase() != _selectedCategory.toLowerCase()) return false;
      if (_searchQuery.isNotEmpty) {
        return s.name.toLowerCase().contains(_searchQuery) ||
               s.rollNumber.toLowerCase().contains(_searchQuery) ||
               s.parentName.toLowerCase().contains(_searchQuery);
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case 'Name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
      case 'Roll':
        filtered.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
      case 'Class':
        filtered.sort((a, b) => a.classId.compareTo(b.classId));
    }
    return filtered;
  }

  Widget _buildFilterChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Filter & Sort', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setSheetState(() {
                        _selectedClass = 'All';
                        _selectedGender = 'All';
                        _selectedCategory = 'All';
                        _sortBy = 'Name';
                      });
                      setState(() {});
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Class', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: ['All', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'].map((c) {
                  final isSelected = _selectedClass == c;
                  return ChoiceChip(
                    label: Text(c == 'All' ? 'All' : 'Class $c', style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                    selected: isSelected,
                    selectedColor: Colors.blue[700],
                    onSelected: (_) {
                      setSheetState(() => _selectedClass = c);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              const Text('Gender', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: ['All', 'Male', 'Female', 'Other'].map((g) {
                  final isSelected = _selectedGender == g;
                  return ChoiceChip(
                    label: Text(g, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                    selected: isSelected,
                    selectedColor: Colors.purple,
                    onSelected: (_) {
                      setSheetState(() => _selectedGender = g);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              const Text('Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: ['All', 'General', 'OBC', 'SC', 'ST', 'EWS'].map((c) {
                  final isSelected = _selectedCategory == c;
                  return ChoiceChip(
                    label: Text(c, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                    selected: isSelected,
                    selectedColor: Colors.teal,
                    onSelected: (_) {
                      setSheetState(() => _selectedCategory = c);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: ['Name', 'Roll', 'Class'].map((s) {
                  final isSelected = _sortBy == s;
                  return ChoiceChip(
                    label: Text(s, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                    selected: isSelected,
                    selectedColor: Colors.orange,
                    onSelected: (_) {
                      setSheetState(() => _sortBy = s);
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Student Card Widget ──
class _StudentCard extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _StudentCard({required this.student, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final genderIcon = student.gender.toLowerCase() == 'male' ? Icons.male : Icons.female;
    final genderColor = student.gender.toLowerCase() == 'male' ? Colors.blue : Colors.pink;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: genderColor.withOpacity(0.1),
          child: Text(student.name[0].toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold, color: genderColor)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(student.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            Icon(genderIcon, size: 14, color: genderColor),
          ],
        ),
        subtitle: Text(
          'Roll: ${student.rollNumber} • Class ${student.classId} • Age ${student.age}',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (student.category != null && student.category!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(student.category!, style: const TextStyle(fontSize: 9, color: Colors.teal)),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
