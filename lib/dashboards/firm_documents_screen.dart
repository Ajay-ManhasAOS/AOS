import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class FirmDocumentsScreen extends StatefulWidget {
  const FirmDocumentsScreen({super.key});

  @override
  State<FirmDocumentsScreen> createState() => _FirmDocumentsScreenState();
}

class _FirmDocumentsScreenState extends State<FirmDocumentsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('firm_documents')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _documents = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load documents: $e')),
        );
      }
    }
  }

  Future<void> _showUploadDialog() async {
    final nameController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Upload Firm Document'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Document Name', hintText: 'e.g. GST Registration Certificate'),
              ),
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
                if (nameController.text.trim().isEmpty) {
                  setDialogState(() => error = 'Document name is required');
                  return;
                }
                final result = await FilePicker.platform.pickFiles(withData: true);
                if (result == null || result.files.isEmpty) return;
                final file = result.files.first;
                final bytes = file.bytes;
                if (bytes == null) return;

                setDialogState(() => error = null);
                try {
                  final path = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
                  await supabase.storage.from('firm-documents').uploadBinary(path, bytes);
                  await supabase.from('firm_documents').insert({
                    'document_name': nameController.text.trim(),
                    'file_path': path,
                    'file_name': file.name,
                    'uploaded_by': supabase.auth.currentUser!.id,
                  });
                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  setDialogState(() => error = 'Upload failed: $e');
                }
              },
              child: const Text('Choose File & Upload'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(String path) async {
    try {
      final signedUrl = await supabase.storage.from('firm-documents').createSignedUrl(path, 300);
      await launchUrl(Uri.parse(signedUrl));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: $e')),
        );
      }
    }
  }

  Future<void> _deleteDocument(Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('This will permanently delete "${doc['document_name']}". This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await supabase.storage.from('firm-documents').remove([doc['file_path']]);
      await supabase.from('firm_documents').delete().eq('id', doc['id']);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd MMM yyyy');
    return Scaffold(
      appBar: AppBar(title: const Text('Firm Documents')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? const Center(child: Text('No documents uploaded yet. Tap + to add one.'))
              : ListView.builder(
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final d = _documents[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.description),
                        title: Text(d['document_name'] ?? ''),
                        subtitle: Text('${d['file_name']} • ${df.format(DateTime.parse(d['created_at']))}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download),
                              tooltip: 'View / Download',
                              onPressed: () => _openDocument(d['file_path']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteDocument(d),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showUploadDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
