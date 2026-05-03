import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import '../../models/student_model.dart';
import '../../core/constants/class_constants.dart';

/// Result of parsing an Excel file for student import.
class ExcelImportResult {
  final List<StudentModel> validStudents;
  final List<ExcelRowError> errors;
  final List<String> mappedColumns;
  final List<String> unmappedColumns;
  final int totalRows;

  const ExcelImportResult({
    required this.validStudents,
    required this.errors,
    required this.mappedColumns,
    required this.unmappedColumns,
    required this.totalRows,
  });
}

/// Represents a validation error for a specific row.
class ExcelRowError {
  final int rowIndex; // 0-based data row index (not counting header)
  final String field;
  final String message;
  final Map<String, String> rowData; // raw data for display

  const ExcelRowError({
    required this.rowIndex,
    required this.field,
    required this.message,
    this.rowData = const {},
  });
}

/// Service to parse Excel files and convert rows into StudentModel objects.
class ExcelImportService {
  ExcelImportService._();

  // ── Column name aliases → StudentModel field mapping ────────────────
  static const Map<String, List<String>> _columnAliases = {
    'name': ['name', 'student name', 'full name', 'student_name', 'fullname', 'student'],
    'rollNumber': ['roll', 'roll number', 'roll no', 'roll_number', 'rollno', 'roll_no'],
    'classId': ['class', 'class id', 'class_id', 'classid', 'grade', 'standard', 'std'],
    'phone': ['phone', 'mobile', 'contact', 'phone number', 'phone_number', 'mobile number', 'mobile_number', 'contact number'],
    'gender': ['gender', 'sex'],
    'dateOfBirth': ['dob', 'date of birth', 'date_of_birth', 'birth date', 'birthdate', 'birth_date', 'birthday'],
    'address': ['address', 'full address', 'full_address', 'residential address'],
    'parentName': ['father name', 'father_name', 'parent name', 'parent_name', 'father', 'fathername', 'guardian', 'guardian name'],
    'parentPhone': ['father phone', 'father_phone', 'parent phone', 'parent_phone', 'father mobile', 'guardian phone'],
    'motherName': ['mother name', 'mother_name', 'mother', 'mothername'],
    'motherPhone': ['mother phone', 'mother_phone', 'mother mobile'],
    'email': ['email', 'e-mail', 'email address', 'email_address', 'student email'],
    'category': ['category', 'caste category', 'reservation'],
    'caste': ['caste', 'sub caste', 'sub_caste'],
    'religion': ['religion'],
    'bloodGroup': ['blood group', 'blood_group', 'bloodgroup', 'bg'],
    'aadharNumber': ['aadhar', 'aadhar number', 'aadhar_number', 'aadhaar', 'aadhaar number', 'uid'],
    'city': ['city', 'town'],
    'state': ['state', 'province'],
    'pincode': ['pincode', 'pin code', 'pin_code', 'zip', 'zip code', 'postal code'],
    'previousSchool': ['previous school', 'previous_school', 'prev school', 'last school'],
    'previousClass': ['previous class', 'previous_class', 'prev class', 'last class'],
    'parentOccupation': ['father occupation', 'father_occupation', 'occupation', 'parent occupation', 'parent_occupation', 'guardian occupation'],
    'nationality': ['nationality'],
  };

  /// Required fields that must be present and non-empty.
  static const _requiredFields = [
    'name', 'rollNumber', 'classId', 'phone', 'gender', 'dateOfBirth',
  ];

  static const _validGenders = ['male', 'female', 'other'];
  static const _validCategories = ['general', 'obc', 'sc', 'st', 'ews'];

  // ── Main Parse Method ───────────────────────────────────────────────

  /// Parse an Excel file from bytes and return an ExcelImportResult.
  /// [existingRolls] — set of roll numbers already in the DB for duplicate detection.
  /// [deviceId] — device identifier for sync tracking.
  static ExcelImportResult parseExcelBytes({
    required Uint8List bytes,
    required Set<String> existingRolls,
    required String deviceId,
  }) {
    final excel = Excel.decodeBytes(bytes);

    // Use the first sheet
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName]!;

    if (sheet.maxRows < 2) {
      return const ExcelImportResult(
        validStudents: [],
        errors: [],
        mappedColumns: [],
        unmappedColumns: [],
        totalRows: 0,
      );
    }

    // ── Step 1: Map header columns ────────────────────────────────────
    final headerRow = sheet.rows[0];
    final Map<int, String> columnMapping = {}; // colIndex → field name
    final List<String> mappedColumns = [];
    final List<String> unmappedColumns = [];

    for (int col = 0; col < headerRow.length; col++) {
      final cell = headerRow[col];
      if (cell == null || cell.value == null) continue;

      final headerText = _getCellValueString(cell.value).toLowerCase()
          .replaceAll(RegExp(r"[''`]"), '')  // remove apostrophes
          .replaceAll(RegExp(r'\s+'), ' ');   // normalize whitespace

      String? matchedField;
      for (final entry in _columnAliases.entries) {
        if (entry.value.contains(headerText)) {
          matchedField = entry.key;
          break;
        }
      }

      if (matchedField != null) {
        columnMapping[col] = matchedField;
        mappedColumns.add('${cell.value} → $matchedField');
      } else {
        unmappedColumns.add(cell.value.toString());
      }
    }

    // ── Step 2: Parse data rows ───────────────────────────────────────
    final List<StudentModel> validStudents = [];
    final List<ExcelRowError> errors = [];
    final Set<String> importRolls = {}; // track duplicates within this file

    for (int rowIdx = 1; rowIdx < sheet.maxRows; rowIdx++) {
      final row = sheet.rows[rowIdx];

      // Build raw data map for this row
      final Map<String, String> rawData = {};
      for (final entry in columnMapping.entries) {
        final cell = (entry.key < row.length) ? row[entry.key] : null;
        if (cell != null && cell.value != null) {
          rawData[entry.value] = _getCellValueString(cell.value);
        }
      }

      // Skip completely empty rows
      if (rawData.values.every((v) => v.isEmpty)) continue;

      final dataRowIdx = rowIdx - 1; // 0-based data row index

      // ── Validate required fields ──
      bool hasError = false;
      for (final field in _requiredFields) {
        if (!rawData.containsKey(field) || rawData[field]!.isEmpty) {
          errors.add(ExcelRowError(
            rowIndex: dataRowIdx,
            field: field,
            message: 'Missing required field: $field',
            rowData: rawData,
          ));
          hasError = true;
        }
      }
      if (hasError) continue;

      // ── Validate class ID ──
      final classId = rawData['classId']!;
      if (!ClassConstants.allClasses.contains(classId)) {
        errors.add(ExcelRowError(
          rowIndex: dataRowIdx,
          field: 'classId',
          message: 'Invalid class "$classId". Use: Nursery, KG1, KG2, 1-12',
          rowData: rawData,
        ));
        continue;
      }

      // ── Validate gender ──
      final gender = rawData['gender']!;
      final normalizedGender = _capitalizeFirst(gender.toLowerCase());
      if (!_validGenders.contains(gender.toLowerCase())) {
        errors.add(ExcelRowError(
          rowIndex: dataRowIdx,
          field: 'gender',
          message: 'Invalid gender "$gender". Use: Male, Female, Other',
          rowData: rawData,
        ));
        continue;
      }

      // ── Parse date of birth ──
      DateTime? dob;
      try {
        dob = _parseDate(rawData['dateOfBirth']!);
      } catch (_) {
        errors.add(ExcelRowError(
          rowIndex: dataRowIdx,
          field: 'dateOfBirth',
          message: 'Cannot parse date "${rawData['dateOfBirth']}". Use DD/MM/YYYY or YYYY-MM-DD',
          rowData: rawData,
        ));
        continue;
      }

      // ── Check duplicate roll numbers ──
      final rollNumber = rawData['rollNumber']!;
      if (existingRolls.contains(rollNumber)) {
        errors.add(ExcelRowError(
          rowIndex: dataRowIdx,
          field: 'rollNumber',
          message: 'Roll number "$rollNumber" already exists in database',
          rowData: rawData,
        ));
        continue;
      }
      if (importRolls.contains(rollNumber)) {
        errors.add(ExcelRowError(
          rowIndex: dataRowIdx,
          field: 'rollNumber',
          message: 'Duplicate roll number "$rollNumber" in this file',
          rowData: rawData,
        ));
        continue;
      }
      importRolls.add(rollNumber);

      // ── Validate category if provided ──
      final category = rawData['category'];
      if (category != null && category.isNotEmpty && !_validCategories.contains(category.toLowerCase())) {
        // Warn but don't block — just use as-is
        debugPrint('Warning: Row $dataRowIdx has unrecognized category "$category"');
      }

      // ── Build StudentModel ──
      try {
        final student = StudentModel(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_$dataRowIdx',
          name: rawData['name']!,
          rollNumber: rollNumber,
          classId: classId,
          email: _nullIfEmpty(rawData['email']),
          phone: rawData['phone']!,
          parentName: rawData['parentName'] ?? 'Unknown',
          parentPhone: rawData['parentPhone'] ?? 'N/A',
          parentOccupation: _nullIfEmpty(rawData['parentOccupation']),
          motherName: _nullIfEmpty(rawData['motherName']),
          motherPhone: _nullIfEmpty(rawData['motherPhone']),
          dateOfBirth: dob,
          gender: normalizedGender,
          caste: _nullIfEmpty(rawData['caste']),
          category: _nullIfEmpty(category != null ? _capitalizeFirst(category) : null),
          religion: _nullIfEmpty(rawData['religion']),
          nationality: rawData['nationality'] ?? 'Indian',
          bloodGroup: _nullIfEmpty(rawData['bloodGroup']),
          address: rawData['address'] ?? 'N/A',
          city: _nullIfEmpty(rawData['city']),
          state: _nullIfEmpty(rawData['state']),
          pincode: _nullIfEmpty(rawData['pincode']),
          previousSchool: _nullIfEmpty(rawData['previousSchool']),
          previousClass: _nullIfEmpty(rawData['previousClass']),
          aadharNumber: _nullIfEmpty(rawData['aadharNumber']),
          admissionDate: DateTime.now(),
          status: 'approved',
          deviceId: deviceId,
        );
        validStudents.add(student);
      } catch (e) {
        errors.add(ExcelRowError(
          rowIndex: dataRowIdx,
          field: 'general',
          message: 'Failed to create student: $e',
          rowData: rawData,
        ));
      }
    }

    return ExcelImportResult(
      validStudents: validStudents,
      errors: errors,
      mappedColumns: mappedColumns,
      unmappedColumns: unmappedColumns,
      totalRows: sheet.maxRows - 1, // exclude header
    );
  }

  // ── Date Parsing Helpers ────────────────────────────────────────────

  static DateTime _parseDate(String value) {
    // Try Excel serial date number
    final serial = double.tryParse(value);
    if (serial != null && serial > 25000) {
      // Excel serial date: days since 1899-12-30
      return DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
    }

    // Try ISO format: YYYY-MM-DD
    if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(value)) {
      return DateTime.parse(value);
    }

    // Try DD/MM/YYYY or DD-MM-YYYY
    final parts = value.split(RegExp(r'[/\-.]'));
    if (parts.length == 3) {
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
        return DateTime(year, month, day);
      }
    }

    throw FormatException('Cannot parse date: $value');
  }

  static String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  static String _getCellValueString(CellValue? value) {
    if (value == null) return '';
    
    // In excel 4.x, value properties depend on the subtype.
    if (value is TextCellValue) {
      return value.value.text?.toString().trim() ?? '';
    } else if (value is IntCellValue) {
      return value.value.toString().trim();
    } else if (value is DoubleCellValue) {
      String str = value.value.toString().trim();
      if (str.endsWith('.0')) {
        str = str.substring(0, str.length - 2);
      }
      return str;
    } else if (value is BoolCellValue) {
      return value.value.toString().trim();
    } else if (value is DateCellValue) {
      return "${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}";
    }
    
    // Fallback if type isn't matched
    String str = value.toString().trim();
    // Sometimes toString() yields something like "TextCellValue(hello)"
    if (str.contains('CellValue(')) {
      final RegExp regExp = RegExp(r'CellValue\((.*)\)');
      final match = regExp.firstMatch(str);
      if (match != null && match.groupCount >= 1) {
        str = match.group(1) ?? str;
      }
    }
    
    if (str.endsWith('.0')) {
      str = str.substring(0, str.length - 2);
    }
    return str.trim();
  }

  static String? _nullIfEmpty(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    return s.trim();
  }
}
