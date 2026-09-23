import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final supabase = Supabase.instance.client;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loading = true;
  List<Map<String, dynamic>> _rows = []; // computed rows: staff + salary + incentives + paid status

  @override
  void initState() {
    super.initState();
    _loadPayroll();
  }

  Future<void> _loadPayroll() async {
    setState(() => _loading = true);
    try {
      final monthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
      final monthStr = monthStart.toIso8601String().split('T')[0];

      final staffList = await supabase
          .from('staff')
          .select('id, name, role, salary, branches(name)')
          .neq('role', 'admin')
          .eq('status', 'active');

      final completedRequests = await supabase
          .from('service_requests')
          .select('operator_id, services(operator_incentive)')
          .eq('status', 'completed')
          .gte('completed_at', monthStart.toIso8601String())
          .lt('completed_at', monthEnd.toIso8601String());

      final existingRuns = await supabase
          .from('payroll_runs')
          .select()
          .eq('month', monthStr);
      final paidStaffIds = {for (final r in existingRuns) r['staff_id']: r};

      final incentiveByStaff = <String, double>{};
      for (final r in completedRequests) {
        final opId = r['operator_id'] as String;
        final incentive = (r['services']?['operator_incentive'] as num?)?.toDouble() ?? 0;
        incentiveByStaff[opId] = (incentiveByStaff[opId] ?? 0) + incentive;
      }

      final rows = staffList.map((s) {
        final salary = (s['salary'] as num?)?.toDouble() ?? 0;
        final incentive = incentiveByStaff[s['id']] ?? 0;
        final paidRun = paidStaffIds[s['id']];
        return {
          'staff_id': s['id'],
          'name': s['name'],
          'role': s['role'],
          'branch': s['branches']?['name'] ?? '',
          'salary': salary,
          'incentive': incentive,
          'total': salary + incentive,
          'paid': paidRun != null,
          'paid_total': paidRun?['total_paid'],
        };
      }).toList();

      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load payroll: $e')),
        );
      }
    }
  }

  Future<void> _markPaid(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Text('Mark ₹${row['total'].toStringAsFixed(2)} as paid to ${row['name']} for ${DateFormat('MMMM yyyy').format(_selectedMonth)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final monthStr = DateTime(_selectedMonth.year, _selectedMonth.month, 1).toIso8601String().split('T')[0];
      await supabase.from('payroll_runs').insert({
        'staff_id': row['staff_id'],
        'month': monthStr,
        'base_salary': row['salary'],
        'incentive_total': row['incentive'],
        'total_paid': row['total'],
        'paid_by': supabase.auth.currentUser!.id,
      });
      _loadPayroll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark paid: $e')),
        );
      }
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
      _loadPayroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPayout = _rows.fold<double>(0, (sum, r) => sum + (r['total'] as double));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickMonth),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(DateFormat('MMMM yyyy').format(_selectedMonth), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Total payout: ₹${totalPayout.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                if (_rows.isEmpty) const Text('No active staff found.'),
                ..._rows.map((r) {
                  final paid = r['paid'] as bool;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text('${r['name']} (${r['role']} • ${r['branch']})', style: const TextStyle(fontWeight: FontWeight.bold))),
                              if (paid) const Chip(label: Text('Paid'), backgroundColor: Color(0xFFDFF5E1)),
                            ],
                          ),
                          Text('Salary: ₹${(r['salary'] as double).toStringAsFixed(2)}'),
                          Text('Incentive: ₹${(r['incentive'] as double).toStringAsFixed(2)}'),
                          Text('Total: ₹${(r['total'] as double).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (!paid)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: ElevatedButton(
                                onPressed: () => _markPaid(r),
                                child: const Text('Mark Paid'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}