import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfitSharingScreen extends StatefulWidget {
  const ProfitSharingScreen({super.key});
  @override
  State<ProfitSharingScreen> createState() => _ProfitSharingScreenState();
}

class _ProfitSharingScreenState extends State<ProfitSharingScreen> {
  final supabase = Supabase.instance.client;
  final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _df = DateFormat('dd MMM yyyy');
  final _iso = DateFormat('yyyy-MM-dd');

  late DateTime _month;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _st;
  Map<String, dynamic>? _cfg;
  final Map<String, String> _names = {};
  List<Map<String, dynamic>> _finals = [];
  List<Map<String, dynamic>> _payouts = [];
  double _contributed = 0;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month - 1, 1);
    _load();
  }

  double _n(dynamic v) => (v as num?)?.toDouble() ?? 0;
  String _m(double v) => _money.format(v);
  String _pct(dynamic v) => '${(_n(v) * 100).toStringAsFixed(0)}%';
  String _err(Object e) => e is PostgrestException ? e.message : e.toString();

  bool get _isCurrentOrFuture {
    final n = DateTime.now();
    return !_month.isBefore(DateTime(n.year, n.month, 1));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final st = await supabase.rpc('partner_statement', params: {'p_month': _iso.format(_month)});
      final cfg = await supabase.from('partnership_config').select().eq('id', 1).single();
      final admins = await supabase.from('staff').select('id, name').eq('role', 'admin');
      final finals = await supabase.from('partner_statements').select().order('month');
      final payouts = await supabase.from('partner_payouts').select().order('paid_on', ascending: false);
      final contrib = await supabase.from('capital_contributions').select('amount');
      _names.clear();
      for (final a in admins) {
        _names[a['id'] as String] = a['name'] as String;
      }
      setState(() {
        _st = Map<String, dynamic>.from(st as Map);
        _cfg = Map<String, dynamic>.from(cfg);
        _finals = List<Map<String, dynamic>>.from(finals);
        _payouts = List<Map<String, dynamic>>.from(payouts);
        _contributed = contrib.fold<double>(0, (a, r) => a + _n(r['amount']));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = _err(e);
        _loading = false;
      });
    }
  }

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  Future<void> _finalise() async {
    final st = _st!;
    final first = _names[_cfg!['first_partner_id']] ?? 'First partner';
    final second = _names[_cfg!['second_partner_id']] ?? 'Second partner';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Finalise ${DateFormat('MMMM yyyy').format(_month)}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Net Distributable Profit: ${_m(_n(st['ndp']))}'),
            Text('Capital recovery ($first): ${_m(_n(st['capital_recovery']))}'),
            Text('$first profit: ${_m(_n(st['first_profit']))}'),
            Text('$second profit: ${_m(_n(st['second_profit']))}'),
            const SizedBox(height: 8),
            Text('Payroll entries found for this month: ${st['payroll_runs']}'),
            const SizedBox(height: 8),
            const Text(
              'Check first that payroll is fully paid, expenses are approved, and the capital ticks are set. '
              'A finalised month is locked (the latest one can be reopened).',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Finalise')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.rpc('partner_statement_finalize', params: {'p_month': _iso.format(_month)});
      _load();
    } catch (e) {
      _snack('Could not finalise: ${_err(e)}');
    }
  }

  Future<void> _reopen() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reopen this month?'),
        content: const Text('The month becomes a draft again and the recovery balance is recalculated. Payments you recorded are not affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reopen')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.rpc('partner_statement_reopen', params: {'p_month': _iso.format(_month)});
      _load();
    } catch (e) {
      _snack('Could not reopen: ${_err(e)}');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  double _paid(String partnerId, String kind) => _payouts
      .where((p) => p['partner_id'] == partnerId && p['kind'] == kind)
      .fold<double>(0, (a, p) => a + _n(p['amount']));

  Future<void> _showPayoutDialog() async {
    final firstId = _cfg!['first_partner_id'] as String;
    final secondId = _cfg!['second_partner_id'] as String;
    String partnerId = firstId;
    String kind = 'capital_recovery';
    DateTime date = DateTime.now();
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    String? error;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record Payment to Partner'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: partnerId,
                    decoration: const InputDecoration(labelText: 'Paid to'),
                    items: [
                      DropdownMenuItem(value: firstId, child: Text(_names[firstId] ?? 'First partner')),
                      DropdownMenuItem(value: secondId, child: Text(_names[secondId] ?? 'Second partner')),
                    ],
                    onChanged: (v) => setDialogState(() {
                      partnerId = v!;
                      if (partnerId != firstId) kind = 'profit_share';
                    }),
                  ),
                  DropdownButtonFormField<String>(
                    value: kind,
                    decoration: const InputDecoration(labelText: 'Towards'),
                    items: [
                      if (partnerId == firstId)
                        const DropdownMenuItem(value: 'capital_recovery', child: Text('Capital recovery')),
                      const DropdownMenuItem(value: 'profit_share', child: Text('Profit share')),
                    ],
                    onChanged: (v) => setDialogState(() => kind = v!),
                  ),
                  TextField(
                    controller: amountC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount paid (₹)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event, size: 18),
                    label: Text('Paid on: ${_df.format(date)}'),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (d != null) setDialogState(() => date = d);
                    },
                  ),
                  TextField(controller: noteC, decoration: const InputDecoration(labelText: 'Note (optional)')),
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
                      if (amount == null || amount <= 0) {
                        setDialogState(() => error = 'Enter an amount above 0');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await supabase.from('partner_payouts').insert({
                          'paid_on': _iso.format(date),
                          'partner_id': partnerId,
                          'kind': kind,
                          'amount': amount,
                          'note': noteC.text.trim().isEmpty ? null : noteC.text.trim(),
                          'created_by': supabase.auth.currentUser!.id,
                        });
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        _load();
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          error = 'Failed to save: ${_err(e)}';
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

  Future<void> _deletePayout(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this payment entry?'),
        content: Text('${_m(_n(p['amount']))} on ${_df.format(DateTime.parse(p['paid_on']))}. Use this only to correct a mistake.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from('partner_payouts').delete().eq('id', p['id']);
      _load();
    } catch (e) {
      _snack('Failed: ${_err(e)}');
    }
  }

  Widget _line(String label, double v, {bool bold = false, bool minus = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : null, color: color))),
            Text('${minus ? '− ' : ''}${_m(v)}',
                style: TextStyle(fontWeight: bold ? FontWeight.bold : null, color: color)),
          ],
        ),
      );

  Widget _statementCard(Map<String, dynamic> st, String first, String second) {
    final finalised = st['finalised'] == true;
    final loss = _n(st['capital_covered_loss']);
    final ndp = _n(st['ndp']);
    final p1 = _n(st['phase1_ndp']);
    final p2 = _n(st['phase2_ndp']);
    final cfg = _cfg!;
    final label = finalised ? 'Finalised' : (_isCurrentOrFuture ? 'In progress' : 'Draft');
    final color = finalised ? Colors.green : (_isCurrentOrFuture ? Colors.orange : Colors.blue);

    String? splitNote;
    if (ndp > 0 && p1 > 0 && p2 > 0 && st['recovery_completes_on'] != null) {
      splitNote = 'Capital recovery completes on ${_df.format(DateTime.parse(st['recovery_completes_on']))}. '
          '${_m(p1)} is shared ${_pct(cfg['recovery_share'])}/${_pct(cfg['first_profit_share'])}/${_pct(cfg['second_profit_share'])}, '
          'and ${_m(p2)} is shared ${_pct(cfg['after_recovery_first_share'])}/${_pct(1 - _n(cfg['after_recovery_first_share']))}.';
    } else if (ndp > 0 && p1 == 0) {
      splitNote = 'Capital is already fully recovered, so profit is shared ${_pct(cfg['after_recovery_first_share'])}/${_pct(1 - _n(cfg['after_recovery_first_share']))}.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Profit statement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Chip(
                  label: Text(label, style: TextStyle(color: color, fontSize: 12)),
                  backgroundColor: color.withOpacity(0.12),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            _line('Service revenue (after govt fees)', _n(st['service_revenue'])),
            _line('Salaries & incentives (from profit)', _n(st['salaries_total']), minus: true),
            _line('Expenses (from profit)', _n(st['expenses_total']), minus: true),
            const Divider(),
            _line('Operating result', _n(st['operating_result']), bold: true),
            if (loss > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Loss of ${_m(loss)} is covered from capital. Nothing to distribute this month.',
                    style: TextStyle(color: Colors.orange.shade800)),
              )
            else ...[
              _line('Net Distributable Profit', ndp, bold: true),
              const Divider(),
              _line('Capital recovery to $first (${_pct(cfg['recovery_share'])} while recovering)', _n(st['capital_recovery'])),
              _line('$first: profit share', _n(st['first_profit'])),
              _line('$second: profit share', _n(st['second_profit'])),
              if (splitNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(splitNote, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
            ],
            const Divider(),
            _line('Total capital received', _n(st['capital_target'])),
            _line('Still to recover before this month', _n(st['recovery_remaining_before'])),
            _line('Still to recover after this month', _n(st['recovery_remaining_after']), bold: true),
            const SizedBox(height: 4),
            Text('Payroll entries counted: ${st['payroll_runs']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (!finalised && !_isCurrentOrFuture)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.lock),
                    label: const Text('Finalise this month'),
                    onPressed: _finalise,
                  ),
                if (finalised && _finals.isNotEmpty && _finals.last['month'] == st['month'])
                  OutlinedButton.icon(
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Reopen'),
                    onPressed: _reopen,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _balancesCard(String first, String second) {
    final firstId = _cfg!['first_partner_id'] as String;
    final secondId = _cfg!['second_partner_id'] as String;
    final capAlloc = _finals.fold<double>(0, (a, s) => a + _n(s['capital_recovery']));
    final firstProfit = _finals.fold<double>(0, (a, s) => a + _n(s['first_profit']));
    final secondProfit = _finals.fold<double>(0, (a, s) => a + _n(s['second_profit']));
    final capPaid = _paid(firstId, 'capital_recovery');
    final firstPaid = _paid(firstId, 'profit_share');
    final secondPaid = _paid(secondId, 'profit_share');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Balances (finalised months only)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text('Capital recovery: $first', style: const TextStyle(fontWeight: FontWeight.w600)),
            _line('Total capital received', _contributed),
            _line('Allocated for recovery so far', capAlloc),
            _line('Still to be recovered from profit', _contributed - capAlloc, bold: true),
            _line('Paid out towards capital', capPaid),
            _line('Allocated but not yet paid', capAlloc - capPaid, bold: true, color: Colors.deepOrange),
            const Divider(),
            Text('Profit share: $first', style: const TextStyle(fontWeight: FontWeight.w600)),
            _line('Allocated', firstProfit),
            _line('Paid out', firstPaid),
            _line('Due', firstProfit - firstPaid, bold: true, color: Colors.deepOrange),
            const Divider(),
            Text('Profit share: $second', style: const TextStyle(fontWeight: FontWeight.w600)),
            _line('Allocated', secondProfit),
            _line('Paid out', secondPaid),
            _line('Due', secondProfit - secondPaid, bold: true, color: Colors.deepOrange),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = _cfg == null ? 'First partner' : (_names[_cfg!['first_partner_id']] ?? 'First partner');
    final second = _cfg == null ? 'Second partner' : (_names[_cfg!['second_partner_id']] ?? 'Second partner');
    return Scaffold(
      appBar: AppBar(title: const Text('Profit Sharing')),
      floatingActionButton: _cfg == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _showPayoutDialog,
              icon: const Icon(Icons.payments),
              label: const Text('Record Payment'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: $_error')))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
                          Text(DateFormat('MMMM yyyy').format(_month),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _isCurrentOrFuture ? null : () => _shift(1),
                          ),
                        ],
                      ),
                      _statementCard(_st!, first, second),
                      _balancesCard(first, second),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
                        child: Text('Payments made', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      if (_payouts.isEmpty)
                        const Padding(padding: EdgeInsets.all(12), child: Text('No payments recorded yet.')),
                      for (final p in _payouts)
                        Card(
                          child: ListTile(
                            title: Text(_m(_n(p['amount'])), style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${_df.format(DateTime.parse(p['paid_on']))} • ${_names[p['partner_id']] ?? ''} • '
                              '${p['kind'] == 'capital_recovery' ? 'Capital recovery' : 'Profit share'}'
                              '${(p['note'] ?? '').toString().isNotEmpty ? '\n${p['note']}' : ''}',
                            ),
                            isThreeLine: (p['note'] ?? '').toString().isNotEmpty,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deletePayout(p),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
