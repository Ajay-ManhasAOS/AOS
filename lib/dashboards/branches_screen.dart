import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _branches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() => _loading = true);
    final data = await supabase.from('branches').select().order('created_at');
    setState(() {
      _branches = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _showBranchDialog({Map<String, dynamic>? existing}) async {
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final addressController = TextEditingController(text: existing?['address'] ?? '');
    final phoneController = TextEditingController(text: existing?['phone'] ?? '');
    bool isPrincipal = existing?['is_principal'] ?? false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Branch' : 'Edit Branch'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Branch Name')),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
              CheckboxListTile(
                title: const Text('Principal place of business'),
                value: isPrincipal,
                onChanged: (v) => setDialogState(() => isPrincipal = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final payload = {
                  'name': nameController.text.trim(),
                  'address': addressController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'is_principal': isPrincipal,
                };
                if (existing == null) {
                  await supabase.from('branches').insert(payload);
                } else {
                  await supabase.from('branches').update(payload).eq('id', existing['id']);
                }
                if (context.mounted) Navigator.pop(context);
                _loadBranches();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBranch(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete branch?'),
        content: const Text('This cannot be undone. Staff or records tied to this branch may be affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await supabase.from('branches').delete().eq('id', id);
      _loadBranches();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Branches')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _branches.isEmpty
              ? const Center(child: Text('No branches yet. Tap + to add one.'))
              : ListView.builder(
                  itemCount: _branches.length,
                  itemBuilder: (context, index) {
                    final b = _branches[index];
                    return ListTile(
                      title: Text(b['name'] ?? ''),
                      subtitle: Text([
                        if (b['is_principal'] == true) 'Principal',
                        if (b['address'] != null && b['address'] != '') b['address'],
                        if (b['phone'] != null && b['phone'] != '') b['phone'],
                      ].join(' • ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showBranchDialog(existing: b),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteBranch(b['id']),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBranchDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}