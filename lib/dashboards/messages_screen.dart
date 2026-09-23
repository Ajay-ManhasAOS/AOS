import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MessagesScreen extends StatefulWidget {
  final String otherBranchId;
  final String otherBranchName;
  const MessagesScreen({super.key, required this.otherBranchId, required this.otherBranchName});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final supabase = Supabase.instance.client;
  final _bodyController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  String? _myBranchId;
  String? _myName;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final userId = supabase.auth.currentUser!.id;
    final me = await supabase.from('staff').select('branch_id, name').eq('id', userId).single();
    _myBranchId = me['branch_id'];
    _myName = me['name'];
    await _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final messages = await supabase
          .from('messages')
          .select()
          .or('and(sender_branch_id.eq.$_myBranchId,recipient_branch_id.eq.${widget.otherBranchId}),'
              'and(sender_branch_id.eq.${widget.otherBranchId},recipient_branch_id.eq.$_myBranchId)')
          .order('created_at', ascending: true);
      setState(() {
        _messages = List<Map<String, dynamic>>.from(messages);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e')),
        );
      }
    }
  }

  Future<void> _send() async {
    final text = _bodyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await supabase.from('messages').insert({
        'sender_branch_id': _myBranchId,
        'recipient_branch_id': widget.otherBranchId,
        'sender_id': supabase.auth.currentUser!.id,
        'sender_name': _myName,
        'body': text,
      });
      _bodyController.clear();
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM, hh:mm a');

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherBranchName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(child: Text('No messages yet.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final m = _messages[index];
                            final isMine = m['sender_branch_id'] == _myBranchId;
                            final time = DateTime.parse(m['created_at']);
                            return Align(
                              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 320),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isMine ? Colors.blue.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m['sender_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(height: 2),
                                    Text(m['body'] ?? ''),
                                    const SizedBox(height: 2),
                                    Text(df.format(time), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _bodyController,
                          decoration: const InputDecoration(hintText: 'Type a message...'),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      IconButton(
                        icon: _sending
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send),
                        onPressed: _sending ? null : _send,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}