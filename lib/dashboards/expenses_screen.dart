import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _expenses = [];
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
      final expenses = await supabase
          .from('expenses')
          .select('*, staff!expenses_staff_id_fkey(name)')
          .order('created_at', ascending: false);
      setState(() {
        _myRole = me['role'];
        _myBranchId = me['branch_id'];
        _expenses = List<Map<String, dynamic>>.from(expenses);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load expenses: $e')),
        );
      }
    }
  }

  Future<void> _showAddExpenseDialog() async {
    final categoryController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final voucherController = TextEditingController();
    String? error;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Log Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: categoryController, decoration: const InputDecoration(labelText: 'Category (e.g. Stationery, Electricity)')),
                TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount'), keyboardType: TextInputType.number),
                TextField(controller: voucherController, decoration: const InputDecoration(labelText: 'Voucher Reference')),
                TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note (optional)')),
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
                      setDialogState(() => submitting = true);
                      try {
                        await supabase.from('expenses').insert({
                          'branch_id': _myBranchId,
                          'staff_id': supabase.auth.currentUser!.id,
                          'category': categoryController.text.trim(),
                          'amount': double.tryParse(amountController.text) ?? 0,
                          'voucher_reference': voucherController.text.trim(),
                          'note': noteController.text.trim(),
                        });
                        if (context.mounted) Navigator.pop(context);
                        _loadData();
                      } catch (e) {
                        setDialogState(() {
                          error = 'Failed to save. Please try again.';
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

  Future<void> _reviewExpense(String id, String decision) async {
    try {
      await supabase.from('expenses').update({
        'approval_status': decision,
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
    final canAdd = _myRole == 'operator' || _myRole == 'manager' || _myRole == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? const Center(child: Text('No expenses logged yet.'))
              : ListView.builder(
                  itemCount: _expenses.length,
                  itemBuilder: (context, index) {
                    final e = _expenses[index];
                    final status = e['approval_status'] as String? ?? 'pending';
                    final staffName = e['staff']?['name'] ?? 'Unknown';
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
                                Expanded(child: Text(e['category'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                Chip(
                                  label: Text(status),
                                  backgroundColor: _statusColor(status).withOpacity(0.15),
                                  labelStyle: TextStyle(color: _statusColor(status)),
                                ),
                              ],
                            ),
                            Text('₹${e['amount']} • by $staffName'),
                            if (e['voucher_reference'] != null && e['voucher_reference'] != '')
                              Text('Voucher: ${e['voucher_reference']}'),
                            if (e['note'] != null && e['note'] != '') Text('Note: ${e['note']}'),
                            if (canApprove && status == 'pending' && e['staff_id'] != supabase.auth.currentUser!.id)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => _reviewExpense(e['id'], 'approved'),
                                      child: const Text('Approve'),
                                    ),
                                    OutlinedButton(
                                      onPressed: () => _reviewExpense(e['id'], 'rejected'),
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
      floatingActionButton: canAdd
          ? FloatingActionButton(
              onPressed: _showAddExpenseDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}