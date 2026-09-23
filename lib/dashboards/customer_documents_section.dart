import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerDocumentsSection extends StatefulWidget {
  final String customerId;
  const CustomerDocumentsSection({super.key, required this.customerId});

  @override
  State<CustomerDocumentsSection> createState() => _CustomerDocumentsSectionState();
}

class _CustomerDocumentsSectionState extends State<CustomerDocumentsSection> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    setState(() => _loading = true);
    try {
      final docs = await supabase
          .from('customer_documents')
          .select()
          .eq('customer_id', widget.customerId)
          .order('created_at', ascending: false);
      setState(() {
        _docs = List<Map<String, dynamic>>.from(docs);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<String?> _pickDocType() async {
    final options = ['Aadhaar Card', 'PAN Card', 'Voter ID', 'Passport Photo', 'Other'];
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Document Type'),
        children: options
            .map((o) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, o),
                  child: Text(o),
                ))
            .toList(),
      ),
    );
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final docType = await _pickDocType();
    if (docType == null) return;

    setState(() => _uploading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final me = await supabase.from('staff').select('branch_id').eq('id', userId).single();
      final branchId = me['branch_id'];
      final path = '$branchId/${widget.customerId}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

      await supabase.storage.from('customer-documents').uploadBinary(path, bytes);
      await supabase.from('customer_documents').insert({
        'customer_id': widget.customerId,
        'branch_id': branchId,
        'uploaded_by': userId,
        'file_path': path,
        'file_name': file.name,
        'doc_type': docType,
      });
      await _loadDocs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _openDoc(String path) async {
    try {
      final signedUrl = await supabase.storage.from('customer-documents').createSignedUrl(path, 300);
      await launchUrl(Uri.parse(signedUrl));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Documents', style: TextStyle(fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: _uploading ? null : _upload,
              icon: _uploading
                  ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file, size: 18),
              label: const Text('Upload'),
            ),
          ],
        ),
        if (_loading)
          const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
        else if (_docs.isEmpty)
          const Text('No documents uploaded yet.', style: TextStyle(color: Colors.grey))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _docs.map((d) {
              return ActionChip(
                avatar: const Icon(Icons.description, size: 16),
                label: Text(d['doc_type'] ?? d['file_name'] ?? 'Document'),
                onPressed: () => _openDoc(d['file_path']),
              );
            }).toList(),
          ),
      ],
    );
  }
}