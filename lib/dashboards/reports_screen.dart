import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

enum ReportPeriod { today, thisWeek, thisMonth, thisYear, custom }

class ReportsScreen extends StatefulWidget {
  /// When true (operator use) the report is limited to the signed-in staff member's own branch.
  final bool ownBranchOnly;
  const ReportsScreen({super.key, this.ownBranchOnly = false});

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
  double _totalGovt = 0;
  double _totalIncentive = 0;
  String? _branchId;
  Map<String, List<Map<String, dynamic>>> _details = {};

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
      if (widget.ownBranchOnly && _branchId == null) {
        final b = await supabase.rpc('my_branch');
        _branchId = b?.toString();
        if (_branchId == null) throw Exception('No branch is assigned to your account');
      }
      final startStr = start.toIso8601String();
      final endStr = end.toIso8601String();

      final requests = await supabase
          .from('service_requests')
          .select('id, amount, quantity, payment_method, payment_received_at, branch_id, govt_fee_snapshot, incentive_snapshot, customers(name), services(name, govt_fee, operator_incentive), branches!service_requests_branch_id_fkey(name)')
          .eq('payment_status', 'received')
          .match(_branchFilter)
          .gte('payment_received_at', startStr)
          .lt('payment_received_at', endStr);

      final expenses = await supabase
          .from('expenses')
          .select('id, amount, category, note, created_at, branch_id, branches(name)')
          .eq('approval_status', 'approved')
          .match(_branchFilter)
          .gte('created_at', startStr)
          .lt('created_at', endStr);

      final totals = <String, Map<String, double>>{};
      double revTotal = 0;
      double expTotal = 0;

      double govtTotal = 0;
      double incTotal = 0;
      final details = <String, List<Map<String, dynamic>>>{};
      for (final r in requests) {
        final name = r['branches']?['name'] ?? 'Unknown';
        final qty = (r['quantity'] as num?)?.toInt() ?? 1;
        final amt = (r['amount'] as num?)?.toDouble() ?? 0;
        final govt = (((r['govt_fee_snapshot'] ?? r['services']?['govt_fee']) as num?)?.toDouble() ?? 0) * qty;
        final inc = (((r['incentive_snapshot'] ?? r['services']?['operator_incentive']) as num?)?.toDouble() ?? 0) * qty;
        details.putIfAbsent(name, () => []).add({
          'kind': 'payment',
          'when': DateTime.tryParse('${r['payment_received_at']}')?.toLocal(),
          'ref': r['id'].toString().substring(0, 8),
          'who': r['customers']?['name'] ?? '',
          'item': r['services']?['name'] ?? '',
          'method': r['payment_method'] ?? '',
          'amount': amt,
          'govt': govt,
          'counted': amt - govt,
        });
        totals.putIfAbsent(name, () => {'revenue': 0, 'expenses': 0, 'govt': 0, 'incentive': 0});
        totals[name]!['revenue'] = totals[name]!['revenue']! + amt;
        totals[name]!['govt'] = totals[name]!['govt']! + govt;
        totals[name]!['incentive'] = totals[name]!['incentive']! + inc;
        revTotal += amt;
        govtTotal += govt;
        incTotal += inc;
      }
      for (final e in expenses) {
        final name = e['branches']?['name'] ?? 'Unknown';
        final amt = (e['amount'] as num?)?.toDouble() ?? 0;
        final note = (e['note'] ?? '').toString();
        details.putIfAbsent(name, () => []).add({
          'kind': 'expense',
          'when': DateTime.tryParse('${e['created_at']}')?.toLocal(),
          'ref': e['id'].toString().substring(0, 8),
          'who': '',
          'item': note.isEmpty ? '${e['category'] ?? ''}' : '${e['category'] ?? ''} - $note',
          'amount': amt,
          'counted': -amt,
        });
        totals.putIfAbsent(name, () => {'revenue': 0, 'expenses': 0});
        totals[name]!['expenses'] = totals[name]!['expenses']! + amt;
        expTotal += amt;
      }

      setState(() {
        _branchTotals = totals;
        _details = details;
        _totalRevenue = revTotal;
        _totalExpenses = expTotal;
        _totalGovt = govtTotal;
        _totalIncentive = incTotal;
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

  Map<String, Object> get _branchFilter =>
      (widget.ownBranchOnly && _branchId != null) ? {'branch_id': _branchId!} : <String, Object>{};

  List<Widget> _detailRows(String branch) {
    final list = _details[branch] ?? [];
    if (list.isEmpty) return [const ListTile(dense: true, title: Text('No entries'))];
    final df = DateFormat('dd MMM, hh:mm a');
    final payments = list.where((d) => d['kind'] == 'payment').toList();
    final exps = list.where((d) => d['kind'] == 'expense').toList();
    int byWhen(Map<String, dynamic> a, Map<String, dynamic> b) {
      final x = a['when'] as DateTime?;
      final y = b['when'] as DateTime?;
      if (x == null || y == null) return 0;
      return x.compareTo(y);
    }
    payments.sort(byWhen);
    exps.sort(byWhen);
    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
        );
    Widget row(Map<String, dynamic> d) {
      final when = d['when'] as DateTime?;
      final whenText = when == null ? '' : df.format(when);
      final counted = (d['counted'] as num).toDouble();
      final isPay = d['kind'] == 'payment';
      final title = isPay ? '$whenText • ${d['ref']} • ${d['who']}' : '$whenText • ${d['ref']}';
      final sub = isPay
          ? '${d['item']}\nReceived ₹${(d['amount'] as num).toStringAsFixed(2)} • Govt fee ₹${(d['govt'] as num).toStringAsFixed(2)} • ${d['method']}'
          : '${d['item']}';
      return ListTile(
        dense: true,
        title: Text(title),
        subtitle: Text(sub),
        isThreeLine: isPay,
        trailing: Text(
          '${counted < 0 ? '−' : ''}₹${counted.abs().toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: counted < 0 ? Colors.red : Colors.green.shade700),
        ),
      );
    }
    return [
      header('Payments received (${payments.length})'),
      ...payments.map(row),
      header('Expenses (${exps.length})'),
      ...exps.map(row),
    ];
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
      appBar: AppBar(title: Text(widget.ownBranchOnly ? 'Branch Report' : 'Reports')),
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
                              Text(widget.ownBranchOnly ? 'Branch total' : 'Company-wide', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('Amount collected: ₹${_totalRevenue.toStringAsFixed(2)}'),
                              Text('Govt fees (pass-through): - ₹${_totalGovt.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                              const Divider(),
                              Text('Service revenue: ₹${(_totalRevenue - _totalGovt).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Operator incentive: - ₹${_totalIncentive.toStringAsFixed(2)}'),
                              Text('Expenses: - ₹${_totalExpenses.toStringAsFixed(2)}'),
                              const Divider(),
                              Text(
                                'Net margin: ₹${(_totalRevenue - _totalGovt - _totalIncentive - _totalExpenses).toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                        final govt = entry.value['govt'] ?? 0;
                        final inc = entry.value['incentive'] ?? 0;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ExpansionTile(
                            children: _detailRows(entry.key),
                            title: Text(entry.key),
                            subtitle: Text('Collected: ₹${rev.toStringAsFixed(2)} • Govt fee: ₹${govt.toStringAsFixed(2)} • Service revenue: ₹${(rev - govt).toStringAsFixed(2)}\nIncentive: ₹${inc.toStringAsFixed(2)} • Expenses: ₹${exp.toStringAsFixed(2)} • Net margin: ₹${(rev - govt - inc - exp).toStringAsFixed(2)}'),
                            
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