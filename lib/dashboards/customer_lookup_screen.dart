import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'customer_detail_screen.dart';

class CustomerLookupScreen extends StatefulWidget {
  const CustomerLookupScreen({super.key});

  @override
  State<CustomerLookupScreen> createState() => _CustomerLookupScreenState();
}

class _CustomerLookupScreenState extends State<CustomerLookupScreen> {
  final supabase = Supabase.instance.client;
  final mobileController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searched = false;
  bool _loading = false;

  Future<void> _search() async {
    final query = mobileController.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      final data = await supabase
          .from('customers')
          .select()
          .or('mobile_number.ilike.%$query%,name.ilike.%$query%')
          .limit(20);
      setState(() {
        _results = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _results = [];
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  Future<void> _showAddCustomerDialog({String? prefillMobile}) async {
    final mobileFieldController = TextEditingController(text: prefillMobile ?? mobileController.text.trim());
    final nameController = TextEditingController();
    final dobController = TextEditingController();
    final addressController = TextEditingController();
    final aadhaarController = TextEditingController();
    final panController = TextEditingController();
    final voterController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Customer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: mobileFieldController,
                  decoration: const InputDecoration(labelText: 'Mobile Number'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
                TextField(controller: dobController, decoration: const InputDecoration(labelText: 'DOB (YYYY-MM-DD)')),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
                TextField(controller: aadhaarController, decoration: const InputDecoration(labelText: 'Aadhaar Number')),
                TextField(controller: panController, decoration: const InputDecoration(labelText: 'PAN Number')),
                TextField(controller: voterController, decoration: const InputDecoration(labelText: 'Voter ID')),
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
                if (mobileFieldController.text.trim().isEmpty || nameController.text.trim().isEmpty) {
                  setDialogState(() => error = 'Mobile number and name are required');
                  return;
                }
                try {
                  final inserted = await supabase.from('customers').insert({
                    'mobile_number': mobileFieldController.text.trim(),
                    'name': nameController.text.trim(),
                    'dob': dobController.text.trim().isEmpty ? null : dobController.text.trim(),
                    'address': addressController.text.trim(),
                    'aadhaar_number': aadhaarController.text.trim(),
                    'pan_number': panController.text.trim(),
                    'voter_id': voterController.text.trim(),
                  }).select().single();
                  if (context.mounted) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: inserted)),
                    );
                  }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find / Add Customer')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: mobileController,
                    decoration: const InputDecoration(labelText: 'Search by Mobile or Name'),
                    keyboardType: TextInputType.phone,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _search, child: const Text('Search')),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _searched && _results.isEmpty)
              Column(
                children: [
                  const Text('No customer found with this number.'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showAddCustomerDialog(),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add New Customer'),
                  ),
                ],
              ),
            if (!_loading && _results.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: OutlinedButton.icon(
                  onPressed: () => _showAddCustomerDialog(prefillMobile: mobileController.text.trim()),
                  icon: const Icon(Icons.group_add),
                  label: const Text('Add Family Member (same number)'),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final c = _results[index];
                    return Card(
                      child: ListTile(
                        title: Text(c['name'] ?? ''),
                        subtitle: Text(c['mobile_number'] ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: c)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCustomerDialog(),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
