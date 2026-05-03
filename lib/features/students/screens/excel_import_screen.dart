import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../../services/excel/excel_import_service.dart';
import '../repositories/student_repository.dart';
import '../../../services/db/sqlite_service.dart';
import '../../../models/student_model.dart';
import '../../dashboard/repositories/dashboard_repository.dart';
import '../utils/excel_template_helper.dart';
import 'students_screen.dart';

class ExcelImportScreen extends ConsumerStatefulWidget {
  const ExcelImportScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends ConsumerState<ExcelImportScreen> {
  // State
  _ImportPhase _phase = _ImportPhase.pickFile;
  ExcelImportResult? _result;
  String? _fileName;
  bool _isProcessing = false;
  int _importedCount = 0;
  int _skippedCount = 0;

  // Track which valid rows are selected for import
  late List<bool> _selectedRows;

  // ── File Picking ────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _showError('Could not read file data.');
        return;
      }

      setState(() {
        _isProcessing = true;
        _fileName = file.name;
      });

      await _parseExcel(file.bytes!);
    } catch (e) {
      _showError('Error picking file: $e');
      setState(() => _isProcessing = false);
    }
  }

  // ── Excel Parsing ───────────────────────────────────────────────────

  Future<void> _parseExcel(Uint8List bytes) async {
    try {
      // Get existing roll numbers for duplicate detection
      final db = await SQLiteService().database;
      final existing = await db.query('students',
          columns: ['roll_number'],
          where: 'is_deleted = 0');
      final existingRolls = existing.map((r) => r['roll_number'].toString()).toSet();

      final result = ExcelImportService.parseExcelBytes(
        bytes: bytes,
        existingRolls: existingRolls,
        deviceId: 'device_${DateTime.now().millisecondsSinceEpoch}',
      );

      setState(() {
        _result = result;
        _selectedRows = List.filled(result.validStudents.length, true);
        _phase = _ImportPhase.preview;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Error parsing Excel: $e');
    }
  }

  // ── Bulk Import ─────────────────────────────────────────────────────

  Future<void> _importStudents() async {
    if (_result == null) return;

    final selected = <StudentModel>[];
    for (int i = 0; i < _result!.validStudents.length; i++) {
      if (_selectedRows[i]) selected.add(_result!.validStudents[i]);
    }

    if (selected.isEmpty) {
      _showError('No students selected for import.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final count = await ref.read(studentRepositoryProvider).bulkAddStudents(selected);

      setState(() {
        _importedCount = count;
        _skippedCount = _result!.totalRows - count;
        _phase = _ImportPhase.done;
        _isProcessing = false;
      });

      // Invalidate providers
      ref.invalidate(studentsListProvider);
      ref.invalidate(dashboardMetricsProvider);
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError('Import failed: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Import from Excel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Template Guide',
            onPressed: () => ExcelTemplateHelper.showTemplateGuide(context),
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : switch (_phase) {
              _ImportPhase.pickFile => _buildPickPhase(),
              _ImportPhase.preview => _buildPreviewPhase(),
              _ImportPhase.done => _buildDonePhase(),
            },
    );
  }

  // ── Phase 1: Pick File ──────────────────────────────────────────────

  Widget _buildPickPhase() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.upload_file_rounded, size: 56, color: Colors.green[600]),
            ),
            const SizedBox(height: 24),
            const Text(
              'Import Students from Excel',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a .xlsx file with student data.\nThe system will auto-detect columns and validate each row.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Select Excel File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => ExcelTemplateHelper.showTemplateGuide(context),
              icon: const Icon(Icons.table_chart_rounded, size: 18),
              label: const Text('View Template Guide'),
              style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
            ),
          ],
        ),
      ),
    );
  }

  // ── Phase 2: Preview ────────────────────────────────────────────────

  Widget _buildPreviewPhase() {
    final result = _result!;
    final selectedCount = _selectedRows.where((s) => s).length;

    return Column(
      children: [
        // ── File Info + Column Mapping Summary ──
        Container(
          width: double.infinity,
          color: Colors.blue.withOpacity(0.04),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.insert_drive_file_rounded, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _fileName ?? 'Unknown file',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _phase = _ImportPhase.pickFile;
                      _result = null;
                    }),
                    child: const Text('Change', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _infoBadge('${result.totalRows} rows', Colors.blue),
                  _infoBadge('${result.validStudents.length} valid', Colors.green),
                  if (result.errors.isNotEmpty)
                    _infoBadge('${result.errors.length} errors', Colors.red),
                  _infoBadge('${result.mappedColumns.length} columns mapped', Colors.purple),
                  if (result.unmappedColumns.isNotEmpty)
                    _infoBadge('${result.unmappedColumns.length} ignored', Colors.grey),
                ],
              ),
            ],
          ),
        ),

        // ── Column mapping detail (expandable) ──
        if (result.mappedColumns.isNotEmpty || result.unmappedColumns.isNotEmpty)
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14),
            title: const Text('Column Mapping', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            children: [
              ...result.mappedColumns.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(m, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )),
              if (result.unmappedColumns.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('Ignored: ${result.unmappedColumns.join(', ')}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ],
          ),

        // ── Error rows ──
        if (result.errors.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(0.15)),
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                '${result.errors.length} rows with errors (will be skipped)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red),
              ),
              childrenPadding: const EdgeInsets.only(top: 6),
              children: result.errors.take(20).map((err) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Row ${err.rowIndex + 1}: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                    Expanded(
                      child: Text(err.message, style: const TextStyle(fontSize: 11, color: Colors.red)),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),

        // ── Valid students table ──
        Expanded(
          child: result.validStudents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 12),
                      const Text('No valid students found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text('Check the errors above and fix your Excel file.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(10),
                    child: DataTable(
                      headingRowHeight: 40,
                      dataRowMinHeight: 36,
                      dataRowMaxHeight: 44,
                      columnSpacing: 14,
                      horizontalMargin: 10,
                      headingRowColor: WidgetStateProperty.all(Colors.blue.withOpacity(0.06)),
                      columns: const [
                        DataColumn(label: Text('✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('#', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Roll', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Class', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Gender', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Phone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Father', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('DOB', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                      rows: List.generate(result.validStudents.length, (i) {
                        final s = result.validStudents[i];
                        return DataRow(
                          selected: _selectedRows[i],
                          color: WidgetStateProperty.resolveWith((states) {
                            if (!_selectedRows[i]) return Colors.grey.withOpacity(0.05);
                            return null;
                          }),
                          cells: [
                            DataCell(Checkbox(
                              value: _selectedRows[i],
                              onChanged: (v) => setState(() => _selectedRows[i] = v ?? true),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            )),
                            DataCell(Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                            DataCell(Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            DataCell(Text(s.rollNumber, style: const TextStyle(fontSize: 12))),
                            DataCell(Text(s.classId, style: const TextStyle(fontSize: 12))),
                            DataCell(Text(s.gender, style: const TextStyle(fontSize: 12))),
                            DataCell(Text(s.phone, style: const TextStyle(fontSize: 12))),
                            DataCell(Text(s.parentName, style: const TextStyle(fontSize: 12))),
                            DataCell(Text('${s.dateOfBirth.day}/${s.dateOfBirth.month}/${s.dateOfBirth.year}',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(SizedBox(
                              width: 150,
                              child: Text(s.address, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            )),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
        ),

        // ── Import button bar ──
        if (result.validStudents.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                // Select/Deselect all
                TextButton.icon(
                  onPressed: () {
                    final allSelected = _selectedRows.every((s) => s);
                    setState(() {
                      for (int i = 0; i < _selectedRows.length; i++) {
                        _selectedRows[i] = !allSelected;
                      }
                    });
                  },
                  icon: Icon(
                    _selectedRows.every((s) => s) ? Icons.deselect : Icons.select_all,
                    size: 18,
                  ),
                  label: Text(
                    _selectedRows.every((s) => s) ? 'Deselect All' : 'Select All',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const Spacer(),
                Text(
                  '$selectedCount selected',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: selectedCount > 0 ? _importStudents : null,
                  icon: const Icon(Icons.file_download_done_rounded, size: 18),
                  label: Text('Import $selectedCount Students'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Phase 3: Done ───────────────────────────────────────────────────

  Widget _buildDonePhase() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 60, color: Colors.green),
            ),
            const SizedBox(height: 24),
            const Text(
              'Import Complete!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statBox('$_importedCount', 'Imported', Colors.green),
                const SizedBox(width: 16),
                _statBox('$_skippedCount', 'Skipped', Colors.orange),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sync_rounded, size: 16, color: Colors.blue),
                  SizedBox(width: 6),
                  Text(
                    'Students will sync to server automatically.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.people_rounded),
              label: const Text('View Students'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────

  Widget _infoBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statBox(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

enum _ImportPhase { pickFile, preview, done }
