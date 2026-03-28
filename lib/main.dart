import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/widgets/main_layout.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final authRepo = AuthRepository();
  final session = await authRepo.getSession();

  runApp(
    ProviderScope(
      child: KVMErpApp(initialSession: session),
    ),
  );
}

class KVMErpApp extends ConsumerStatefulWidget {
  final AuthSession? initialSession;

  const KVMErpApp({Key? key, this.initialSession}) : super(key: key);

  @override
  ConsumerState<KVMErpApp> createState() => _KVMErpAppState();
}

class _KVMErpAppState extends ConsumerState<KVMErpApp> {
  @override
  void initState() {
    super.initState();
    // Set the role provider from cached session on startup
    if (widget.initialSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(userRoleProvider.notifier).state = UserRole.values
            .firstWhere((e) => e.name == widget.initialSession!.role,
                orElse: () => UserRole.student);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KVM ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: widget.initialSession != null
          ? const MainLayout()
          : const LoginScreen(),
    );
  }
}

