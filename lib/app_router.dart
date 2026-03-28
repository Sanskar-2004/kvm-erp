import 'package:flutter/material.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/students/screens/students_screen.dart';
import 'features/attendance/screens/attendance_screen.dart';
import 'features/timetable/screens/timetable_screen.dart';
import 'features/marks/screens/marks_screen.dart';
import 'features/fees/screens/fees_screen.dart';
import 'features/notices/screens/notices_screen.dart';
import 'features/ai/screens/ai_chat_screen.dart';

class AppRouter {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String students = '/students';
  static const String attendance = '/attendance';
  static const String timetable = '/timetable';
  static const String marks = '/marks';
  static const String fees = '/fees';
  static const String notices = '/notices';
  static const String ai = '/ai';

  static Map<String, WidgetBuilder> get routes => {
        login: (_) => const LoginScreen(),
        dashboard: (_) => const DashboardScreen(),
        students: (_) => const StudentsScreen(),
        attendance: (_) => const AttendanceScreen(),
        timetable: (_) => const TimetableScreen(),
        marks: (_) => const MarksScreen(),
        fees: (_) => const FeesScreen(),
        notices: (_) => const NoticesScreen(),
        ai: (_) => const AiChatScreen(),
      };
}
