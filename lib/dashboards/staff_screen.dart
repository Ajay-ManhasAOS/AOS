import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _branches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final staffData = await supabase.from('staff').select('*, branches(name)').order('created_at');
    final branchData = await supabase.from('branches').select();
    setState(() {
      _staff = List<Map<String, dynamic>>.from(staffData);
      _branches = List<Map<String, dynamic>>.from(branchData);
      _loading = false;
    });
  }

  Future<void> _generateAppointmentLetter(Map<String, dynamic> staff) async {
  final doc = pw.Document();
  final today = DateFormat('dd MMMM yyyy').format(DateTime.now());
  final doj = staff['date_of_joining'] != null
      ? DateFormat('dd MMMM yyyy').format(DateTime.parse(staff['date_of_joining']))
      : today;
  final branchName = staff['branches']?['name'] ?? '';
  final logoBytes = await rootBundle.load('assets/logo.png');
  final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  crossAxisAlignment: pw.CrossAxisAlignment.center,
  children: [
    pw.Text('AM Online Solutions', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
    pw.Image(logo, width: 60, height: 60),
  ],
),
pw.SizedBox(height: 4),
pw.Text('Branch: $branchName'),
          pw.SizedBox(height: 24),
          pw.Text('Date: $today'),
          pw.SizedBox(height: 24),
          pw.Text('APPOINTMENT LETTER', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          pw.Text('Dear ${staff['name']},'),
          pw.SizedBox(height: 12),
          pw.Text(
            'We are pleased to appoint you as ${staff['role']} at our ${branchName.isNotEmpty ? branchName : 'branch'} location, '
            'effective from $doj. Your monthly remuneration will be Rs. ${staff['salary'] ?? '0'}, subject to applicable '
            'incentives as per company policy.',
          ),
          pw.SizedBox(height: 12),
          if (staff['phone'] != null && staff['phone'] != '')
            pw.Text('Contact Number on File: ${staff['phone']}'),
          if (staff['address'] != null && staff['address'] != '')
            pw.Text('Address on File: ${staff['address']}'),
          pw.SizedBox(height: 12),
          pw.Text(
            'You are expected to adhere to the company\'s policies, procedures, and code of conduct as communicated to '
            'you from time to time. This appointment is subject to the terms discussed with you.',
          ),
          pw.SizedBox(height: 12),
          pw.Text('We look forward to a long and successful association with you.'),
          pw.SizedBox(height: 32),
          pw.Text('For AM Online Solutions'),
          pw.SizedBox(height: 32),
          pw.Text('Authorized Signatory'),
        ],
      ),
    ),
  );

  final bytes = await doc.save();
  final safeName = (staff['name'] as String).replaceAll(' ', '_');
  await Printing.layoutPdf(
    onLayout: (format) async => bytes,
    name: 'Appointment_Letter_$safeName',
  );
}

  Future<void> _showAddStaffDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final salaryController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final emergencyNameController = TextEditingController();
    final emergencyPhoneController = TextEditingController();
    DateTime? dateOfJoining;
    String role = 'operator';
    String? branchId = _branches.isNotEmpty ? _branches.first['id'] : null;
    String? error;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Staff'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Full Name')),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email (login)')),
                TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone Number'), keyboardType: TextInputType.phone),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(dateOfJoining == null ? 'Date of Joining' : DateFormat('dd MMM yyyy').format(dateOfJoining!)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2015),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => dateOfJoining = picked);
                  },
                ),
                TextField(controller: emergencyNameController, decoration: const InputDecoration(labelText: 'Emergency Contact Name')),
                TextField(controller: emergencyPhoneController, decoration: const InputDecoration(labelText: 'Emergency Contact Phone'), keyboardType: TextInputType.phone),
                TextField(controller: salaryController, decoration: const InputDecoration(labelText: 'Salary'), keyboardType: TextInputType.number),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'operator', child: Text('Operator')),
                    DropdownMenuItem(value: 'manager', child: Text('Manager')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin (Partner)')),
                  ],
                  onChanged: (v) => setDialogState(() => role = v!),
                ),
                DropdownButtonFormField<String>(
                  value: branchId,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: _branches.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name']))).toList(),
                  onChanged: (v) => setDialogState(() => branchId = v),
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
              onPressed: submitting
                  ? null
                  : () async {
                      setDialogState(() {
                        submitting = true;
                        error = null;
                      });
                      try {
                        final response = await supabase.functions.invoke(
                          'create-staff',
                          body: {
                            'name': nameController.text.trim(),
                            'email': emailController.text.trim(),
                            'password': passwordController.text,
                            'role': role,
                            'branch_id': branchId,
                            'salary': double.tryParse(salaryController.text) ?? 0,
                            'phone': phoneController.text.trim(),
                            'address': addressController.text.trim(),
                            'date_of_joining': dateOfJoining?.toIso8601String().split('T')[0],
                            'emergency_contact_name': emergencyNameController.text.trim(),
                            'emergency_contact_phone': emergencyPhoneController.text.trim(),
                          },
                        );
                        final data = response.data;
                        if (data is Map && data['error'] != null) {
                          setDialogState(() {
                            error = data['error'].toString();
                            submitting = false;
                          });
                          return;
                        }
                        if (context.mounted) Navigator.pop(context);
                        _loadData();
                      } catch (e) {
                        setDialogState(() {
                          error = 'Failed to create staff. Please try again.';
                          submitting = false;
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showStatusDialog(Map<String, dynamic> staff) async {
    String status = staff['status'] ?? 'active';
    DateTime? leavingDate = staff['date_of_leaving'] != null
        ? DateTime.parse(staff['date_of_leaving'])
        : null;
    String? error;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Update Status: ${staff['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (staff['phone'] != null && staff['phone'] != '') Text('Phone: ${staff['phone']}'),
                if (staff['address'] != null && staff['address'] != '') Text('Address: ${staff['address']}'),
                if (staff['date_of_joining'] != null)
                  Text('Joined: ${DateFormat('dd MMM yyyy').format(DateTime.parse(staff['date_of_joining']))}'),
                if (staff['emergency_contact_name'] != null && staff['emergency_contact_name'] != '')
                  Text('Emergency Contact: ${staff['emergency_contact_name']} (${staff['emergency_contact_phone'] ?? ''})'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'on_leave', child: Text('On Leave')),
                    DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                    DropdownMenuItem(value: 'resigned', child: Text('Resigned')),
                  ],
                  onChanged: (v) => setDialogState(() => status = v!),
                ),
                if (status == 'resigned')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(leavingDate == null
                          ? 'Select last working day'
                          : 'Last working day: ${DateFormat('dd MMM yyyy').format(leavingDate!)}'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: leavingDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDialogState(() => leavingDate = picked);
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
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (status == 'resigned' && leavingDate == null) {
                    setDialogState(() => error = 'Please select the last working day.');
                    return;
                  }
                  await supabase.from('staff').update({
                    'status': status,
                    'date_of_leaving': status == 'resigned'
                        ? DateFormat('yyyy-MM-dd').format(leavingDate!)
                        : null,
                  }).eq('id', staff['id']);
                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  setDialogState(() => error = 'Failed to update status.');
                }
              },
              child: const Text('Save'),
            ),
            TextButton.icon(
              onPressed: () => _generateAppointmentLetter(staff),
              icon: const Icon(Icons.description),
              label: const Text('Appointment Letter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetPassword(String staffId, String staffName) async {
    final ctrl = TextEditingController();
    final pwd = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset password: $staffName'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New temporary password',
            helperText: 'At least 6 characters. Ask them to change it after login.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (pwd == null) return;

    String msg;
    if (pwd.length < 6) {
      msg = 'Password must be at least 6 characters';
    } else {
      try {
        await supabase.functions.invoke(
          'reset-staff-password',
          body: {'staff_id': staffId, 'new_password': pwd},
        );
        msg = 'Password reset for $staffName';
      } on FunctionException catch (e) {
        final d = e.details;
        msg = 'Failed: ${d is Map && d['error'] != null ? d['error'] : e.reasonPhrase}';
      } catch (e) {
        msg = 'Failed: $e';
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _staff.isEmpty
              ? const Center(child: Text('No staff yet. Tap + to add one.'))
              : ListView.builder(
                  itemCount: _staff.length,
                  itemBuilder: (context, index) {
                    final s = _staff[index];
                    final branchName = s['branches']?['name'] ?? 'Unassigned';
                    return ListTile(
                      title: Text(s['name'] ?? ''),
                      subtitle: Text('${s['role']} • $branchName • ${s['status']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.lock_reset),
                        tooltip: 'Reset password',
                        onPressed: () => _resetPassword(s['id'], s['name'] ?? ''),
                      ),
                      onTap: () => _showStatusDialog(s),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _branches.isEmpty
            ? null
            : _showAddStaffDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
