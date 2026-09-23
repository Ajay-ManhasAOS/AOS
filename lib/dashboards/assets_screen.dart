import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _assets = [];
  List<Map<String, dynamic>> _branches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final assets = await supabase
          .from('assets')
          .select('*, branches(name)')
          .order('created_at', ascending: false);
      final branches = await supabase.from('branches').select();
      setState(() {
        _assets = List<Map<String, dynamic>>.from(assets);
        _branches = List<Map<String, dynamic>>.from(branches);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load assets: $e')),
        );
      }
    }
  }

  Future<void> _showAddAssetDialog() async {
    final descController = TextEditingController();
    final valueController = TextEditingController();
    DateTime? purchaseDate;
    DateTime? warrantyExpiry;
    String? branchId = _branches.isNotEmpty ? _branches.first['id'] : null;
    String? error;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Asset'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                DropdownButtonFormField<String>(
                  value: branchId,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: _branches.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name']))).toList(),
                  onChanged: (v) => setDialogState(() => branchId = v),
                ),
                TextField(
                  controller: valueController,
                  decoration: const InputDecoration(labelText: 'Value (₹)'),
                  keyboardType: TextInputType.number,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(purchaseDate == null ? 'Purchase Date' : DateFormat('dd MMM yyyy').format(purchaseDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => purchaseDate = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(warrantyExpiry == null ? 'Warranty/Guarantee Expiry' : DateFormat('dd MMM yyyy').format(warrantyExpiry!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) setDialogState(() => warrantyExpiry = picked);
                  },
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (descController.text.trim().isEmpty || branchId == null) {
                  setDialogState(() => error = 'Description and branch are required');
                  return;
                }
                try {
                  await supabase.from('assets').insert({
                    'branch_id': branchId,
                    'description': descController.text.trim(),
                    'value': double.tryParse(valueController.text) ?? 0,
                    'purchase_date': purchaseDate?.toIso8601String().split('T')[0],
                    'warranty_expiry': warrantyExpiry?.toIso8601String().split('T')[0],
                  });
                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  setDialogState(() => error = 'Failed to save. Please try again.');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Assets')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
              ? const Center(child: Text('No assets yet. Tap + to add one.'))
              : ListView.builder(
                  itemCount: _assets.length,
                  itemBuilder: (context, index) {
                    final a = _assets[index];
                    final branchName = a['branches']?['name'] ?? 'Unassigned';
                    final warrantyExpiry = a['warranty_expiry'] != null ? DateTime.parse(a['warranty_expiry']) : null;
                    final expired = warrantyExpiry != null && warrantyExpiry.isBefore(DateTime.now());
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text('${a['asset_code'] != null ? '[${a['asset_code']}] ' : ''}${a['description'] ?? ''}'),
                        subtitle: Text(
                          '$branchName • ₹${a['value']}'
                          '${warrantyExpiry != null ? ' • Warranty: ${df.format(warrantyExpiry)}${expired ? ' (EXPIRED)' : ''}' : ''}',
                          style: TextStyle(color: expired ? Colors.red : null),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _branches.isEmpty ? null : _showAddAssetDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}