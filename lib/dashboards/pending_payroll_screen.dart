import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingPayrollScreen extends StatefulWidget {
  const PendingPayrollScreen({super.key});
  @override
  State<PendingPayrollScreen> createState() => _PendingPayrollScreenState();
}

class _PendingPayrollScreenState extends State<PendingPayrollScreen> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _ms(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-01';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final thisMonth = DateTime(now.year, now.month, 1);

      final staffList = await supabase
          .from('staff')
          .select('id, name, role, salary, status, date_of_joining, date_of_leaving, branches(name)')
          .neq('role', 'admin');

      final runs = await supabase.from('payroll_runs').select('staff_id, month');
      final paid = {
        for (final r in runs)
          '${r['staff_id']}|${(r['month'] as String).substring(0, 10)}'
      };

      DateTime? earliest;
      for (final s in staffList) {
        final d = s['date_of_joining'] as String?;
        if (d == null) continue;
        final doj = DateTime.parse(d);
        final m = DateTime(doj.year, doj.month, 1);
        if (earliest == null || m.isBefore(earliest)) earliest = m;
      }

      final incentive = <String, double>{};
      if (earliest != null) {
        final reqs = await supabase
            .from('service_requests')
            .select('operator_id, quantity, completed_at, services(operator_incentive)')
            .eq('status', 'completed')
            .gte('completed_at',
                earliest.subtract(const Duration(days: 1)).toUtc().toIso8601String());
        for (final r in reqs) {
          final c = r['completed_at'] as String?;
          if (c == null) continue;
          final d = DateTime.parse(c).toLocal();
          final key = '${r['operator_id']}|${_ms(DateTime(d.year, d.month, 1))}';
          final q = (r['quantity'] as num?)?.toInt() ?? 1;
          final inc =
              ((r['services']?['operator_incentive'] as num?)?.toDouble() ?? 0) * q;
          incentive[key] = (incentive[key] ?? 0) + inc;
        }
      }

      final items = <Map<String, dynamic>>[];
      for (final s in staffList) {
        final d = s['date_of_joining'] as String?;
        if (d == null) continue;
        final doj = DateTime.parse(d);
        final full = (s['salary'] as num?)?.toDouble() ?? 0;
        final dolStr = s['date_of_leaving'] as String?;
        final dol = dolStr == null ? null : DateTime.parse(dolStr);
        if (s['status'] != 'active' && dol == null) continue;
        for (var m = DateTime(doj.year, doj.month, 1);
            m.isBefore(thisMonth);
            m = DateTime(m.year, m.month + 1, 1)) {
          if (dol != null && DateTime(dol.year, dol.month, 1).isBefore(m)) break;
          final ms = _ms(m);
          if (paid.contains('${s['id']}|$ms')) continue;
          final dim = DateTime(m.year, m.month + 1, 0).day;
          final startDay = (doj.year == m.year && doj.month == m.month) ? doj.day : 1;
          final endDay =
              (dol != null && dol.year == m.year && dol.month == m.month) ? dol.day : dim;
          final worked = (endDay - startDay + 1).clamp(0, dim).toInt();
          final salary = (full * worked / dim).roundToDouble();
          final inc = incentive['${s['id']}|$ms'] ?? 0;
          items.add({
            'staff_id': s['id'],
            'name': s['name'],
            'branch': s['branches']?['name'] ?? '',
            'month': m,
            'month_str': ms,
            'salary': salary,
            'days_worked': worked,
            'days_in_month': dim,
            'incentive': inc,
            'total': salary + inc,
          });
        }
      }
      items.sort((a, b) {
        final c = (a['month'] as DateTime).compareTo(b['month'] as DateTime);
        return c != 0 ? c : (a['name'] as String).compareTo(b['name'] as String);
      });
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markPaid(Map<String, dynamic> r) async {
    final label = DateFormat('MMMM yyyy').format(r['month'] as DateTime);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm payment'),
        content: Text(
            'Mark ₹${(r['total'] as double).toStringAsFixed(2)} as paid to ${r['name']} for $label?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark Paid')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from('payroll_runs').insert({
        'staff_id': r['staff_id'],
        'month': r['month_str'],
        'base_salary': r['salary'],
        'days_worked': r['days_worked'],
        'days_in_month': r['days_in_month'],
        'incentive_total': r['incentive'],
        'total_paid': r['total'],
        'paid_by': supabase.auth.currentUser?.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Marked as paid')));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<double>(0, (a, r) => a + (r['total'] as double));
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Payroll')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Card(
                        color: Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Unpaid from earlier months'),
                              const SizedBox(height: 4),
                              Text('₹${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 28, fontWeight: FontWeight.bold)),
                              Text('${_items.length} pending entries'),
                            ],
                          ),
                        ),
                      ),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('Nothing pending. All earlier months are paid.')),
                        ),
                      for (final r in _items)
                        Card(
                          child: ListTile(
                            title: Text(
                                '${r['name']} • ${DateFormat('MMMM yyyy').format(r['month'] as DateTime)}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${r['branch']}\n'
                                'Salary ₹${(r['salary'] as double).toStringAsFixed(2)}'
                                '${r['days_worked'] != r['days_in_month'] ? ' (${r['days_worked']} of ${r['days_in_month']} days)' : ''}'
                                '  •  Incentive ₹${(r['incentive'] as double).toStringAsFixed(2)}\n'
                                'Total ₹${(r['total'] as double).toStringAsFixed(2)}'),
                            isThreeLine: true,
                            trailing: ElevatedButton(
                              onPressed: () => _markPaid(r),
                              child: const Text('Mark Paid'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
