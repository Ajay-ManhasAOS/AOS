import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'messages_screen.dart';

class BranchMessagesListScreen extends StatefulWidget {
  const BranchMessagesListScreen({super.key});

  @override
  State<BranchMessagesListScreen> createState() => _BranchMessagesListScreenState();
}

class _BranchMessagesListScreenState extends State<BranchMessagesListScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _branches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    final userId = supabase.auth.currentUser!.id;
    final me = await supabase.from('staff').select('branch_id').eq('id', userId).single();
    final myBranchId = me['branch_id'];
    final branches = await supabase.from('branches').select().order('name');
    setState(() {
      _branches = List<Map<String, dynamic>>.from(branches).where((b) => b['id'] != myBranchId).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _branches.isEmpty
              ? const Center(child: Text('No other branches to message.'))
              : ListView.builder(
                  itemCount: _branches.length,
                  itemBuilder: (context, index) {
                    final b = _branches[index];
                    return ListTile(
                      leading: const Icon(Icons.chat_bubble_outline),
                      title: Text(b['name'] ?? ''),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MessagesScreen(otherBranchId: b['id'], otherBranchName: b['name'])),
                      ),
                    );
                  },
                ),
    );
  }
}