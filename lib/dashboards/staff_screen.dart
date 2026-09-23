import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _branches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final staffData = await supabase.from('staff').select('*, branches(name)').order('created_at');
    final branchData = await supabase.from('branches').select();
    setState(() {
      _staff = List<Map<String, dynamic>>.from(staffData);
      _branches = List<Map<String, dynamic>>.from(branchData);
      _loading = false;
    });
  }

  Future<void> _showStatusDialog(Map<String, dynamic> staff) async {
  String status = staff['status'] ?? 'active';
  String? error;

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Update Status: ${staff['name']}'),
        content: DropdownButtonFormField<String>(
          value: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: const [
            DropdownMenuItem(value: 'active', child: Text('Active')),
            DropdownMenuItem(value: 'on_leave', child: Text('On Leave')),
            DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
            DropdownMenuItem(value: 'resigned', child: Text('Resigned')),
          ],
          onChanged: (v) => setDialogState(() => status = v!),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await supabase.from('staff').update({'status': status}).eq('id', staff['id']);
                if (context.mounted) Navigator.pop(context);
                _loadData();
              } catch (e) {
                setDialogState(() => error = 'Failed to update status.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _showAddStaffDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final salaryController = TextEditingController();
    String role = 'operator';
    String? branchId = _branches.isNotEmpty ? _branches.first['id'] : null;
    String? error;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Staff'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email (login)')),
                TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                TextField(controller: salaryController, decoration: const InputDecoration(labelText: 'Salary'), keyboardType: TextInputType.number),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'operator', child: Text('Operator')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin (Partner)')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v!),
                ),
                DropdownButtonFormField<String>(
                  value: branchId,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: _branches.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name']))).toList(),
                  onChanged: (v) => setDialogState(() => branchId = v),
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
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() {
                        submitting = true;
                        error = null;
                      });
                      try {
                        final response = await supabase.functions.invoke(
                          'create-staff',
                          body: {
                            'name': nameController.text.trim(),
                            'email': emailController.text.trim(),
                            'password': passwordController.text,
                            'role': role,
                            'branch_id': branchId,
                            'salary': double.tryParse(salaryController.text) ?? 0,
                          },
                        );
                        final data = response.data;
                        if (data is Map && data['error'] != null) {
                          setDialogState(() {
                            error = data['error'].toString();
                            submitting = false;
                          });
                          return;
                        }
                        if (context.mounted) Navigator.pop(context);
                        _loadData();
                      } catch (e) {
                        setDialogState(() {
                          error = 'Failed to create staff. Please try again.';
                          submitting = false;
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _staff.isEmpty
              ? const Center(child: Text('No staff yet. Tap + to add one.'))
              : ListView.builder(
                  itemCount: _staff.length,
                  itemBuilder: (context, index) {
                    final s = _staff[index];
                    final branchName = s['branches']?['name'] ?? 'Unassigned';
                    return ListTile(
                      title: Text(s['name'] ?? ''),
                      subtitle: Text('${s['role']} • $branchName • ${s['status']}'),
                      onTap: () => _showStatusDialog(s),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _branches.isEmpty
            ? null
            : _showAddStaffDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
