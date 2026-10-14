import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final supabase = Supabase.instance.client;
  bool _loading = true;
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();
  String _period = 'today';

  List<Map<String, dynamic>> _sales = [];
  Map<String, double> _byMethod = {};
  double _totalIncentive = 0;
  double _totalGovtFee = 0;
  double _cashInHand = 0;
  List<Map<String, dynamic>> _myDeposits = [];

  @override
  void initState() {
    super.initState();
    _applyPeriod('today');
  }

  void _applyPeriod(String period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;
    switch (period) {
      case 'week':
        start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        end = start.add(const Duration(days: 7));
        break;
      case 'month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
    }
    setState(() {
      _period = period;
      _rangeStart = start;
      _rangeEnd = end;
    });
    _loadData();
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
        _period = 'custom';
        _rangeStart = picked.start;
        _rangeEnd = picked.end.add(const Duration(days: 1));
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final myId = supabase.auth.currentUser!.id;

      final sales = await supabase
          .from('service_requests')
          .select('*, customers(name), services(name, govt_fee, operator_incentive)')
          .eq('operator_id', myId)
          .eq('payment_status', 'received')
          .gte('payment_received_at', _rangeStart.toIso8601String())
          .lt('payment_received_at', _rangeEnd.toIso8601String())
          .order('payment_received_at', ascending: false);

      final byMethod = <String, double>{};
      double incentiveTotal = 0;
      double govtFeeTotal = 0;
      for (final r in sales) {
        final qty = (r['quantity'] as num?)?.toInt() ?? 1;
        final method = r['payment_method'] ?? 'unknown';
        final amt = (r['amount'] as num?)?.toDouble() ?? 0;
        byMethod[method] = (byMethod[method] ?? 0) + amt;
        incentiveTotal += ((r['services']?['operator_incentive'] as num?)?.toDouble() ?? 0) * qty;
        govtFeeTotal += ((r['services']?['govt_fee'] as num?)?.toDouble() ?? 0) * qty;
      }

      final allCash = await supabase
          .from('service_requests')
          .select('amount')
          .eq('operator_id', myId)
          .eq('payment_status', 'received')
          .eq('payment_method', 'cash');
      final totalCashCollected = allCash.fold<double>(0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));

      final approvedDeposits = await supabase
          .from('cash_deposits')
          .select('amount')
          .eq('staff_id', myId)
          .eq('status', 'approved');
      final totalApproved = approvedDeposits.fold<double>(0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));

      final myDeposits = await supabase
          .from('cash_deposits')
          .select()
          .eq('staff_id', myId)
          .order('created_at', ascending: false)
          .limit(10);

      setState(() {
        _sales = List<Map<String, dynamic>>.from(sales);
        _byMethod = byMethod;
        _totalIncentive = incentiveTotal;
        _totalGovtFee = govtFeeTotal;
        _cashInHand = totalCashCollected - totalApproved;
        _myDeposits = List<Map<String, dynamic>>.from(myDeposits);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sales: $e')),
        );
      }
    }
  }

  Future<void> _showDepositDialog() async {
    final amountController = TextEditingController(text: _cashInHand.toStringAsFixed(0));
    final noteController = TextEditingController();
    String? error;

    final userId = supabase.auth.currentUser!.id;
    final me = await supabase.from('staff').select('branch_id').eq('id', userId).single();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mark Cash Deposited'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current cash in hand: ₹${_cashInHand.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount Deposited'), keyboardType: TextInputType.number),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note (optional)')),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('This will be sent to Admin for confirmation. Your balance updates once approved.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountController.text);
                if (amt == null || amt <= 0) {
                  setDialogState(() => error = 'Enter a valid amount');
                  return;
                }
                try {
                  await supabase.from('cash_deposits').insert({
                    'staff_id': userId,
                    'branch_id': me['branch_id'],
                    'amount': amt,
                    'note': noteController.text.trim(),
                  });
                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  setDialogState(() => error = 'Failed to submit: $e');
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Color _depositStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM, hh:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('My Sales')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(label: const Text('Today'), selected: _period == 'today', onSelected: (_) => _applyPeriod('today')),
                ChoiceChip(label: const Text('This Week'), selected: _period == 'week', onSelected: (_) => _applyPeriod('week')),
                ChoiceChip(label: const Text('This Month'), selected: _period == 'month', onSelected: (_) => _applyPeriod('month')),
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
                      Card(
                        color: Colors.amber.withOpacity(0.12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Cash in Hand (Undeposited)', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('₹${_cashInHand.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ElevatedButton(onPressed: _showDepositDialog, child: const Text('Mark Cash Deposited')),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Summary for Selected Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._byMethod.entries.map((e) => Chip(label: Text('${e.key}: ₹${e.value.toStringAsFixed(0)}'))),
                          Chip(label: Text('Incentive: ₹${_totalIncentive.toStringAsFixed(0)}'), backgroundColor: Colors.blue.withOpacity(0.1)),
                          Chip(label: Text('Govt Fee: ₹${_totalGovtFee.toStringAsFixed(0)}'), backgroundColor: Colors.purple.withOpacity(0.1)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      if (_sales.isEmpty) const Text('No sales in this period.'),
                      ..._sales.map((r) {
                        final qty = (r['quantity'] as num?)?.toInt() ?? 1;
                        final incentive = ((r['services']?['operator_incentive'] as num?)?.toDouble() ?? 0) * qty;
                        final govtFee = ((r['services']?['govt_fee'] as num?)?.toDouble() ?? 0) * qty;
                        final customerName = r['customers']?['name'] ?? 'Unknown';
                        final serviceName = r['services']?['name'] ?? 'Unknown';
                        final date = r['payment_received_at'] != null ? DateTime.parse(r['payment_received_at']) : null;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('$customerName • $serviceName'),
                            subtitle: Text(
                              '₹${r['amount']} • ${r['payment_method']}\nIncentive: ₹${incentive.toStringAsFixed(0)} • Govt Fee: ₹${govtFee.toStringAsFixed(0)}'
                              '${date != null ? '\n${df.format(date)}' : ''}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      const Text('My Deposit Claims', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      if (_myDeposits.isEmpty) const Text('No deposit claims yet.'),
                      ..._myDeposits.map((d) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('₹${d['amount']}'),
                              subtitle: Text(d['note'] ?? ''),
                              trailing: Chip(
                                label: Text(d['status']),
                                backgroundColor: _depositStatusColor(d['status']).withOpacity(0.15),
                                labelStyle: TextStyle(color: _depositStatusColor(d['status'])),
                              ),
                            ),
                          )),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
