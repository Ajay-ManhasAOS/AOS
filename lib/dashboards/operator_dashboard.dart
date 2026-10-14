import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'customer_lookup_screen.dart';
import 'expenses_screen.dart';
import 'leaves_screen.dart';
import 'consumables_screen.dart';
import 'branch_messages_list_screen.dart';
import 'delegated_tasks_screen.dart';
import '../change_password_screen.dart';
import 'sales_screen.dart';
import 'my_applications_screen.dart';
import 'services_screen.dart';

Widget _lead(IconData icon, Color color) => CircleAvatar(
      backgroundColor: color.withOpacity(0.12),
      child: Icon(icon, color: color),
    );

Widget _stat(String label, int value, Color color) => Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('$value',
                style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );

class OperatorDashboard extends StatelessWidget {
  const OperatorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text('Operator Dashboard'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
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
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.teal.shade400],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Consumer(builder: (context, ref, _) {
              final rows = ref.watch(myAgingProvider).maybeWhen(
                    data: (d) => d,
                    orElse: () => <Map<String, dynamic>>[],
                  );
              final pending =
                  rows.where((r) => r['status'] == 'initiated').length;
              final inProc =
                  rows.where((r) => r['status'] == 'under_process').length;
              final overdue =
                  rows.where((r) => (r['days_open'] as int) > 7).length;
              final now = DateTime.now();
              final date =
                  '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storefront,
                          color: Colors.white, size: 30),
                      const SizedBox(width: 10),
                      const Text('Operator Desk',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(date,
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _stat('Pending', pending, Colors.white),
                      _stat('Under Process', inProc, Colors.white),
                      _stat('Overdue', overdue,
                          overdue > 0 ? Colors.yellowAccent : Colors.white),
                    ],
                  ),
                ],
              );
            }),
          ),
          Card(
            child: ListTile(
              leading: _lead(Icons.person_search, Colors.green.shade700),
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
              leading: _lead(Icons.list_alt, Colors.cyan.shade700),
              title: const Text('Services & Rates'),
              subtitle: const Text('Search services, fees and required documents'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServicesScreen(readOnly: true)),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: _lead(Icons.receipt, Colors.blue),
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
              leading: _lead(Icons.event_busy, Colors.deepOrange),
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
              leading: _lead(Icons.print, Colors.purple),
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
              leading: _lead(Icons.chat, Colors.teal),
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
              leading: _lead(Icons.move_to_inbox, Colors.pink),
              title: const Text('Delegated to Me'),
              subtitle: const Text('Tasks delegated from other branches'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DelegatedTasksScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
            leading: _lead(Icons.point_of_sale, Colors.amber.shade800),
            title: const Text('My Sales'),
            subtitle: const Text('View sales, incentives, and deposit cash collected'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalesScreen()),
            ),
          ),
        ),
        Card(
            child: ListTile(
            leading: _lead(Icons.hourglass_top, Colors.indigo),
            title: const Text('My Applications'),
            subtitle: const Text('Pending & under process, with days'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyApplicationsScreen()),
            ),
        ),
        ),
        ],
      ),
    );
  }
}