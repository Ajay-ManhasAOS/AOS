import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CashDepositsScreen extends StatefulWidget {
  const CashDepositsScreen({super.key});

  @override
  State<CashDepositsScreen> createState() => _CashDepositsScreenState();
}

class _CashDepositsScreenState extends State<CashDepositsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _deposits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('cash_deposits')
          .select('*, staff!cash_deposits_staff_id_fkey(name), branches(name)')
          .order('created_at', ascending: false);
      setState(() {
        _deposits = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load deposits: $e')),
        );
      }
    }
  }

  Future<void> _review(String id, String decision) async {
    try {
      await supabase.from('cash_deposits').update({
        'status': decision,
        'reviewed_by': supabase.auth.currentUser!.id,
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
    final df = DateFormat('dd MMM yyyy, hh:mm a');
    return Scaffold(
      appBar: AppBar(title: const Text('Cash Deposits')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _deposits.isEmpty
              ? const Center(child: Text('No deposit claims yet.'))
              : ListView.builder(
                  itemCount: _deposits.length,
                  itemBuilder: (context, index) {
                    final d = _deposits[index];
                    final status = d['status'] as String? ?? 'pending';
                    final staffName = d['staff']?['name'] ?? 'Unknown';
                    final branchName = d['branches']?['name'] ?? 'Unknown';
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
                                Expanded(child: Text('$staffName • $branchName', style: const TextStyle(fontWeight: FontWeight.bold))),
                                Chip(
                                  label: Text(status),
                                  backgroundColor: _statusColor(status).withOpacity(0.15),
                                  labelStyle: TextStyle(color: _statusColor(status)),
                                ),
                              ],
                            ),
                            Text('₹${d['amount']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            if (d['note'] != null && d['note'] != '') Text('Note: ${d['note']}'),
                            Text(df.format(DateTime.parse(d['created_at'])), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            if (status == 'pending')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    ElevatedButton(onPressed: () => _review(d['id'], 'approved'), child: const Text('Approve')),
                                    OutlinedButton(onPressed: () => _review(d['id'], 'rejected'), child: const Text('Reject')),
                                  ],
                                ),
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
