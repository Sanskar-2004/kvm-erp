import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/staff_repository.dart';
import '../../../models/staff_model.dart';
import 'add_staff_screen.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  String _selectedRole = 'all';

  final _roles = [
    'all', 'teacher', 'driver', 'peon', 'accountant', 
    'principal', 'librarian', 'security'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Directory'),
        backgroundColor: Colors.indigo[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddStaffScreen()),
              );
              if (result == true) {
                setState(() {}); // refresh
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Filter Row
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _roles.map((role) {
                  final isSelected = _selectedRole == role;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(role.toUpperCase(), style: TextStyle(
                        color: isSelected ? Colors.white : Colors.indigo,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      )),
                      selectedColor: Colors.indigo[600],
                      checkmarkColor: Colors.white,
                      onSelected: (val) {
                        setState(() => _selectedRole = role);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          Expanded(
            child: FutureBuilder<List<StaffModel>>(
              future: _selectedRole == 'all' 
                  ? ref.read(staffRepositoryProvider).getAllStaff()
                  : ref.read(staffRepositoryProvider).getStaffByRole(_selectedRole),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final staff = snapshot.data ?? [];
                if (staff.isEmpty) {
                  return Center(
                    child: Text('No staff found for role: $_selectedRole', 
                      style: TextStyle(color: Colors.grey[600]))
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: staff.length,
                  itemBuilder: (context, index) {
                    final member = staff[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: member.canLogin ? Colors.green[100] : Colors.grey[200],
                          child: Icon(
                            Icons.person, 
                            color: member.canLogin ? Colors.green[700] : Colors.grey[600]
                          ),
                        ),
                        title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${member.role.toUpperCase()} ${member.department != null ? '• ${member.department}' : ''}\n${member.phone ?? 'No Phone'}'),
                        isThreeLine: true,
                        trailing: member.canLogin 
                          ? const Icon(Icons.key_rounded, color: Colors.amber, size: 20)
                          : const SizedBox.shrink(),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo[600],
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddStaffScreen()),
          );
          if (result == true) {
            setState(() {});
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Staff'),
      ),
    );
  }
}
