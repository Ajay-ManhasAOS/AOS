import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

enum ReportPeriod { today, thisWeek, thisMonth, thisYear, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final supabase = Supabase.instance.client;
  ReportPeriod _period = ReportPeriod.today;
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();
  bool _loading = true;
  Map<String, Map<String, double>> _branchTotals = {};
  double _totalRevenue = 0;
  double _totalExpenses = 0;

  @override
  void initState() {
    super.initState();
    _applyPeriod(ReportPeriod.today);
  }

  void _applyPeriod(ReportPeriod period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;
    switch (period) {
      case ReportPeriod.today:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
        break;
      case ReportPeriod.thisWeek:
        start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        end = start.add(const Duration(days: 7));
        break;
      case ReportPeriod.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1);
        break;
      case ReportPeriod.thisYear:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year + 1, 1, 1);
        break;
      case ReportPeriod.custom:
        start = _rangeStart;
        end = _rangeEnd.add(const Duration(days: 1));
        break;
    }
    setState(() {
      _period = period;
      _rangeStart = start;
      _rangeEnd = end.subtract(const Duration(days: 1));
    });
    _loadReport(start, end);
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
    );
    if (picked != null) {
      setState(() {
        _period = ReportPeriod.custom;
        _rangeStart = picked.start;
        _rangeEnd = picked.end;
      });
      _loadReport(picked.start, picked.end.add(const Duration(days: 1)));
    }
  }

  Future<void> _loadReport(DateTime start, DateTime end) async {
    setState(() => _loading = true);
    try {
      final startStr = start.toIso8601String();
      final endStr = end.toIso8601String();

      final requests = await supabase
          .from('service_requests')
          .select('amount, branch_id, branches!service_requests_branch_id_fkey(name)')
          .eq('payment_status', 'received')
          .gte('created_at', startStr)
          .lt('created_at', endStr);

      final expenses = await supabase
          .from('expenses')
          .select('amount, branch_id, branches(name)')
          .eq('approval_status', 'approved')
          .gte('created_at', startStr)
          .lt('created_at', endStr);

      final totals = <String, Map<String, double>>{};
      double revTotal = 0;
      double expTotal = 0;

      for (final r in requests) {
        final name = r['branches']?['name'] ?? 'Unknown';
        final amt = (r['amount'] as num?)?.toDouble() ?? 0;
        totals.putIfAbsent(name, () => {'revenue': 0, 'expenses': 0});
        totals[name]!['revenue'] = totals[name]!['revenue']! + amt;
        revTotal += amt;
      }
      for (final e in expenses) {
        final name = e['branches']?['name'] ?? 'Unknown';
        final amt = (e['amount'] as num?)?.toDouble() ?? 0;
        totals.putIfAbsent(name, () => {'revenue': 0, 'expenses': 0});
        totals[name]!['expenses'] = totals[name]!['expenses']! + amt;
        expTotal += amt;
      }

      setState(() {
        _branchTotals = totals;
        _totalRevenue = revTotal;
        _totalExpenses = expTotal;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load report: $e')),
        );
      }
    }
  }

  String _periodLabel() {
    final df = DateFormat('dd MMM yyyy');
    switch (_period) {
      case ReportPeriod.today:
        return 'Today (${df.format(_rangeStart)})';
      case ReportPeriod.thisWeek:
        return 'This Week (${df.format(_rangeStart)} - ${df.format(_rangeEnd)})';
      case ReportPeriod.thisMonth:
        return DateFormat('MMMM yyyy').format(_rangeStart);
      case ReportPeriod.thisYear:
        return DateFormat('yyyy').format(_rangeStart);
      case ReportPeriod.custom:
        return '${df.format(_rangeStart)} - ${df.format(_rangeEnd)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('Today'), selected: _period == ReportPeriod.today, onSelected: (_) => _applyPeriod(ReportPeriod.today)),
                ChoiceChip(label: const Text('This Week'), selected: _period == ReportPeriod.thisWeek, onSelected: (_) => _applyPeriod(ReportPeriod.thisWeek)),
                ChoiceChip(label: const Text('This Month'), selected: _period == ReportPeriod.thisMonth, onSelected: (_) => _applyPeriod(ReportPeriod.thisMonth)),
                ChoiceChip(label: const Text('This Year'), selected: _period == ReportPeriod.thisYear, onSelected: (_) => _applyPeriod(ReportPeriod.thisYear)),
                ActionChip(label: const Text('Custom Range'), onPressed: _pickCustomRange),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Text(_periodLabel(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Card(
                        color: Colors.blue.withOpacity(0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Company-wide', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Revenue: ₹${_totalRevenue.toStringAsFixed(2)}'),
                              Text('Expenses: ₹${_totalExpenses.toStringAsFixed(2)}'),
                              Text(
                                'Net: ₹${(_totalRevenue - _totalExpenses).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('By Branch', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_branchTotals.isEmpty) const Text('No activity for this period.'),
                      ..._branchTotals.entries.map((entry) {
                        final rev = entry.value['revenue'] ?? 0;
                        final exp = entry.value['expenses'] ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(entry.key),
                            subtitle: Text('Revenue: ₹${rev.toStringAsFixed(2)} • Expenses: ₹${exp.toStringAsFixed(2)} • Net: ₹${(rev - exp).toStringAsFixed(2)}'),
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}