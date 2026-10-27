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
import 'undeposited_cash_screen.dart';
import 'pending_payroll_screen.dart';
import 'promo_codes_screen.dart';

Widget _lead(IconData icon, Color color) => CircleAvatar(
      backgroundColor: color.withOpacity(0.12),
      child: Icon(icon, color: color),
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
          _group(Icons.groups, Colors.blue, 'HR', [
            _tile(context, Icons.people, Colors.blue, 'Staff',
                'Add and manage managers & operators', () => const StaffScreen()),
            _tile(context, Icons.payments, Colors.green, 'Payroll',
                'Monthly salary + incentive calculation', () => const PayrollScreen()),
            _tile(context, Icons.pending_actions, Colors.teal, 'Pending Payroll',
                'Unpaid salary from earlier months', () => const PendingPayrollScreen()),
            _tile(context, Icons.event_busy, Colors.pink, 'Leaves',
                'Review and approve staff leave requests', () => const LeavesScreen()),
          ]),
          _group(Icons.account_balance, Colors.green.shade700, 'Finance', [
            _tile(context, Icons.bar_chart, Colors.teal, 'Reports',
                'Daily income, sales & expenses by branch', () => const ReportsScreen()),
            _tile(context, Icons.receipt, Colors.deepOrange, 'Expenses',
                'HQ expenses & partner approvals', () => const ExpensesScreen()),
            _tile(context, Icons.account_balance_wallet, Colors.green.shade700, 'Cash Deposits',
                'Confirm cash collected and deposited by branches', () => const CashDepositsScreen()),
            _tile(context, Icons.account_balance_wallet, Colors.orange, 'Undeposited Cash',
                'Cash lying with each branch', () => const UndepositedCashScreen()),
            _tile(context, Icons.local_offer, Colors.red, 'Promo Codes',
                'Discount codes for selected services', () => const PromoCodesScreen()),
          ]),
          _group(Icons.dashboard_customize, Colors.deepPurple, 'Operations', [
            _tile(context, Icons.account_tree, Colors.deepPurple, 'Branch-wise Status',
                'Pending, under process, overdue by branch', () => const BranchStatusScreen()),
            _tile(context, Icons.store, Colors.indigo, 'Branches',
                'Add, edit, or view all branches', () => const BranchesScreen()),
            _tile(context, Icons.miscellaneous_services, Colors.purple, 'Services Catalog',
                'Manage services, rates, fees & incentives', () => const ServicesScreen()),
            _tile(context, Icons.chat, Colors.cyan, 'Messages',
                'Send/receive notes with branches', () => const BranchMessagesListScreen()),
            _tile(context, Icons.folder_special, Colors.amber.shade800, 'Firm Documents',
                'Registration certificates, licenses, agreements', () => const FirmDocumentsScreen()),
          ]),
          _group(Icons.inventory_2, Colors.brown, 'Inventory & Assets', [
            _tile(context, Icons.inventory_2, Colors.orange, 'Stock Report',
                'View branch stock levels, send stock to branches', () => const StockScreen()),
            _tile(context, Icons.print, Colors.blueGrey, 'Consumables Log',
                'Audit branch printing/paper usage', () => const ConsumablesScreen()),
            _tile(context, Icons.inventory, Colors.brown, 'Assets',
                'Track equipment, warranty & guarantee periods', () => const AssetsScreen()),
          ]),
        ],
      ),
    );
  }
}
