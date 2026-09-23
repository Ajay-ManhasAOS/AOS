import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'customer_lookup_screen.dart';
import 'expenses_screen.dart';
import 'leaves_screen.dart';
import 'consumables_screen.dart';
import 'branch_messages_list_screen.dart';
import 'delegated_tasks_screen.dart';
import '../change_password_screen.dart';

class OperatorDashboard extends StatelessWidget {
  const OperatorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operator Dashboard'),
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
              leading: const Icon(Icons.person_search),
              title: const Text('Find / Add Customer'),
              subtitle: const Text('Look up a customer by mobile or name, or add a new one'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerLookupScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Expenses'),
              subtitle: const Text('Log branch expenses for approval'),
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
              subtitle: const Text('Request leave and track approval status'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeavesScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Consumables Log'),
              subtitle: const Text('Log daily printing/paper usage'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConsumablesScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Messages'),
              subtitle: const Text('Send/receive notes with other branches'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BranchMessagesListScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.move_to_inbox),
              title: const Text('Delegated to Me'),
              subtitle: const Text('Tasks delegated from other branches'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DelegatedTasksScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}