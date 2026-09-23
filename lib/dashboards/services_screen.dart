import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final services = await supabase
          .from('services')
          .select('*, service_categories(name)')
          .order('created_at', ascending: false);
      final categories = await supabase.from('service_categories').select().order('name');
      setState(() {
        _services = List<Map<String, dynamic>>.from(services);
        _categories = List<Map<String, dynamic>>.from(categories);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load services: $e')),
        );
      }
    }
  }

  Future<void> _uploadGuidePdf(void Function(String, String) onUploaded) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final path = 'guides/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    try {
      await supabase.storage.from('service-guides').uploadBinary(path, bytes);
      onUploaded(path, file.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _openGuide(String path) async {
    final url = supabase.storage.from('service-guides').getPublicUrl(path);
    await launchUrl(Uri.parse(url));
  }

  Future<void> _openLink(String url) async {
    await launchUrl(Uri.parse(url));
  }

  Future<void> _showServiceDialog({Map<String, dynamic>? existing}) async {
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final baseRateController = TextEditingController(text: existing?['base_rate']?.toString() ?? '0');
    final govtFeeController = TextEditingController(text: existing?['govt_fee']?.toString() ?? '0');
    final incentiveController = TextEditingController(text: existing?['operator_incentive']?.toString() ?? '0');
    final docsController = TextEditingController(
      text: existing?['required_documents'] != null
          ? (existing!['required_documents'] as List).join(', ')
          : '',
    );
    final portalLinkController = TextEditingController(text: existing?['portal_link'] ?? '');
    String? guidePdfPath = existing?['guide_pdf_path'];
    String? guidePdfName = existing?['guide_pdf_name'];
    String? categoryId = existing?['category_id'] ?? (_categories.isNotEmpty ? _categories.first['id'] : null);
    bool isActive = existing?['is_active'] ?? true;
    String? error;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Service' : 'Edit Service'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Service Name')),
                DropdownButtonFormField<String>(
                  value: categoryId,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name']))).toList(),
                  onChanged: (v) => setDialogState(() => categoryId = v),
                ),
                TextField(
                  controller: baseRateController,
                  decoration: const InputDecoration(labelText: 'Base Rate (₹)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: govtFeeController,
                  decoration: const InputDecoration(labelText: 'Government Fee (₹)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: incentiveController,
                  decoration: const InputDecoration(labelText: 'Operator Incentive (₹)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: docsController,
                  decoration: const InputDecoration(
                    labelText: 'Documents Required',
                    hintText: 'e.g. Aadhaar Card, PAN Card, Passport Photo',
                  ),
                  maxLines: 2,
                ),
                TextField(
                  controller: portalLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Portal Link',
                    hintText: 'e.g. https://digi.punjab.gov.in/service/...',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        guidePdfName ?? 'No guide PDF attached',
                        style: TextStyle(color: guidePdfName == null ? Colors.grey : null),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await _uploadGuidePdf((path, name) {
                          setDialogState(() {
                            guidePdfPath = path;
                            guidePdfName = name;
                          });
                        });
                      },
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Upload PDF'),
                    ),
                  ],
                ),
                CheckboxListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v ?? true),
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
              onPressed: () async {
                if (nameController.text.trim().isEmpty || categoryId == null) {
                  setDialogState(() => error = 'Name and category are required');
                  return;
                }
                final docsList = docsController.text
                    .split(',')
                    .map((d) => d.trim())
                    .where((d) => d.isNotEmpty)
                    .toList();
                final payload = {
                  'name': nameController.text.trim(),
                  'category_id': categoryId,
                  'base_rate': double.tryParse(baseRateController.text) ?? 0,
                  'govt_fee': double.tryParse(govtFeeController.text) ?? 0,
                  'operator_incentive': double.tryParse(incentiveController.text) ?? 0,
                  'required_documents': docsList,
                  'portal_link': portalLinkController.text.trim(),
                  'guide_pdf_path': guidePdfPath,
                  'guide_pdf_name': guidePdfName,
                  'is_active': isActive,
                };
                try {
                  if (existing == null) {
                    await supabase.from('services').insert(payload);
                  } else {
                    await supabase.from('services').update(payload).eq('id', existing['id']);
                  }
                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  setDialogState(() => error = 'Failed to save. Please try again.');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Category Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await supabase.from('service_categories').insert({'name': nameController.text.trim()});
              if (context.mounted) Navigator.pop(context);
              _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteService(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete service?'),
        content: const Text('This cannot be undone. Existing service requests referencing this service will keep their historical data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await supabase.from('services').delete().eq('id', id);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot delete — this service has existing requests. Consider marking it inactive instead.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services Catalog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Add Category',
            onPressed: _showAddCategoryDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
              ? const Center(child: Text('No services yet. Tap + to add one.'))
              : ListView.builder(
                  itemCount: _services.length,
                  itemBuilder: (context, index) {
                    final s = _services[index];
                    final categoryName = s['service_categories']?['name'] ?? 'Uncategorized';
                    final isActive = s['is_active'] ?? true;
                    final docs = (s['required_documents'] as List?)?.cast<String>() ?? [];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s['name'] ?? '',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? null : Colors.grey),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showServiceDialog(existing: s),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteService(s['id']),
                                ),
                              ],
                            ),
                            Text(
                              '$categoryName • Base ₹${s['base_rate']} • Govt ₹${s['govt_fee']} • Incentive ₹${s['operator_incentive']}'
                              '${isActive ? '' : ' • INACTIVE'}',
                            ),
                            if (docs.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: docs.map((d) => Chip(label: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                                ),
                              ),
                            if (s['portal_link'] != null && s['portal_link'] != '')
                              TextButton.icon(
                                onPressed: () => _openLink(s['portal_link']),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Open Portal'),
                              ),
                            if (s['guide_pdf_path'] != null)
                              TextButton.icon(
                                onPressed: () => _openGuide(s['guide_pdf_path']),
                                icon: const Icon(Icons.picture_as_pdf, size: 16),
                                label: Text(s['guide_pdf_name'] ?? 'View Guide'),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _categories.isEmpty
            ? _showAddCategoryDialog
            : () => _showServiceDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
