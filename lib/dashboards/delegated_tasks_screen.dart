import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'customer_detail_screen.dart';

class DelegatedTasksScreen extends StatefulWidget {
  const DelegatedTasksScreen({super.key});

  @override
  State<DelegatedTasksScreen> createState() => _DelegatedTasksScreenState();
}

class _DelegatedTasksScreenState extends State<DelegatedTasksScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final me = await supabase.from('staff').select('branch_id').eq('id', userId).single();
      final data = await supabase
          .from('service_requests')
          .select('*, services(name), customers(id, name, mobile_number), branches!service_requests_branch_id_fkey(name)')
          .eq('delegated_branch_id', me['branch_id'])
          .order('delegated_at', ascending: false);
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load delegated tasks: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(String requestId, String newStatus) async {
    final update = <String, dynamic>{'status': newStatus};
    if (newStatus == 'completed') {
      update['completed_at'] = DateTime.now().toIso8601String();
    }
    await supabase.from('service_requests').update(update).eq('id', requestId);
    _loadTasks();
  }

  Future<void> _release(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Release delegation?'),
        content: const Text('This returns the task to its original branch. Only do this once the work is complete or handed back.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Release')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await supabase.from('service_requests').update({
        'delegated_branch_id': null,
        'delegated_at': null,
        'delegated_by': null,
      }).eq('id', requestId);
      _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to release: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delegated to Me')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(child: Text('No tasks delegated to your branch.'))
              : ListView.builder(
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final t = _tasks[index];
                    final serviceName = t['services']?['name'] ?? 'Unknown';
                    final customer = t['customers'];
                    final customerName = customer?['name'] ?? 'Unknown';
                    final originBranch = t['branches']?['name'] ?? 'Unknown';
                    final status = t['status'] as String? ?? 'initiated';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text('$customerName • $serviceName', style: const TextStyle(fontWeight: FontWeight.bold))),
                                Chip(label: Text(status)),
                              ],
                            ),
                            Text('From: $originBranch'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (status == 'initiated')
                                  OutlinedButton(
                                    onPressed: () => _updateStatus(t['id'], 'under_process'),
                                    child: const Text('Start Processing'),
                                  ),
                                if (status == 'under_process')
                                  OutlinedButton(
                                    onPressed: () => _updateStatus(t['id'], 'completed'),
                                    child: const Text('Mark Completed'),
                                  ),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: customer)),
                                  ),
                                  child: const Text('Open Customer'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _release(t['id']),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Release'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}