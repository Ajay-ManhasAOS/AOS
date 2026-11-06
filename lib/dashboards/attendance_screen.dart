import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final supabase = Supabase.instance.client;
  late DateTime _month;
  bool _loading = true;
  bool _lateOnly = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  final Map<String, String> _names = {};
  String _shift = '09:50';

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month, 1);
    _load();
  }

  bool get _isCurrent {
    final n = DateTime.now();
    return !_month.isBefore(DateTime(n.year, n.month, 1));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final f = DateFormat('yyyy-MM-dd');
      final start = f.format(_month);
      final end = f.format(DateTime(_month.year, _month.month + 1, 1));
      final rows = await supabase
          .from('attendance')
          .select('staff_id, login_time, attendance_date, is_late, minutes_late')
          .gte('attendance_date', start)
          .lt('attendance_date', end)
          .order('attendance_date');
      final staff = await supabase.from('staff').select('id, name');
      final cfg = await supabase.from('attendance_settings').select('shift_start').eq('id', 1).maybeSingle();
      _names.clear();
      for (final s in staff) {
        _names[s['id'] as String] = (s['name'] ?? '') as String;
      }
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _shift = (cfg?['shift_start'] ?? '09:50').toString().substring(0, 5);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is PostgrestException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  // Login time shown in India time whatever the device's own timezone is.
  String _ist(String iso) {
    final t = DateTime.parse(iso).toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('hh:mm a').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final byStaff = <String, List<Map<String, dynamic>>>{};
    for (final r in _rows) {
      byStaff.putIfAbsent(r['staff_id'] as String, () => []).add(r);
    }
    final ids = byStaff.keys.toList()
      ..sort((a, b) {
        int lates(String id) => byStaff[id]!.where((r) => r['is_late'] == true).length;
        final c = lates(b).compareTo(lates(a));
        return c != 0 ? c : (_names[a] ?? '').compareTo(_names[b] ?? '');
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: $_error')))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shiftMonth(-1)),
                          Text(DateFormat('MMMM yyyy').format(_month),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _isCurrent ? null : () => _shiftMonth(1)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('Shift starts $_shift (India time). Warn-only: no salary effect.',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
                            FilterChip(
                              label: const Text('Late only'),
                              selected: _lateOnly,
                              onSelected: (v) => setState(() => _lateOnly = v),
                            ),
                          ],
                        ),
                      ),
                      if (ids.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No attendance recorded this month.')),
                      for (final id in ids)
                        _staffCard(_names[id] ?? 'Unknown', byStaff[id]!),
                    ],
                  ),
                ),
    );
  }

  Widget _staffCard(String name, List<Map<String, dynamic>> rows) {
    final lates = rows.where((r) => r['is_late'] == true).toList();
    final totalMin = lates.fold<int>(0, (a, r) => a + ((r['minutes_late'] as num?)?.toInt() ?? 0));
    final shown = (_lateOnly ? lates : rows).toList()
      ..sort((a, b) => (b['attendance_date'] as String).compareTo(a['attendance_date'] as String));
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Present ${rows.length} days • Late ${lates.length} • Total late $totalMin min'),
        trailing: lates.isEmpty
            ? const Icon(Icons.check_circle, color: Colors.green)
            : CircleAvatar(
                radius: 14,
                backgroundColor: Colors.orange.shade100,
                child: Text('${lates.length}', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
              ),
        children: [
          if (shown.isEmpty) const ListTile(dense: true, title: Text('No late marks')),
          for (final r in shown)
            ListTile(
              dense: true,
              title: Text(DateFormat('EEE, dd MMM').format(DateTime.parse(r['attendance_date'] as String))),
              subtitle: Text('Login ${_ist(r['login_time'] as String)}'),
              trailing: r['is_late'] == true
                  ? Chip(
                      label: Text('Late ${r['minutes_late']} min', style: TextStyle(color: Colors.orange.shade900, fontSize: 12)),
                      backgroundColor: Colors.orange.shade50,
                      visualDensity: VisualDensity.compact,
                    )
                  : const Text('On time', style: TextStyle(color: Colors.green)),
            ),
        ],
      ),
    );
  }
}
