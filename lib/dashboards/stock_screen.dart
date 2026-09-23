import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

const _itemLabels = {
  'paper': 'Paper',
  'bw_toner': 'B&W Toner',
  'color_toner': 'Colour Toner',
  'lamination_sheets': 'Lamination Sheets',
  'blank_cards': 'Blank Cards',
};

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _branches = [];
  Map<String, Map<String, int>> _stockByBranch = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final branches = await supabase.from('branches').select().order('name');
      final stock = await supabase.from('branch_stock').select();
      final grouped = <String, Map<String, int>>{};
      for (final s in stock) {
        final branchId = s['branch_id'] as String;
        grouped.putIfAbsent(branchId, () => {});
        grouped[branchId]![s['item_type']] = (s['quantity'] as num).toInt();
      }
      setState(() {
        _branches = List<Map<String, dynamic>>.from(branches);
        _stockByBranch = grouped;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load stock: $e')),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadTransactions(String? branchId) async {
  var query = supabase
      .from('stock_transactions')
      .select('*, branches(name), staff(name)');
  if (branchId != null) {
    query = query.eq('branch_id', branchId);
  }
  final data = await query.order('created_at', ascending: false).limit(100);
  return List<Map<String, dynamic>>.from(data);
}

void _showTransactionHistory() {
  String? filterBranchId;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Stock Transaction History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: filterBranchId,
                decoration: const InputDecoration(labelText: 'Filter by Branch'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Branches')),
                  ..._branches.map((b) => DropdownMenuItem<String?>(value: b['id'] as String, child: Text(b['name']))),
                ],
                onChanged: (v) => setSheetState(() => filterBranchId = v),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadTransactions(filterBranchId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final txns = snapshot.data!;
                    if (txns.isEmpty) return const Center(child: Text('No transactions found.'));
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: txns.length,
                      itemBuilder: (context, index) {
                        final t = txns[index];
                        final isHq = t['source'] == 'hq_shipment';
                        final date = DateTime.parse(t['created_at']);
                        final branchName = t['branches']?['name'] ?? 'Unknown';
                        final staffName = t['staff']?['name'] ?? 'Unknown';
                        final itemLabel = _itemLabels[t['item_type']] ?? t['item_type'];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              isHq ? Icons.local_shipping : Icons.storefront,
                              color: isHq ? Colors.blue : Colors.green,
                            ),
                            title: Text('$itemLabel: +${t['quantity']} • $branchName'),
                            subtitle: Text(
                              '${isHq ? 'HQ Shipment' : 'Local Purchase'} by $staffName\n'
                              '${DateFormat('dd MMM yyyy, hh:mm a').format(date)}'
                              '${t['note'] != null && t['note'] != '' ? '\nNote: ${t['note']}' : ''}',
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Future<void> _showSendStockDialog() async {
    String? branchId = _branches.isNotEmpty ? _branches.first['id'] : null;
    String itemType = 'paper';
    final qtyController = TextEditingController();
    final noteController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Send Stock to Branch'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: branchId,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: _branches.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name']))).toList(),
                onChanged: (v) => setDialogState(() => branchId = v),
              ),
              DropdownButtonFormField<String>(
                value: itemType,
                decoration: const InputDecoration(labelText: 'Item'),
                items: _itemLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setDialogState(() => itemType = v!),
              ),
              TextField(controller: qtyController, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
              TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note (optional)')),
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
                if (branchId == null || qty == null || qty <= 0) {
                  setDialogState(() => error = 'Enter a valid quantity');
                  return;
                }
                try {
                  await supabase.from('stock_transactions').insert({
                    'branch_id': branchId,
                    'item_type': itemType,
                    'quantity': qty,
                    'source': 'hq_shipment',
                    'status': 'pending',
                    'note': noteController.text.trim(),
                    'created_by': supabase.auth.currentUser!.id,
                  });
                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  setDialogState(() => error = 'Failed to send: $e');
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Report'),
        actions: [
          IconButton(icon: const Icon(Icons.history), tooltip: 'Transaction History', onPressed: _showTransactionHistory),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _branches.map((b) {
                final stock = _stockByBranch[b['id']] ?? {};
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _itemLabels.entries.map((e) {
                            final qty = stock[e.key] ?? 0;
                            return Chip(
                              label: Text('${e.value}: $qty'),
                              backgroundColor: qty <= 0 ? Colors.red.withOpacity(0.1) : null,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSendStockDialog,
        icon: const Icon(Icons.local_shipping),
        label: const Text('Send Stock'),
      ),
    );
  }
}
