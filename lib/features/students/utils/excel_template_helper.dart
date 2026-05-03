import 'package:flutter/material.dart';

/// Helper that shows users the expected Excel format for bulk student import.
class ExcelTemplateHelper {
  ExcelTemplateHelper._();

  static const requiredColumns = [
    {'header': 'Name', 'example': 'Aarav Sharma', 'description': 'Student full name'},
    {'header': 'Roll Number', 'example': '001', 'description': 'Class roll number'},
    {'header': 'Class', 'example': '10', 'description': 'Nursery, KG1, KG2, 1-12'},
    {'header': 'Phone', 'example': '9876543210', 'description': 'Student/family phone'},
    {'header': 'Gender', 'example': 'Male', 'description': 'Male, Female, or Other'},
    {'header': 'DOB', 'example': '15/05/2010', 'description': 'DD/MM/YYYY or YYYY-MM-DD'},
    {'header': 'Address', 'example': '123, Model Town', 'description': 'Full residential address'},
    {'header': 'Father Name', 'example': 'Rajesh Sharma', 'description': 'Father/guardian name'},
  ];

  static const optionalColumns = [
    {'header': 'Father Phone', 'example': '9876543211'},
    {'header': 'Mother Name', 'example': 'Sunita Sharma'},
    {'header': 'Mother Phone', 'example': '9876543212'},
    {'header': 'Email', 'example': 'aarav@email.com'},
    {'header': 'Category', 'example': 'General'},
    {'header': 'Caste', 'example': 'Brahmin'},
    {'header': 'Religion', 'example': 'Hindu'},
    {'header': 'Blood Group', 'example': 'B+'},
    {'header': 'Aadhar Number', 'example': '123456789012'},
    {'header': 'City', 'example': 'Bhopal'},
    {'header': 'State', 'example': 'Madhya Pradesh'},
    {'header': 'Pincode', 'example': '462001'},
    {'header': 'Previous School', 'example': 'DPS School'},
    {'header': 'Previous Class', 'example': '9'},
    {'header': 'Father Occupation', 'example': 'Engineer'},
    {'header': 'Nationality', 'example': 'Indian'},
  ];

  /// Shows a dialog explaining the Excel template format.
  static void showTemplateGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Excel Template Guide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('How to format your Excel file', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tips
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: Colors.blue),
                        SizedBox(width: 6),
                        Text('Tips', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text('• First row must be column headers', style: TextStyle(fontSize: 12)),
                    Text('• Column names are flexible (e.g., "Student Name" or "Name" both work)', style: TextStyle(fontSize: 12)),
                    Text('• Extra columns are safely ignored', style: TextStyle(fontSize: 12)),
                    Text('• Use .xlsx format (not .xls or .csv)', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Required columns
              const Text('Required Columns', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 8),
              ...requiredColumns.map((col) => _columnTile(
                col['header']!, col['example']!, col['description']!, true,
              )),

              const SizedBox(height: 20),
              const Text('Optional Columns', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              ...optionalColumns.map((col) => _columnTile(
                col['header']!, col['example']!, null, false,
              )),

              const SizedBox(height: 20),

              // Class naming note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                        SizedBox(width: 6),
                        Text('Class Values', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text('Use exactly: Nursery, KG1, KG2, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12',
                        style: TextStyle(fontSize: 12)),
                    Text('Do NOT use "Class 10" or "X" — just the number or name.',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _columnTile(String header, String example, String? description, bool required) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: required ? Colors.red.withOpacity(0.03) : Colors.grey.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: required ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            required ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: required ? Colors.red : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(header, style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: required ? Colors.red[700] : Colors.black87,
                )),
                if (description != null)
                  Text(description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(example, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blueGrey)),
          ),
        ],
      ),
    );
  }
}
