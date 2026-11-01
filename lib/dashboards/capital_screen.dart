import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CapitalScreen extends StatefulWidget {
  const CapitalScreen({super.key});
  @override
  State<CapitalScreen> createState() => _CapitalScreenState();
}

class _CapitalScreenState extends State<CapitalScreen> {
  final supabase = Supabase.instance.client;
  final _df = DateFormat('dd MMM yyyy');
  final _iso = DateFormat('yyyy-MM-dd');
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _partners = [];
  List<Map<String, dynamic>> _branches = [];
  double _contributed = 0;
  double _usedExpenses = 0;
  double _usedPayroll = 0;
  double _lossCovered = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _sum(List rows, String key) =>
      rows.fold<double>(0, (a, r) => a + ((r[key] as num?)?.toDouble() ?? 0));

  String _m(double v) => '₹${v.toStringAsFixed(2)}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await supabase
          .from('capital_contributions')
          .select('*, staff(name), branches(name)')
          .order('contributed_on', ascending: false);
      final partners = await supabase.from('staff').select('id, name').eq('role', 'admin').order('name');
      final branches = await supabase.from('branches').select('id, name').order('name');
      final exp = await supabase
          .from('expenses')
          .select('amount')
          .eq('funded_from_capital', true)
          .eq('approval_status', 'approved');
      final pay = await supabase.from('payroll_runs').select('total_paid').eq('funded_from_capital', true);
      final loss = await supabase.from('partner_statements').select('capital_covered_loss');
      setState(() {
        _items = List<Map<String, dynamic>>.from(items);
        _partners = List<Map<String, dynamic>>.from(partners);
        _branches = List<Map<String, dynamic>>.from(branches);
        _contributed = _sum(items, 'amount');
        _usedExpenses = _sum(exp, 'amount');
        _usedPayroll = _sum(pay, 'total_paid');
        _lossCovered = _sum(loss, 'capital_covered_loss');
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showAddDialog() async {
    DateTime date = DateTime.now();
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    String? partnerId = _partners.isNotEmpty ? _partners.first['id'] as String : null;
    String? branchId;
    String? error;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Capital'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: partnerId,
                    decoration: const InputDecoration(labelText: 'Received from (partner)'),
                    items: [
                      for (final p in _partners)
                        DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] as String)),
                    ],
                    onChanged: (v) => setDialogState(() => partnerId = v),
                  ),
                  TextField(
                    controller: amountC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount received (₹)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: Text('Date received: ${_df.format(date)}'),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (d != null) setDialogState(() => date = d);
                    },
                  ),
                  DropdownButtonFormField<String?>(
                    value: branchId,
                    decoration: const InputDecoration(labelText: 'For a specific branch? (optional)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('General / not branch-specific')),
                      for (final b in _branches)
                        DropdownMenuItem<String?>(value: b['id'] as String, child: Text(b['name'] as String)),
                    ],
                    onChanged: (v) => setDialogState(() => branchId = v),
                  ),
                  TextField(
                    controller: noteC,
                    decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. Initial capital, New branch'),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!, style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final amount = double.tryParse(amountC.text.trim());
                      if (partnerId == null) {
                        setDialogState(() => error = 'Choose the partner');
                        return;
                      }
                      if (amount == null || amount <= 0) {
                        setDialogState(() => error = 'Enter an amount above 0');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await supabase.from('capital_contributions').insert({
                          'contributed_on': _iso.format(date),
                          'amount': amount,
                          'partner_id': partnerId,
                          'branch_id': branchId,
                          'note': noteC.text.trim().isEmpty ? null : noteC.text.trim(),
                          'created_by': supabase.auth.currentUser!.id,
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        _load();
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          error = 'Failed to save: $e';
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text('${_m((item['amount'] as num).toDouble())} received on ${_df.format(DateTime.parse(item['contributed_on']))}. Use this only to correct a mistake.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from('capital_contributions').delete().eq('id', item['id']);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final used = _usedExpenses + _usedPayroll + _lossCovered;
    return Scaffold(
      appBar: AppBar(title: const Text('Partner Capital')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Capital'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                    children: [
                      Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Capital to be recovered (total received)'),
                              Text(_m(_contributed),
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                              const Divider(),
                              Text('Used for setup expenses: ${_m(_usedExpenses)}'),
                              Text('Used for setup salaries: ${_m(_usedPayroll)}'),
                              Text('Monthly losses covered: ${_m(_lossCovered)}'),
                              Text('Remaining in the pool: ${_m(_contributed - used)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              const Text(
                                'Monthly losses covered from capital will be deducted here once month-end statements are added.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No capital recorded yet. Tap Add Capital.')),
                        ),
                      for (final it in _items)
                        Card(
                          child: ListTile(
                            title: Text(_m((it['amount'] as num).toDouble()),
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${_df.format(DateTime.parse(it['contributed_on']))} • ${it['staff']?['name'] ?? ''}'
                              '${it['branches']?['name'] != null ? ' • ${it['branches']['name']}' : ''}'
                              '${(it['note'] ?? '').toString().isNotEmpty ? '\n${it['note']}' : ''}',
                            ),
                            isThreeLine: (it['note'] ?? '').toString().isNotEmpty,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _delete(it),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
