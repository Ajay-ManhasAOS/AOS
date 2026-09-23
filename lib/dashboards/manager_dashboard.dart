import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'expenses_screen.dart';
import 'leaves_screen.dart';
import 'messages_screen.dart';
import '../change_password_screen.dart';
import 'branch_messages_list_screen.dart';

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_reset),
            tooltip: 'Change Password',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Expenses'),
              subtitle: const Text('Review and approve branch expenses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpensesScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_busy),
              title: const Text('Leaves'),
              subtitle: const Text('Review and approve staff leave requests'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeavesScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Messages'),
              subtitle: const Text('Send/receive notes with admin'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BranchMessagesListScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}