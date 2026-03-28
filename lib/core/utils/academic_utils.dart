class AcademicUtils {
  AcademicUtils._();

  /// Determines if a class is considered junior (e.g. Class 1-8).
  /// Customize the parsing logic based on exact school requirements.
  static bool isJuniorClass(String className) {
    // Handling Roman numerals or generic numbers like 'IV', 'X', '10', '1'.
    final cleanName = className.trim().toUpperCase();

    // Map common strings to int
    int num = -1;
    if (int.tryParse(cleanName) != null) {
      num = int.parse(cleanName);
    } else {
      switch (cleanName) {
        case 'I': num = 1; break;
        case 'II': num = 2; break;
        case 'III': num = 3; break;
        case 'IV': num = 4; break;
        case 'V': num = 5; break;
        case 'VI': num = 6; break;
        case 'VII': num = 7; break;
        case 'VIII': num = 8; break;
        case 'IX': num = 9; break;
        case 'X': num = 10; break;
        case 'XI': num = 11; break;
        case 'XII': num = 12; break;
        case 'NURSERY':
        case 'LKG':
        case 'UKG':
        case 'PRE-PRIMARY':
          num = 0;
          break;
      }
    }

    // Usually, up to 8th standard is considered junior
    if (num >= 0 && num <= 8) {
      return true;
    }
    return false;
  }

  /// Calculates percentage from marks obtained and total marks
  static double calculatePercentage(double marksObtained, double totalMarks) {
    if (totalMarks <= 0) return 0.0;
    final percentage = (marksObtained / totalMarks) * 100;
    return double.parse(percentage.toStringAsFixed(2)); // round to 2 decimals
  }

  /// Generates a grade based on the given percentage
  static String generateGrade(double percentage) {
    if (percentage >= 91) return 'A1';
    if (percentage >= 81) return 'A2';
    if (percentage >= 71) return 'B1';
    if (percentage >= 61) return 'B2';
    if (percentage >= 51) return 'C1';
    if (percentage >= 41) return 'C2';
    if (percentage >= 33) return 'D';
    return 'E'; // E stands for Failed in standard CBSE boards
  }
}
