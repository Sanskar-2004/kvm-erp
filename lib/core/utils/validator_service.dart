class ValidatorService {
  ValidatorService._();

  /// Validates standard class assignment rules
  static void validateClassAssignment(String className, String? stream) {
    if (className.trim().isEmpty) {
      throw ArgumentError('Class name cannot be empty.');
    }
    
    final classNum = int.tryParse(className);
    if (classNum != null) {
      if (classNum >= 9 && stream == null) {
        throw ArgumentError('Stream (Science, Commerce, Arts) is strictly required for class $classNum.');
      }
      if (classNum < 9 && stream != null) {
        throw ArgumentError('Stream is not applicable for junior classes.');
      }
    }
  }

  /// Validates marks constraint bounding based on total marks
  static void validateMarks(double obtained, double total) {
    if (total <= 0) {
      throw ArgumentError('Total marks must be greater than zero.');
    }
    if (obtained < 0) {
      throw ArgumentError('Obtained marks cannot be negative.');
    }
    if (obtained > total) {
      throw ArgumentError('Obtained marks ($obtained) cannot exceed total marks ($total).');
    }
  }

  /// Validates standard student profile data
  static void validateStudent(String name, String rollNumber, String phone) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Student name is required.');
    }
    if (rollNumber.trim().isEmpty) {
      throw ArgumentError('Roll number is required.');
    }
    if (phone.length < 10) {
      throw ArgumentError('Phone number must be at least 10 digits.');
    }
  }

  /// Validates standard attendance entry logic
  static void validateAttendance(DateTime date, int? periodNumber) {
    if (date.isAfter(DateTime.now())) {
      throw ArgumentError('Attendance cannot be marked for future dates.');
    }
    if (periodNumber != null && periodNumber <= 0) {
      throw ArgumentError('Period number must be positive.');
    }
  }
}
