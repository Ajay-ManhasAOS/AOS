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
import 'cash_deposits_screen.dart';
import 'firm_documents_screen.dart';
import 'branch_status_screen.dart';

Widget _lead(IconData icon, Color color) => CircleAvatar(
      backgroundColor: color.withOpacity(0.12),
      child: Icon(icon, color: color),
    );


class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.indigo,
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
          Card(
            child: ListTile(
              leading: _lead(Icons.store, Colors.indigo),
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
              leading: _lead(Icons.people, Colors.blue),
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
              leading: _lead(Icons.receipt, Colors.deepOrange),
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
              leading: _lead(Icons.miscellaneous_services, Colors.purple),
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
              leading: _lead(Icons.inventory, Colors.brown),
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
              leading: _lead(Icons.bar_chart, Colors.teal),
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
              leading: _lead(Icons.payments, Colors.green),
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
              leading: _lead(Icons.chat, Colors.cyan),
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
            leading: _lead(Icons.event_busy, Colors.pink),
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
    leading: _lead(Icons.inventory_2, Colors.orange),
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
    leading: _lead(Icons.print, Colors.blueGrey),
    title: const Text('Consumables Log'),
    subtitle: const Text('Audit branch printing/paper usage'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConsumablesScreen()),
    ),
  ),
),
Card(
  child: ListTile(
    leading: _lead(Icons.account_balance_wallet, Colors.green.shade700),
    title: const Text('Cash Deposits'),
    subtitle: const Text('Confirm cash collected and deposited by branches'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CashDepositsScreen()),
    ),
  ),
),
Card(
  child: ListTile(
    leading: _lead(Icons.folder_special, Colors.amber.shade800),
    title: const Text('Firm Documents'),
    subtitle: const Text('Registration certificates, licenses, agreements'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FirmDocumentsScreen()),
    ),
  ),
),
Card(
  child: ListTile(
    leading: _lead(Icons.account_tree, Colors.deepPurple),
    title: const Text('Branch-wise Status'),
    subtitle: const Text('Pending, under process, overdue by branch'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BranchStatusScreen()),
    ),
  ),
),
        ],
      ),
    );
  }
}
