import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Col {
  final String key;
  final String label;
  final bool sum;
  const _Col(this.key, this.label, {this.sum = false});
}

class _Report {
  final String key;
  final String label;
  final String file;
  final List<_Col> cols;
  const _Report(this.key, this.label, this.file, this.cols);
}

const _reports = <_Report>[
  _Report('payments', 'Payments: every request, grouped by customer', 'payments', [
    _Col('applied_on', 'Applied on'),
    _Col('customer', 'Customer'),
    _Col('mobile', 'Mobile'),
    _Col('branch', 'Branch'),
    _Col('service', 'Service'),
    _Col('qty', 'Qty'),
    _Col('total_amount', 'Total (₹)', sum: true),
    _Col('discount', 'Discount (₹)', sum: true),
    _Col('govt_fee', 'Govt fee (₹)', sum: true),
    _Col('service_charge', 'Service charge (₹)', sum: true),
    _Col('payment_status', 'Payment'),
    _Col('payment_method', 'Method'),
    _Col('payment_received_on', 'Received on'),
    _Col('request_status', 'Status'),
    _Col('ref_no', 'Ref no'),
    _Col('operator', 'Operator'),
  ]),
  _Report('by_customer', 'Customer-wise summary', 'customer_summary', [
    _Col('customer', 'Customer'),
    _Col('mobile', 'Mobile'),
    _Col('requests', 'Requests', sum: true),
    _Col('total_billed', 'Total billed (₹)', sum: true),
    _Col('received', 'Received (₹)', sum: true),
    _Col('pending', 'Pending (₹)', sum: true),
    _Col('govt_fee', 'Govt fee (₹)', sum: true),
    _Col('discounts', 'Discounts (₹)', sum: true),
  ]),
  _Report('expenses', 'Expenses: approved and pending', 'expenses', [
    _Col('expense_date', 'Date'),
    _Col('branch', 'Branch'),
    _Col('category', 'Category'),
    _Col('amount', 'Amount (₹)'),
    _Col('approval_status', 'Status'),
    _Col('approved_amount', 'Approved (₹)', sum: true),
    _Col('pending_amount', 'Pending (₹)', sum: true),
    _Col('note', 'Note'),
    _Col('voucher_ref', 'Voucher ref'),
    _Col('entered_by', 'Entered by'),
    _Col('reviewed_by', 'Reviewed by'),
    _Col('reviewed_on', 'Reviewed on'),
  ]),
];

class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});
  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  final supabase = Supabase.instance.client;
  final _iso = DateFormat('yyyy-MM-dd');
  final _df = DateFormat('dd MMM yyyy');
  static const _maxShown = 500;

  _Report _report = _reports.first;
  String? _role;
  String? _branchFilter;
  List<Map<String, dynamic>> _branches = [];
  late DateTime _from;
  late DateTime _to;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>>? _rows;
  _Report? _shown;
  DateTime? _shownFrom;
  DateTime? _shownTo;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _from = DateTime(n.year, n.month, 1);
    _to = DateTime(n.year, n.month, n.day);
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final me = await supabase
          .from('staff')
          .select('role')
          .eq('id', supabase.auth.currentUser!.id)
          .single();
      var branches = <Map<String, dynamic>>[];
      if (me['role'] == 'admin') {
        branches = List<Map<String, dynamic>>.from(
            await supabase.from('branches').select('id, name').order('name'));
      }
      if (mounted) {
        setState(() {
          _role = me['role'] as String?;
          _branches = branches;
        });
      }
    } catch (_) {}
  }

  void _preset(String p) {
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    setState(() {
      switch (p) {
        case 'this_month':
          _from = DateTime(n.year, n.month, 1);
          _to = today;
          break;
        case 'last_month':
          _from = DateTime(n.year, n.month - 1, 1);
          _to = DateTime(n.year, n.month, 0);
          break;
        case 'last_7':
          _from = today.subtract(const Duration(days: 6));
          _to = today;
          break;
        case 'fy':
          _from = DateTime(n.month >= 4 ? n.year : n.year - 1, 4, 1);
          _to = today;
          break;
      }
    });
  }

  Future<void> _pick(bool isFrom) async {
    final d = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => isFrom ? _from = d : _to = d);
  }

  Future<void> _run() async {
    if (_from.isAfter(_to)) {
      setState(() => _error = 'The From date is after the To date.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await supabase.rpc('app_report', params: {
        'p_branch': _role == 'admin' ? _branchFilter : null,
        'p_report': _report.key,
        'p_from': _iso.format(_from),
        'p_to': _iso.format(_to),
      });
      final rows = (res as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _rows = rows;
        _shown = _report;
        _shownFrom = _from;
        _shownTo = _to;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load the report: $e';
        _loading = false;
      });
    }
  }

  String _raw(dynamic v) => v == null ? '' : v.toString();

  String _show(_Col c, dynamic v) {
    if (v == null) return '';
    if (c.sum && v is num && c.label.contains('₹')) return v.toStringAsFixed(2);
    return v.toString();
  }

  String _csvEsc(String s) => (s.contains(',') || s.contains('"') || s.contains('\n'))
      ? '"${s.replaceAll('"', '""')}"'
      : s;

  Future<void> _download() async {
    final rows = _rows;
    final rep = _shown;
    if (rows == null || rep == null) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download works in the desktop app.')),
      );
      return;
    }
    try {
      final sb = StringBuffer();
      sb.writeln(rep.cols.map((c) => _csvEsc(c.label)).join(','));
      for (final r in rows) {
        sb.writeln(rep.cols.map((c) => _csvEsc(_raw(r[c.key]))).join(','));
      }
      final name = '${rep.file}_${_iso.format(_shownFrom!)}_to_${_iso.format(_shownTo!)}.csv';
      var path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save report',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (path == null) return;
      if (!path.toLowerCase().endsWith('.csv')) path = '$path.csv';
      await File(path).writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(sb.toString())]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: $path')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  Widget _table(_Report rep, List<Map<String, dynamic>> rows) {
    final shown = rows.length > _maxShown ? rows.sublist(0, _maxShown) : rows;
    return Scrollbar(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 40,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 40,
            columns: [for (final c in rep.cols) DataColumn(label: Text(c.label), numeric: c.sum)],
            rows: [
              for (final r in shown)
                DataRow(cells: [for (final c in rep.cols) DataCell(Text(_show(c, r[c.key])))]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final rep = _shown;
    return Scaffold(
      appBar: AppBar(title: const Text('Data Export')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<_Report>(
                  value: _report,
                  items: [for (final r in _reports) DropdownMenuItem(value: r, child: Text(r.label))],
                  onChanged: (v) => setState(() => _report = v!),
                ),
                if (_role == 'admin')
                  DropdownButton<String?>(
                    value: _branchFilter,
                    hint: const Text('All branches'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All branches')),
                      for (final b in _branches)
                        DropdownMenuItem<String?>(value: b['id'] as String, child: Text(b['name'] as String)),
                    ],
                    onChanged: (v) => setState(() => _branchFilter = v),
                  ),
                if (_role != null && _role != 'admin')
                  Chip(
                    avatar: const Icon(Icons.info_outline, size: 18),
                    label: Text(_role == 'manager' ? 'Your branch' : 'Your own entries'),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event, size: 18),
                  label: Text('From ${_df.format(_from)}'),
                  onPressed: () => _pick(true),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_available, size: 18),
                  label: Text('To ${_df.format(_to)}'),
                  onPressed: () => _pick(false),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Quick ranges',
                  onSelected: _preset,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'this_month', child: Text('This month')),
                    PopupMenuItem(value: 'last_month', child: Text('Last month')),
                    PopupMenuItem(value: 'last_7', child: Text('Last 7 days')),
                    PopupMenuItem(value: 'fy', child: Text('This financial year (Apr-Mar)')),
                  ],
                  child: const Chip(avatar: Icon(Icons.date_range, size: 18), label: Text('Quick range')),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Show'),
                  onPressed: _loading ? null : _run,
                ),
                if (rows != null && rows.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Download CSV'),
                    onPressed: _download,
                  ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (rows != null && rep != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                '${rows.length} rows • ${_df.format(_shownFrom!)} to ${_df.format(_shownTo!)}'
                '${rows.length > _maxShown ? ' • showing first $_maxShown, download for all' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final c in rep.cols.where((c) => c.sum))
                    Chip(
                      label: Text(
                        '${c.label}: ${rows.fold<double>(0, (a, r) => a + ((r[c.key] as num?)?.toDouble() ?? 0)).toStringAsFixed(c.label.contains('₹') ? 2 : 0)}',
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 8),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No records in this date range.'))
                  : _table(rep, rows),
            ),
          ] else if (!_loading)
            const Expanded(child: Center(child: Text('Choose a report and dates, then press Show.'))),
        ],
      ),
    );
  }
}
