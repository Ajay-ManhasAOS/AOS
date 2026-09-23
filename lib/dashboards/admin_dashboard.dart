import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'branches_screen.dart';
import 'staff_screen.dart';
import 'expenses_screen.dart';
import 'services_screen.dart';
import '../change_password_screen.dart';
import 'assets_screen.dart';
import 'reports_screen.dart';
import 'payroll_screen.dart';
import 'branch_messages_list_screen.dart';
import 'leaves_screen.dart';
import 'stock_screen.dart';
import 'consumables_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
              leading: const Icon(Icons.store),
              title: const Text('Branches'),
              subtitle: const Text('Add, edit, or view all branches'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BranchesScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Staff'),
              subtitle: const Text('Add and manage managers & operators'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StaffScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Expenses'),
              subtitle: const Text('HQ expenses & partner approvals'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpensesScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.miscellaneous_services),
              title: const Text('Services Catalog'),
              subtitle: const Text('Manage services, rates, fees & incentives'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ServicesScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Assets'),
              subtitle: const Text('Track equipment, warranty & guarantee periods'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AssetsScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Reports'),
              subtitle: const Text('Daily income, sales & expenses by branch'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.payments),
              title: const Text('Payroll'),
              subtitle: const Text('Monthly salary + incentive calculation'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PayrollScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Messages'),
              subtitle: const Text('Send/receive notes with branches'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BranchMessagesListScreen()),
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
    leading: const Icon(Icons.inventory_2),
    title: const Text('Stock Report'),
    subtitle: const Text('View branch stock levels, send stock to branches'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StockScreen()),
    ),
  ),
),
Card(
  child: ListTile(
    leading: const Icon(Icons.print),
    title: const Text('Consumables Log'),
    subtitle: const Text('Audit branch printing/paper usage'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConsumablesScreen()),
    ),
  ),
),
        ],
      ),
    );
  }
}
