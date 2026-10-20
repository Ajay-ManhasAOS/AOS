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

Widget _tile(BuildContext context, IconData icon, Color color, String title,
        String subtitle, Widget Function() screen) =>
    ListTile(
      leading: _lead(icon, color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => screen()),
      ),
    );

Widget _group(IconData icon, Color color, String title, List<Widget> tiles) => Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: _lead(icon, color),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        shape: const Border(),
        collapsedShape: const Border(),
        children: tiles,
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
            child: _tile(context, Icons.person_search, Colors.green.shade700,
                'Find / Add Customer',
                'Look up a customer by mobile or name, or add a new one',
                () => const CustomerLookupScreen()),
          ),
          Card(
            child: _tile(context, Icons.list_alt, Colors.cyan.shade700,
                'Services & Rates',
                'Search services, fees and required documents',
                () => const ServicesScreen(readOnly: true)),
          ),
          Card(
            child: _tile(context, Icons.hourglass_top, Colors.indigo,
                'My Applications',
                'Pending & under process, with days',
                () => const MyApplicationsScreen()),
          ),
          Card(
            child: _tile(context, Icons.point_of_sale, Colors.amber.shade800,
                'My Sales',
                'View sales, incentives, and deposit cash collected',
                () => const SalesScreen()),
          ),
          Card(
            child: _tile(context, Icons.move_to_inbox, Colors.pink,
                'Delegated to Me',
                'Tasks delegated from other branches',
                () => const DelegatedTasksScreen()),
          ),
          _group(Icons.business, Colors.green.shade700, 'Branch Admin', [
            _tile(context, Icons.receipt, Colors.blue, 'Expenses',
                'Log branch expenses for approval', () => const ExpensesScreen()),
            _tile(context, Icons.print, Colors.purple, 'Consumables Log',
                'Log daily printing/paper usage', () => const ConsumablesScreen()),
            _tile(context, Icons.chat, Colors.teal, 'Messages',
                'Send/receive notes with other branches',
                () => const BranchMessagesListScreen()),
            _tile(context, Icons.event_busy, Colors.deepOrange, 'Leaves',
                'Request leave and track approval status', () => const LeavesScreen()),
          ]),
        ],
      ),
    );
  }
}
