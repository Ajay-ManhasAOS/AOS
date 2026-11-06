import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'login_screen.dart';
import 'dashboards/admin_dashboard.dart';
import 'dashboards/manager_dashboard.dart';
import 'dashboards/operator_dashboard.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://mfpkzoqmhyprbhtelblb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1mcGt6b3FtaHlwcmJodGVsYmxiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkxMjAwNzAsImV4cCI6MjEwNDY5NjA3MH0.K6oUqdoKISjR5Pzi7KiJ_go7cjq4QSu9gnVtz_rpGYg',
  );
  runApp(const ProviderScope(child: AOSApp()));
}

final supabase = Supabase.instance.client;

class AOSApp extends StatelessWidget {
  const AOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AOS',
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        return const RoleRouter();
      },
    );
  }
}

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  Map<String, dynamic>? _staffRow;
  bool _loading = true;
  bool _blocked = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final userId = supabase.auth.currentUser!.id;
    final response = await supabase
        .from('staff')
        .select('role, branch_id, status')
        .eq('id', userId)
        .maybeSingle();

    final status = response?['status'] as String?;
    final blocked = response != null &&
        response['role'] != 'admin' &&
        (status == 'resigned' || status == 'suspended');

    if (!blocked && response != null && (response['role'] == 'operator' || response['role'] == 'manager')) {
      await _markAttendance(userId, response['branch_id']);
    }

    setState(() {
      _staffRow = response;
      _blocked = blocked;
      _loading = false;
    });
  }

  Future<void> _markAttendance(String staffId, String branchId) async {
    String message;
    bool isLate = false;
    try {
      final row = await supabase
          .from('attendance')
          .insert({
            'staff_id': staffId,
            'branch_id': branchId,
          })
          .select('is_late, minutes_late')
          .single();
      message = 'Attendance marked for today';
      if (row['is_late'] == true) {
        isLate = true;
        final now = DateTime.now();
        final monthStart =
            DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
        final lates = await supabase
            .from('attendance')
            .select('id')
            .eq('staff_id', staffId)
            .eq('is_late', true)
            .gte('attendance_date', monthStart);
        final cfg = await supabase
            .from('attendance_settings')
            .select('shift_start')
            .eq('id', 1)
            .maybeSingle();
        final shift = (cfg?['shift_start'] ?? '09:50').toString().substring(0, 5);
        message = 'You are ${row['minutes_late']} minutes late (shift starts at $shift). '
            'Late marks this month: ${lates.length}';
      }
    } on PostgrestException catch (e) {
      message = e.code == '23505'
          ? 'Attendance already marked for today'
          : 'Could not mark attendance: ${e.message}';
    } catch (e) {
      message = 'Could not mark attendance: $e';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: isLate ? 10 : 3),
          backgroundColor: isLate ? Colors.orange.shade800 : null,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_blocked) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text('Your account is not active.'),
              const Text('Please contact the administrator.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => supabase.auth.signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      );
    }
    final role = _staffRow?['role'] as String?;
    switch (role) {
      case 'admin':
        return const AdminDashboard();
      case 'manager':
        return const ManagerDashboard();
      case 'operator':
        return const OperatorDashboard();
      default:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No staff record found for this account.'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => supabase.auth.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        );
    }
  }
}
