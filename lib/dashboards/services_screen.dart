import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class ServicesScreen extends StatefulWidget {
  final bool readOnly;
  const ServicesScreen({super.key, this.readOnly = false});

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

  final _searchCtrl = TextEditingController();
  String _query = '';
  List<Map<String, dynamic>> _cache = [];
  Object? _cacheSvc;
  String? _cacheQ;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (!identical(_cacheSvc, _services) || _cacheQ != _query) {
      _cacheSvc = _services;
      _cacheQ = _query;
      _cache = _fuzzyFilter(_services, _query);
    }
    return _cache;
  }

  static int _lev(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        var m = prev[j] + 1;
        if (cur[j - 1] + 1 < m) m = cur[j - 1] + 1;
        if (prev[j - 1] + cost < m) m = prev[j - 1] + cost;
        cur[j] = m;
      }
      prev = cur;
    }
    return prev[b.length];
  }

  static int _tokenScore(String token, String hay, List<String> words) {
    if (hay.contains(token)) {
      return words.any((w) => w.startsWith(token)) ? 100 : 80;
    }
    if (token.length < 4) return 0;
    final maxEdits = token.length <= 5 ? 1 : 2;
    var best = 0;
    for (final w in words) {
      if (w.length < 3) continue;
      final d1 = _lev(token, w);
      final prefix = w.length > token.length ? w.substring(0, token.length) : w;
      final d2 = _lev(token, prefix);
      final d = d1 < d2 ? d1 : d2;
      if (d <= maxEdits) {
        final sc = 60 - d * 10;
        if (sc > best) best = sc;
      }
    }
    return best;
  }

  static List<Map<String, dynamic>> _fuzzyFilter(
      List<Map<String, dynamic>> list, String query) {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return list;
    final scored = <MapEntry<Map<String, dynamic>, int>>[];
    for (final s in list) {
      final docs = (s['required_documents'] as List?)?.join(' ') ?? '';
      final name = '${s['name'] ?? ''}'.toLowerCase();
      final hay = '$name ${s['service_categories']?['name'] ?? ''} $docs'.toLowerCase();
      final words = hay.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
      var total = 0;
      var ok = true;
      for (final t in tokens) {
        final sc = _tokenScore(t, hay, words);
        if (sc == 0) {
          ok = false;
          break;
        }
        total += sc;
      }
      if (!ok) continue;
      if (name.contains(tokens.join(' '))) total += 50;
      scored.add(MapEntry(s, total));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search services, category or documents',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
            helperText: _query.trim().isEmpty
                ? null
                : '${_filtered.length} of ${_services.length} services',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      );

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      var q = supabase.from('services').select('*, service_categories(name)');
      if (widget.readOnly) q = q.eq('is_active', true);
      final services = await (widget.readOnly
          ? q.order('name')
          : q.order('created_at', ascending: false));
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
        title: Text(widget.readOnly ? 'Services & Rates' : 'Services Catalog'),
        actions: widget.readOnly ? [] : [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Add Category',
            onPressed: _showAddCategoryDialog,
          ),
        ],
      ),
      body: Column(children: [
        _searchBar(),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? Center(child: Text(_services.isEmpty
                  ? (widget.readOnly ? 'No services available.' : 'No services yet. Tap + to add one.')
                  : 'No services match your search.'))
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final s = _filtered[index];
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
                                if (!widget.readOnly) ...[
IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showServiceDialog(existing: s),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteService(s['id']),
                                ),
],
                              ],
                            ),
                            Text(
                              '$categoryName • Base ₹${s['base_rate']} • Govt ₹${s['govt_fee']}${widget.readOnly ? '' : ' • Incentive ₹${s['operator_incentive']}'}'
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
                )),
      ]),
      floatingActionButton: widget.readOnly ? null : FloatingActionButton(
        onPressed: _categories.isEmpty
            ? _showAddCategoryDialog
            : () => _showServiceDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
