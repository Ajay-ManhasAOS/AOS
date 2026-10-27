import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PromoCodesScreen extends StatefulWidget {
  const PromoCodesScreen({super.key});
  @override
  State<PromoCodesScreen> createState() => _PromoCodesScreenState();
}

class _PromoCodesScreenState extends State<PromoCodesScreen> {
  final supabase = Supabase.instance.client;
  final _df = DateFormat('dd MMM yyyy');
  final _iso = DateFormat('yyyy-MM-dd');
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _codes = [];
  List<Map<String, dynamic>> _services = [];
  final Map<String, Set<String>> _codeServices = {};
  final Map<String, int> _uses = {};
  final Map<String, double> _given = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final codes = await supabase.from('promo_codes').select().order('created_at', ascending: false);
      final services = await supabase
          .from('services')
          .select('id, name, base_rate')
          .eq('is_active', true)
          .order('name');
      final links = await supabase.from('promo_code_services').select('promo_id, service_id');
      final used = await supabase
          .from('service_requests')
          .select('promo_code_id, discount_amount')
          .not('promo_code_id', 'is', null);

      _codeServices.clear();
      for (final l in links) {
        _codeServices.putIfAbsent(l['promo_id'] as String, () => <String>{}).add(l['service_id'] as String);
      }
      _uses.clear();
      _given.clear();
      for (final u in used) {
        final id = u['promo_code_id'] as String;
        _uses[id] = (_uses[id] ?? 0) + 1;
        _given[id] = (_given[id] ?? 0) + ((u['discount_amount'] as num?)?.toDouble() ?? 0);
      }
      setState(() {
        _codes = List<Map<String, dynamic>>.from(codes);
        _services = List<Map<String, dynamic>>.from(services);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _trim(dynamic v) {
    final d = (v as num).toDouble();
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(2);
  }

  String _valueText(Map<String, dynamic> c) => c['discount_type'] == 'percent'
      ? '${_trim(c['value'])}% off service charge'
      : '₹${_trim(c['value'])} off service charge';

  (String, Color) _status(Map<String, dynamic> c) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (c['is_active'] != true) return ('Inactive', Colors.grey);
    if (c['valid_to'] != null && DateTime.parse(c['valid_to']).isBefore(today)) {
      return ('Expired', Colors.red);
    }
    if (c['valid_from'] != null && DateTime.parse(c['valid_from']).isAfter(today)) {
      return ('Scheduled', Colors.blue);
    }
    return ('Active', Colors.green);
  }

  Future<void> _toggleActive(Map<String, dynamic> c, bool v) async {
    try {
      await supabase.from('promo_codes').update({'is_active': v}).eq('id', c['id']);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<DateTime?> _pickDate(BuildContext ctx, DateTime? initial) {
    return showDatePicker(
      context: ctx,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
  }

  Future<void> _showEditDialog([Map<String, dynamic>? existing]) async {
    final isNew = existing == null;
    final codeC = TextEditingController(text: existing?['code'] ?? '');
    final descC = TextEditingController(text: existing?['description'] ?? '');
    final valueC = TextEditingController(text: existing == null ? '' : _trim(existing['value']));
    final maxUsesC = TextEditingController(text: existing?['max_uses']?.toString() ?? '');
    final perCustC = TextEditingController(text: existing?['max_uses_per_customer']?.toString() ?? '');
    String type = existing?['discount_type'] ?? 'percent';
    DateTime? validFrom = existing?['valid_from'] != null ? DateTime.parse(existing!['valid_from']) : null;
    DateTime? validTo = existing?['valid_to'] != null ? DateTime.parse(existing!['valid_to']) : null;
    bool active = existing?['is_active'] ?? true;
    final selected = <String>{...(_codeServices[existing?['id']] ?? <String>{})};
    String search = '';
    String? error;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final shown = _services
              .where((s) => (s['name'] as String).toLowerCase().contains(search.toLowerCase()))
              .toList();
          return AlertDialog(
            title: Text(isNew ? 'New Promo Code' : 'Edit ${existing['code']}'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: codeC,
                      enabled: isNew,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Code (e.g. DIWALI10)'),
                    ),
                    TextField(
                      controller: descC,
                      decoration: const InputDecoration(labelText: 'Description (optional)'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(labelText: 'Discount type'),
                      items: const [
                        DropdownMenuItem(value: 'percent', child: Text('Percentage of service charge (%)')),
                        DropdownMenuItem(value: 'flat', child: Text('Flat amount off service charge (₹)')),
                      ],
                      onChanged: (v) => setDialogState(() => type = v!),
                    ),
                    TextField(
                      controller: valueC,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: type == 'percent' ? 'Percent (1-100)' : 'Amount (₹)'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.event, size: 18),
                            label: Text(validFrom == null ? 'Valid from: any' : 'From ${_df.format(validFrom!)}'),
                            onPressed: () async {
                              final d = await _pickDate(context, validFrom);
                              if (d != null) setDialogState(() => validFrom = d);
                            },
                          ),
                        ),
                        if (validFrom != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setDialogState(() => validFrom = null),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.event_available, size: 18),
                            label: Text(validTo == null ? 'Valid until: no end date' : 'Until ${_df.format(validTo!)}'),
                            onPressed: () async {
                              final d = await _pickDate(context, validTo ?? validFrom);
                              if (d != null) setDialogState(() => validTo = d);
                            },
                          ),
                        ),
                        if (validTo != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setDialogState(() => validTo = null),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: maxUsesC,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Max total uses (blank = unlimited)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: perCustC,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Max per customer (blank = unlimited)'),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: active,
                      onChanged: (v) => setDialogState(() => active = v),
                    ),
                    const Divider(),
                    Text('Applies to services (${selected.length} selected)',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search services...',
                      ),
                      onChanged: (v) => setDialogState(() => search = v),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setDialogState(() {
                            for (final s in shown) {
                              selected.add(s['id'] as String);
                            }
                          }),
                          child: Text('Select shown (${shown.length})'),
                        ),
                        TextButton(
                          onPressed: () => setDialogState(() => selected.clear()),
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final s = shown[i];
                          final id = s['id'] as String;
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: selected.contains(id),
                            title: Text(s['name'] as String),
                            subtitle: Text('Service charge ₹${_trim(s['base_rate'] ?? 0)}'),
                            onChanged: (v) => setDialogState(() {
                              if (v == true) {
                                selected.add(id);
                              } else {
                                selected.remove(id);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(error!, style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        final code = codeC.text.trim().toUpperCase();
                        final value = double.tryParse(valueC.text.trim());
                        final maxUsesTxt = maxUsesC.text.trim();
                        final perCustTxt = perCustC.text.trim();
                        String? err;
                        if (code.isEmpty || code.contains(' ')) {
                          err = 'Enter a code without spaces';
                        } else if (value == null || value <= 0) {
                          err = 'Enter a discount value above 0';
                        } else if (type == 'percent' && value > 100) {
                          err = 'Percent cannot be more than 100';
                        } else if (selected.isEmpty) {
                          err = 'Select at least one service';
                        } else if (validFrom != null && validTo != null && validTo!.isBefore(validFrom!)) {
                          err = 'End date is before the start date';
                        } else if ((maxUsesTxt.isNotEmpty && int.tryParse(maxUsesTxt) == null) ||
                            (perCustTxt.isNotEmpty && int.tryParse(perCustTxt) == null)) {
                          err = 'Usage limits must be whole numbers';
                        }
                        if (err != null) {
                          setDialogState(() => error = err);
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final payload = <String, dynamic>{
                            'code': code,
                            'description': descC.text.trim().isEmpty ? null : descC.text.trim(),
                            'discount_type': type,
                            'value': value,
                            'valid_from': validFrom == null ? null : _iso.format(validFrom!),
                            'valid_to': validTo == null ? null : _iso.format(validTo!),
                            'max_uses': maxUsesTxt.isEmpty ? null : int.parse(maxUsesTxt),
                            'max_uses_per_customer': perCustTxt.isEmpty ? null : int.parse(perCustTxt),
                            'is_active': active,
                          };
                          String promoId;
                          if (isNew) {
                            payload['created_by'] = supabase.auth.currentUser!.id;
                            final row = await supabase.from('promo_codes').insert(payload).select('id').single();
                            promoId = row['id'] as String;
                          } else {
                            promoId = existing['id'] as String;
                            await supabase.from('promo_codes').update(payload).eq('id', promoId);
                          }
                          await supabase.from('promo_code_services').delete().eq('promo_id', promoId);
                          await supabase.from('promo_code_services').insert(
                                selected.map((sid) => {'promo_id': promoId, 'service_id': sid}).toList(),
                              );
                          if (dialogContext.mounted) Navigator.pop(dialogContext);
                          _load();
                        } catch (e) {
                          final msg = e.toString();
                          setDialogState(() {
                            saving = false;
                            error = (msg.contains('duplicate') || msg.contains('23505'))
                                ? 'That code already exists. Choose a different code.'
                                : 'Failed to save: $msg';
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promo Codes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New Code'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _codes.isEmpty
                  ? const Center(child: Text('No promo codes yet. Tap New Code to create one.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
                        itemCount: _codes.length,
                        itemBuilder: (context, i) {
                          final c = _codes[i];
                          final id = c['id'] as String;
                          final st = _status(c);
                          final nServices = _codeServices[id]?.length ?? 0;
                          final uses = _uses[id] ?? 0;
                          final given = _given[id] ?? 0;
                          final validity = (c['valid_from'] == null && c['valid_to'] == null)
                              ? 'No date limit'
                              : '${c['valid_from'] == null ? 'any' : _df.format(DateTime.parse(c['valid_from']))}'
                                  ' → ${c['valid_to'] == null ? 'no end' : _df.format(DateTime.parse(c['valid_to']))}';
                          return Card(
                            child: ListTile(
                              onTap: () => _showEditDialog(c),
                              title: Row(
                                children: [
                                  Text(c['code'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(st.$1, style: TextStyle(color: st.$2, fontSize: 12)),
                                    backgroundColor: st.$2.withOpacity(0.12),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '${_valueText(c)}\n'
                                '$nServices services • $validity\n'
                                'Used $uses${c['max_uses'] != null ? ' of ${c['max_uses']}' : ''} times'
                                ' • ₹${given.toStringAsFixed(2)} given'
                                '${(c['description'] ?? '').toString().isNotEmpty ? '\n${c['description']}' : ''}',
                              ),
                              isThreeLine: true,
                              trailing: Switch(
                                value: c['is_active'] == true,
                                onChanged: (v) => _toggleActive(c, v),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
