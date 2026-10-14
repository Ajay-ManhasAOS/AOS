import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'customer_documents_section.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _services = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final requests = await supabase
        .from('service_requests')
        .select('*, services(name)')
        .eq('customer_id', widget.customer['id'])
        .order('created_at', ascending: false);
    final services = await supabase.from('services').select().eq('is_active', true);
    setState(() {
      _requests = List<Map<String, dynamic>>.from(requests);
      _services = List<Map<String, dynamic>>.from(services);
      _loading = false;
    });
  }

  bool _hasAnyDoc(Map<String, dynamic> c) {
    return (c['aadhaar_number'] != null && c['aadhaar_number'] != '') ||
        (c['pan_number'] != null && c['pan_number'] != '') ||
        (c['voter_id'] != null && c['voter_id'] != '');
  }

  Widget _buildDocRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text('$label:')),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _copyableLine(String label, String value) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
        );
      },
      child: Text('$label: $value'),
    );
  }

  Color _ageColor(DateTime createdAt) {
    final days = DateTime.now().difference(createdAt).inDays;
    if (days >= 2) return Colors.red;
    if (days >= 1) return Colors.orange;
    return Colors.green;
  }

  String? _formattedAddress(Map<String, dynamic> c) {
    final parts = <String>[];
    if (c['care_of'] != null && c['care_of'] != '') parts.add('C/O ${c['care_of']}');
    if (c['house_no'] != null && c['house_no'] != '') parts.add(c['house_no']);
    if (c['street'] != null && c['street'] != '') parts.add(c['street']);
    if (c['landmark'] != null && c['landmark'] != '') parts.add('Near ${c['landmark']}');
    if (c['locality'] != null && c['locality'] != '') parts.add(c['locality']);
    if (c['village_town_city'] != null && c['village_town_city'] != '') parts.add(c['village_town_city']);
    if (c['post_office'] != null && c['post_office'] != '') parts.add('PO: ${c['post_office']}');
    if (c['district'] != null && c['district'] != '') parts.add(c['district']);
    if (c['state'] != null && c['state'] != '') parts.add(c['state']);
    if (c['pincode'] != null && c['pincode'] != '') parts.add(c['pincode']);
    if (parts.isEmpty) return c['address'] as String?;
    return parts.join(', ');
  }

  Future<List<Map<String, dynamic>>> _loadIdentityDocs(String customerId) async {
    final data = await supabase
        .from('customer_identity_documents')
        .select()
        .eq('customer_id', customerId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _openPortalLink(String url) async {
    await launchUrl(Uri.parse(url));
  }

  Future<void> _openGuidePdf(String path) async {
    final url = supabase.storage.from('service-guides').getPublicUrl(path);
    await launchUrl(Uri.parse(url));
  }

  Future<void> _updateStatus(String requestId, String newStatus) async {
    final update = <String, dynamic>{'status': newStatus};
    if (newStatus == 'completed') {
      update['completed_at'] = DateTime.now().toIso8601String();
    }
    await supabase.from('service_requests').update(update).eq('id', requestId);
    _loadData();
  }

  Future<void> _markPaymentReceived(String requestId, String? currentMethod) async {
    String? method = currentMethod;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirm Payment'),
          content: DropdownButtonFormField<String>(
            value: method,
            decoration: const InputDecoration(labelText: 'Payment Method'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'upi', child: Text('UPI')),
              DropdownMenuItem(value: 'card', child: Text('Card')),
              DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
            ],
            onChanged: (v) => setDialogState(() => method = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: method == null
                  ? null
                  : () async {
                      await supabase.from('service_requests').update({
                        'payment_status': 'received',
                        'payment_method': method,
                        'payment_received_at': DateTime.now().toIso8601String(),
                      }).eq('id', requestId);
                      if (context.mounted) Navigator.pop(context);
                      _loadData();
                    },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBill(Map<String, dynamic> request) {
    final serviceName = request['services']?['name'] ?? 'Service';
    final amount = request['amount'] ?? 0;
    final createdAt = request['created_at'] != null
        ? DateTime.parse(request['created_at'])
        : DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(createdAt);
    final shortId = (request['id'] as String).substring(0, 8).toUpperCase();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bill / Receipt'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('All Online Services', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              Text('Receipt No: $shortId'),
              Text('Date: $dateStr'),
              const SizedBox(height: 12),
              Text('Customer: ${widget.customer['name'] ?? ''}'),
              Text('Mobile: ${widget.customer['mobile_number'] ?? ''}'),
              const SizedBox(height: 12),
              Text('Service: $serviceName'),
              Text('Amount: ₹$amount'),
              Text('Payment: ${request['payment_status']} via ${request['payment_method'] ?? '-'}'),
              const Divider(),
              const Text('Thank you for your business.', style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showDelegateDialog(String requestId) async {
    final branches = await supabase.from('branches').select();
    String? targetBranchId;
    String? error;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delegate to Branch'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: targetBranchId,
                decoration: const InputDecoration(labelText: 'Branch'),
                items: (branches as List)
                    .map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name'])))
                    .toList(),
                onChanged: (v) => setDialogState(() => targetBranchId = v),
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
              onPressed: (targetBranchId == null || submitting)
                  ? null
                  : () async {
                      setDialogState(() => submitting = true);
                      try {
                        await supabase.from('service_requests').update({
                          'delegated_branch_id': targetBranchId,
                          'delegated_at': DateTime.now().toIso8601String(),
                          'delegated_by': supabase.auth.currentUser!.id,
                        }).eq('id', requestId);
                        if (context.mounted) Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Request delegated successfully')),
                          );
                        }
                        _loadData();
                      } catch (e) {
                        setDialogState(() {
                          error = 'Failed to delegate: $e';
                          submitting = false;
                        });
                      }
                    },
              child: const Text('Delegate'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditRequestDetailsDialog(Map<String, dynamic> request) async {
    final appNumberController = TextEditingController(text: request['application_number'] ?? '');
    final notesController = TextEditingController(text: request['notes'] ?? '');
    String? error;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Application Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: appNumberController,
                decoration: const InputDecoration(labelText: 'Application/Reference Number', hintText: 'e.g. govt portal tracking ID'),
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
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
                try {
                  await supabase.from('service_requests').update({
                    'application_number': appNumberController.text.trim(),
                    'notes': notesController.text.trim(),
                  }).eq('id', request['id']);
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

  Future<void> _showEditCustomerDialog() async {
    final c = widget.customer;
    final nameController = TextEditingController(text: c['name'] ?? '');
    final mobileController = TextEditingController(text: c['mobile_number'] ?? '');
    final dobController = TextEditingController(text: c['dob'] ?? '');
    final aadhaarController = TextEditingController(text: c['aadhaar_number'] ?? '');
    final panController = TextEditingController(text: c['pan_number'] ?? '');
    final voterController = TextEditingController(text: c['voter_id'] ?? '');
    final emailController = TextEditingController(text: c['email'] ?? '');
    final careOfController = TextEditingController(text: c['care_of'] ?? '');
    final houseNoController = TextEditingController(text: c['house_no'] ?? '');
    final streetController = TextEditingController(text: c['street'] ?? '');
    final landmarkController = TextEditingController(text: c['landmark'] ?? '');
    final localityController = TextEditingController(text: c['locality'] ?? '');
    final vtcController = TextEditingController(text: c['village_town_city'] ?? '');
    final postOfficeController = TextEditingController(text: c['post_office'] ?? '');
    final districtController = TextEditingController(text: c['district'] ?? '');
    final stateController = TextEditingController(text: c['state'] ?? '');
    final pincodeController = TextEditingController(text: c['pincode'] ?? '');
    String? error;

    final existingDocs = await _loadIdentityDocs(c['id']);
    final List<Map<String, TextEditingController>> extraDocs = existingDocs
        .map((d) => {
              'name': TextEditingController(text: d['document_name'] ?? ''),
              'number': TextEditingController(text: d['document_number'] ?? ''),
            })
        .toList();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Customer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
                TextField(controller: mobileController, decoration: const InputDecoration(labelText: 'Mobile Number'), keyboardType: TextInputType.phone),
                TextField(controller: dobController, decoration: const InputDecoration(labelText: 'DOB (YYYY-MM-DD)')),
                TextField(controller: aadhaarController, decoration: const InputDecoration(labelText: 'Aadhaar Number')),
                TextField(controller: panController, decoration: const InputDecoration(labelText: 'PAN Number')),
                TextField(controller: voterController, decoration: const InputDecoration(labelText: 'Voter ID')),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email (optional)'), keyboardType: TextInputType.emailAddress),
                const Divider(height: 24),
                const Align(alignment: Alignment.centerLeft, child: Text('Address (DigiLocker Format)', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                TextField(controller: careOfController, decoration: const InputDecoration(labelText: 'Care Of (C/O) — optional')),
                TextField(controller: houseNoController, decoration: const InputDecoration(labelText: 'House No. / Building / Apartment')),
                TextField(controller: streetController, decoration: const InputDecoration(labelText: 'Street / Road / Lane')),
                TextField(controller: landmarkController, decoration: const InputDecoration(labelText: 'Landmark — optional')),
                TextField(controller: localityController, decoration: const InputDecoration(labelText: 'Area / Locality / Sector')),
                TextField(controller: vtcController, decoration: const InputDecoration(labelText: 'Village / Town / City')),
                TextField(controller: postOfficeController, decoration: const InputDecoration(labelText: 'Post Office')),
                TextField(controller: districtController, decoration: const InputDecoration(labelText: 'District')),
                TextField(controller: stateController, decoration: const InputDecoration(labelText: 'State')),
                TextField(controller: pincodeController, decoration: const InputDecoration(labelText: 'PIN Code')),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Additional ID Documents', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () => setDialogState(() {
                        extraDocs.add({'name': TextEditingController(), 'number': TextEditingController()});
                      }),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                ...extraDocs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final doc = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: TextField(controller: doc['name'], decoration: const InputDecoration(labelText: 'Document Name'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: doc['number'], decoration: const InputDecoration(labelText: 'Document Number'))),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                          onPressed: () => setDialogState(() => extraDocs.removeAt(i)),
                        ),
                      ],
                    ),
                  );
                }),
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
                if (nameController.text.trim().isEmpty || mobileController.text.trim().isEmpty) {
                  setDialogState(() => error = 'Name and mobile number are required');
                  return;
                }
                try {
                  await supabase.from('customers').update({
                    'name': nameController.text.trim(),
                    'mobile_number': mobileController.text.trim(),
                    'dob': dobController.text.trim().isEmpty ? null : dobController.text.trim(),
                    'aadhaar_number': aadhaarController.text.trim(),
                    'pan_number': panController.text.trim(),
                    'voter_id': voterController.text.trim(),
                    'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                    'care_of': careOfController.text.trim(),
                    'house_no': houseNoController.text.trim(),
                    'street': streetController.text.trim(),
                    'landmark': landmarkController.text.trim(),
                    'locality': localityController.text.trim(),
                    'village_town_city': vtcController.text.trim(),
                    'post_office': postOfficeController.text.trim(),
                    'district': districtController.text.trim(),
                    'state': stateController.text.trim(),
                    'pincode': pincodeController.text.trim(),
                  }).eq('id', c['id']);

                  await supabase.from('customer_identity_documents').delete().eq('customer_id', c['id']);
                  final docsToInsert = extraDocs
                      .where((d) => d['name']!.text.trim().isNotEmpty && d['number']!.text.trim().isNotEmpty)
                      .map((d) => {
                            'customer_id': c['id'],
                            'document_name': d['name']!.text.trim(),
                            'document_number': d['number']!.text.trim(),
                          })
                      .toList();
                  if (docsToInsert.isNotEmpty) {
                    await supabase.from('customer_identity_documents').insert(docsToInsert);
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Customer updated')),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  setDialogState(() => error = 'Failed to update. Please try again.');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddServiceDialog() async {
    Map<String, dynamic>? selectedService;
    final quantityController = TextEditingController(text: '1');
    String paymentStatus = 'pending';
    String? paymentMethod;
    String? error;
    bool submitting = false;

    final staff = await supabase
        .from('staff')
        .select('branch_id')
        .eq('id', supabase.auth.currentUser!.id)
        .single();
    final branchId = staff['branch_id'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final requiredDocs = (selectedService?['required_documents'] as List?)?.cast<String>() ?? [];
          final rate = selectedService == null
              ? 0.0
              : (selectedService!['base_rate'] as num? ?? 0).toDouble() + (selectedService!['govt_fee'] as num? ?? 0).toDouble();
          final quantity = int.tryParse(quantityController.text) ?? 1;
          final total = rate * quantity;

          return AlertDialog(
            title: const Text('Add Service Request'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Autocomplete<Map<String, dynamic>>(
                    displayStringForOption: (s) => s['name'] as String,
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text == '') return const Iterable<Map<String, dynamic>>.empty();
                      final query = textEditingValue.text.toLowerCase();
                      return _services.where((s) => (s['name'] as String).toLowerCase().contains(query));
                    },
                    onSelected: (s) => setDialogState(() => selectedService = s),
                    fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
                      if (selectedService != null && textController.text != selectedService!['name']) {
                        textController.text = selectedService!['name'];
                      }
                      return TextField(
                        controller: textController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'Search Service', hintText: 'Type to search...'),
                      );
                    },
                  ),
                  if (requiredDocs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Documents Required:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: requiredDocs
                          .map((d) => Chip(
                                label: Text(d, style: const TextStyle(fontSize: 12)),
                                backgroundColor: Colors.blue.withOpacity(0.1),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (selectedService?['portal_link'] != null && selectedService!['portal_link'] != '')
                    TextButton.icon(
                      onPressed: () => _openPortalLink(selectedService!['portal_link']),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open Application Portal'),
                    ),
                  if (selectedService?['guide_pdf_path'] != null)
                    TextButton.icon(
                      onPressed: () => _openGuidePdf(selectedService!['guide_pdf_path']),
                      icon: const Icon(Icons.picture_as_pdf, size: 16),
                      label: Text(selectedService!['guide_pdf_name'] ?? 'View Application Guide'),
                    ),
                  const SizedBox(height: 12),
                  if (selectedService != null) ...[
                    Text('Rate (per unit): ₹${rate.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Text('Total: ₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    value: paymentStatus,
                    decoration: const InputDecoration(labelText: 'Payment Status'),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'received', child: Text('Received')),
                    ],
                    onChanged: (v) => setDialogState(() => paymentStatus = v!),
                  ),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI')),
                      DropdownMenuItem(value: 'card', child: Text('Card')),
                      DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    ],
                    onChanged: (v) => setDialogState(() => paymentMethod = v),
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
                onPressed: (submitting || selectedService == null)
                    ? null
                    : () async {
                        setDialogState(() => submitting = true);
                        try {
                          await supabase.from('service_requests').insert({
                            'customer_id': widget.customer['id'],
                            'service_id': selectedService!['id'],
                            'branch_id': branchId,
                            'operator_id': supabase.auth.currentUser!.id,
                            'status': 'initiated',
                            'payment_status': paymentStatus,
                            'payment_method': paymentMethod,
                            'payment_received_at': paymentStatus == 'received' ? DateTime.now().toIso8601String() : null,
                            'quantity': quantity,
                            'amount': total,
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
                    : const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    return Scaffold(
      appBar: AppBar(
        title: Text(c['name'] ?? ''),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Customer',
            onPressed: _showEditCustomerDialog,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _copyableLine('Mobile', c['mobile_number'] ?? ''),
                if (c['email'] != null && c['email'] != '') _copyableLine('Email', c['email']),
                if (c['dob'] != null && c['dob'] != '') Text('Date of Birth: ${c['dob']}'),
                if (_formattedAddress(c) != null) _copyableLine('Address', _formattedAddress(c)!),
                if (_hasAnyDoc(c)) ...[
                  const SizedBox(height: 8),
                  const Text('Documents on File', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  _buildDocRow('Aadhaar', c['aadhaar_number']),
                  _buildDocRow('PAN', c['pan_number']),
                  _buildDocRow('Voter ID', c['voter_id']),
                ],
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadIdentityDocs(c['id']),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text('Additional ID Documents', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        ...snapshot.data!.map((d) => _buildDocRow(d['document_name'], d['document_number'])),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                CustomerDocumentsSection(customerId: c['id']),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Service History', style: TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _showAddServiceDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('New Service'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                    ? const Center(child: Text('No services yet for this customer.'))
                    : ListView.builder(
                        itemCount: _requests.length,
                        itemBuilder: (context, index) {
                          final r = _requests[index];
                          final serviceName = r['services']?['name'] ?? 'Unknown';
                          final status = r['status'] as String? ?? 'initiated';
                          final paymentStatus = r['payment_status'] as String? ?? 'pending';
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(color: _ageColor(DateTime.parse(r['created_at'])), shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(serviceName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      Chip(label: Text(status)),
                                    ],
                                  ),
                                  Text('Applied: ${DateFormat('dd MMM yyyy').format(DateTime.parse(r['created_at']))} • ₹${r['amount']} • Payment: $paymentStatus'),
                                  if (r['application_number'] != null && r['application_number'] != '')
                                    Text('Ref #: ${r['application_number']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if (r['notes'] != null && r['notes'] != '')
                                    Text('Notes: ${r['notes']}', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (status == 'initiated')
                                        OutlinedButton(
                                          onPressed: () => _updateStatus(r['id'], 'under_process'),
                                          child: const Text('Start Processing'),
                                        ),
                                      if (status == 'under_process')
                                        OutlinedButton(
                                          onPressed: () => _updateStatus(r['id'], 'completed'),
                                          child: const Text('Mark Completed'),
                                        ),
                                      if (paymentStatus == 'pending')
                                        OutlinedButton(
                                          onPressed: () => _markPaymentReceived(r['id'], r['payment_method']),
                                          child: const Text('Mark Paid'),
                                        ),
                                      if (status != 'completed' && r['delegated_branch_id'] == null)
                                        OutlinedButton(
                                          onPressed: () => _showDelegateDialog(r['id']),
                                          child: const Text('Delegate'),
                                        ),
                                      if (r['delegated_branch_id'] != null)
                                        const Chip(label: Text('Delegated'), backgroundColor: Color(0xFFFFF3CD)),
                                      OutlinedButton(
                                        onPressed: () => _showEditRequestDetailsDialog(r),
                                        child: const Text('Edit Details'),
                                      ),
                                      if (status == 'completed' && paymentStatus == 'received')
                                        ElevatedButton.icon(
                                          onPressed: () => _showBill(r),
                                          icon: const Icon(Icons.receipt_long),
                                          label: const Text('View Bill'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
