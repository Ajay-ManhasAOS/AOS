import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ConsumablesScreen extends StatefulWidget {
  const ConsumablesScreen({super.key});

  @override
  State<ConsumablesScreen> createState() => _ConsumablesScreenState();
}

class _ConsumablesScreenState extends State<ConsumablesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  String? _myRole;
  Map<String, int> _myStock = {};
  bool _loading = true;

  final bwController = TextEditingController(text: '0');
  final colorController = TextEditingController(text: '0');
  final photocopyController = TextEditingController(text: '0');
  final laminationController = TextEditingController(text: '0');
  final cardsController = TextEditingController(text: '0');
  final noteController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final me = await supabase.from('staff').select('role, branch_id').eq('id', userId).single();
      final logs = await supabase
          .from('consumables_log')
          .select('*, staff!consumables_log_staff_id_fkey(name), branches(name)')
          .order('log_date', ascending: false)
          .limit(30);
      setState(() {
        _myRole = me['role'];
        _logs = List<Map<String, dynamic>>.from(logs);
        _loading = false;
      });
      _loadStock(me['branch_id']);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load logs: $e')),
        );
      }
    }
  }

  Future<void> _loadStock(String branchId) async {
    final stock = await supabase.from('branch_stock').select().eq('branch_id', branchId);
    final map = <String, int>{};
    for (final s in stock) {
      map[s['item_type']] = (s['quantity'] as num).toInt();
    }
    setState(() => _myStock = map);
  }

  Future<void> _showReceiveStockDialog(String branchId) async {
    String itemType = 'paper';
    final qtyController = TextEditingController();
    final noteController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record Stock Purchased Locally'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: itemType,
                decoration: const InputDecoration(labelText: 'Item'),
                items: const [
                    DropdownMenuItem(value: 'paper', child: Text('Paper')),
                    DropdownMenuItem(value: 'bw_toner', child: Text('B&W Toner')),
                    DropdownMenuItem(value: 'color_toner', child: Text('Colour Toner')),
                    DropdownMenuItem(value: 'lamination_sheets', child: Text('Lamination Sheets')),
                    DropdownMenuItem(value: 'blank_cards', child: Text('Blank Cards')),
                ],
                onChanged: (v) => setDialogState(() => itemType = v!),
              ),
              TextField(controller: qtyController, decoration: const InputDecoration(labelText: 'Quantity Purchased'), keyboardType: TextInputType.number),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note (optional)')),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Remember to also log this as a branch expense for reimbursement.', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                final qty = int.tryParse(qtyController.text);
                if (qty == null || qty <= 0) {
                  setDialogState(() => error = 'Enter a valid quantity');
                  return;
                }
                try {
                  await supabase.from('stock_transactions').insert({
                    'branch_id': branchId,
                    'item_type': itemType,
                    'quantity': qty,
                    'source': 'local_purchase',
                    'note': noteController.text.trim(),
                    'created_by': supabase.auth.currentUser!.id,
                  });
                  if (context.mounted) Navigator.pop(context);
                  _loadStock(branchId);
                } catch (e) {
                  setDialogState(() => error = 'Failed to save: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadPendingShipments(String branchId) async {
  final data = await supabase
      .from('stock_transactions')
      .select()
      .eq('branch_id', branchId)
      .eq('status', 'pending')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(data);
}

Future<void> _markReceived(String transactionId, String branchId) async {
  try {
    await supabase.from('stock_transactions').update({'status': 'received'}).eq('id', transactionId);
    _loadStock(branchId);
    setState(() {});
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to confirm receipt: $e')),
      );
    }
  }
}

  Future<void> _submitToday() async {
    setState(() => _submitting = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final me = await supabase.from('staff').select('branch_id').eq('id', userId).single();
      await supabase.from('consumables_log').upsert({
        'staff_id': userId,
        'branch_id': me['branch_id'],
        'log_date': DateTime.now().toIso8601String().split('T')[0],
        'bw_prints': int.tryParse(bwController.text) ?? 0,
        'color_prints': int.tryParse(colorController.text) ?? 0,
        'photocopies': int.tryParse(photocopyController.text) ?? 0,
        'lamination_sheets': int.tryParse(laminationController.text) ?? 0,
        'blank_cards': int.tryParse(cardsController.text) ?? 0,
        'note': noteController.text.trim(),
      }, onConflict: 'staff_id,branch_id,log_date');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Today\'s log saved')),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    final canLog = _myRole == 'operator' || _myRole == 'manager';

    return Scaffold(
      appBar: AppBar(title: const Text('Consumables Log')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (canLog) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton.icon(
                        onPressed: () async {
                          final userId = supabase.auth.currentUser!.id;
                          final me = await supabase.from('staff').select('branch_id').eq('id', userId).single();
                          _showReceiveStockDialog(me['branch_id']);
                        },
                        icon: const Icon(Icons.add_box, size: 18),
                        label: const Text('Received Stock'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Paper: ${_myStock['paper'] ?? 0}')),
                      Chip(label: Text('B&W Toner: ${_myStock['bw_toner'] ?? 0}')),
                      Chip(label: Text('Colour Toner: ${_myStock['color_toner'] ?? 0}')),
                      Chip(label: Text('Lamination: ${_myStock['lamination_sheets'] ?? 0}')),
                      Chip(label: Text('Cards: ${_myStock['blank_cards'] ?? 0}')),
                    ],
                  ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: () async {
                      final userId = supabase.auth.currentUser!.id;
                      final me = await supabase.from('staff').select('branch_id').eq('id', userId).single();
                      return _loadPendingShipments(me['branch_id']);
                    }(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                      final pending = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const Text('Pending Shipments from HQ', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ...pending.map((t) => Card(
                                color: Colors.amber.withOpacity(0.1),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text('${t['item_type']}: ${t['quantity']}'),
                                  subtitle: Text(t['note'] ?? ''),
                                  trailing: ElevatedButton(
                                    onPressed: () => _markReceived(t['id'], t['branch_id']),
                                    child: const Text('Mark Received'),
                                  ),
                                ),
                              )),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Log Today\'s Usage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: bwController, decoration: const InputDecoration(labelText: 'B&W Prints'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: colorController, decoration: const InputDecoration(labelText: 'Colour Prints'), keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: photocopyController, decoration: const InputDecoration(labelText: 'Photocopies'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: laminationController, decoration: const InputDecoration(labelText: 'Lamination Sheets'), keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: cardsController, decoration: const InputDecoration(labelText: 'Blank Cards'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note (optional)')),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submitToday,
                      child: _submitting
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save Today\'s Log'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text('Recent Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (_logs.isEmpty) const Text('No logs yet.'),
                ..._logs.map((l) {
                  final date = DateTime.parse(l['log_date']);
                  final staffName = l['staff']?['name'] ?? 'Unknown';
                  final branchName = l['branches']?['name'] ?? '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('${df.format(date)} • $staffName ${branchName.isNotEmpty ? '($branchName)' : ''}'),
                      subtitle: Text(
                        'B&W: ${l['bw_prints']} • Colour: ${l['color_prints']} • Photocopy: ${l['photocopies']} • Lamination: ${l['lamination_sheets']} • Cards: ${l['blank_cards']}'
                        '${l['note'] != null && l['note'] != '' ? '\nNote: ${l['note']}' : ''}',
                      ),
                      isThreeLine: l['note'] != null && l['note'] != '',
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
