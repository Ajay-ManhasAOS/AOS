import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UndepositedCashScreen extends StatefulWidget {
  const UndepositedCashScreen({super.key});
  @override
  State<UndepositedCashScreen> createState() => _UndepositedCashScreenState();
}

class _UndepositedCashScreenState extends State<UndepositedCashScreen> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res = await supabase
        .from('v_branch_cash_position')
        .select()
        .order('undeposited', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  double _n(dynamic v) => (v as num?)?.toDouble() ?? 0;
  String _m(double v) => '₹${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Undeposited Cash')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final rows = snap.data!;
          final total = rows.fold<double>(0, (a, r) => a + _n(r['undeposited']));
          final pending = rows.fold<double>(0, (a, r) => a + _n(r['pending_review']));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total cash with branches',
                            style: TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(_m(total),
                            style: const TextStyle(
                                fontSize: 28, fontWeight: FontWeight.bold)),
                        if (pending > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                '${_m(pending)} of deposits awaiting your review',
                                style: const TextStyle(color: Colors.deepOrange)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final r in rows)
                  Card(
                    child: ListTile(
                      title: Text(r['branch_name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Collected ${_m(_n(r['cash_collected']))}  •  Deposited ${_m(_n(r['deposited']))}'
                          '${_n(r['pending_review']) > 0 ? '  •  Pending ${_m(_n(r['pending_review']))}' : ''}'),
                      trailing: Text(_m(_n(r['undeposited'])),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _n(r['undeposited']) > 0
                                  ? Colors.deepOrange
                                  : Colors.green)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
