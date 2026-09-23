import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class LeavesScreen extends StatefulWidget {
  const LeavesScreen({super.key});

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _leaves = [];
  String? _myRole;
  String? _myBranchId;
  bool _loading = true;

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
      final leaves = await supabase
          .from('leaves')
          .select('*, staff!leaves_staff_id_fkey(name)')
          .order('created_at', ascending: false);
      setState(() {
        _myRole = me['role'];
        _myBranchId = me['branch_id'];
        _leaves = List<Map<String, dynamic>>.from(leaves);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load leaves: $e')),
        );
      }
    }
  }

  Future<void> _showRequestLeaveDialog() async {
    DateTime? startDate;
    DateTime? endDate;
    final reasonController = TextEditingController();
    String? error;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request Leave'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(startDate == null ? 'Start Date' : DateFormat('dd MMM yyyy').format(startDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => startDate = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(endDate == null ? 'End Date' : DateFormat('dd MMM yyyy').format(endDate!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: startDate ?? DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => endDate = picked);
                  },
                ),
                TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason')),
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
                      if (startDate == null || endDate == null) {
                        setDialogState(() => error = 'Please select both dates');
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        await supabase.from('leaves').insert({
                          'staff_id': supabase.auth.currentUser!.id,
                          'branch_id': _myBranchId,
                          'start_date': startDate!.toIso8601String().split('T')[0],
                          'end_date': endDate!.toIso8601String().split('T')[0],
                          'reason': reasonController.text.trim(),
                        });
                        if (context.mounted) Navigator.pop(context);
                        _loadData();
                      } catch (e) {
                        setDialogState(() {
                          error = 'Failed to submit. Please try again.';
                          submitting = false;
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewLeave(String id, String decision) async {
    try {
      await supabase.from('leaves').update({
        'status': decision,
        'approved_by': supabase.auth.currentUser!.id,
        'reviewed_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Color _statusColor(String status) {
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
    final canApprove = _myRole == 'manager' || _myRole == 'admin';
    final canRequest = _myRole == 'operator' || _myRole == 'manager';
    final df = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Leaves')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _leaves.isEmpty
              ? const Center(child: Text('No leave requests yet.'))
              : ListView.builder(
                  itemCount: _leaves.length,
                  itemBuilder: (context, index) {
                    final l = _leaves[index];
                    final status = l['status'] as String? ?? 'pending';
                    final staffName = l['staff']?['name'] ?? 'Unknown';
                    final start = DateTime.parse(l['start_date']);
                    final end = DateTime.parse(l['end_date']);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(staffName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                Chip(
                                  label: Text(status),
                                  backgroundColor: _statusColor(status).withOpacity(0.15),
                                  labelStyle: TextStyle(color: _statusColor(status)),
                                ),
                              ],
                            ),
                            Text('${df.format(start)} → ${df.format(end)}'),
                            if (l['reason'] != null && l['reason'] != '') Text('Reason: ${l['reason']}'),
                            if (canApprove && status == 'pending')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => _reviewLeave(l['id'], 'approved'),
                                      child: const Text('Approve'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => _reviewLeave(l['id'], 'rejected'),
                                      child: const Text('Reject'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: canRequest
          ? FloatingActionButton(
              onPressed: _showRequestLeaveDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}