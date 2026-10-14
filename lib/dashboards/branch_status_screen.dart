import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final branchSummaryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('v_branch_status_summary')
      .select()
      .order('branch_name');
  return List<Map<String, dynamic>>.from(res);
});

class BranchStatusScreen extends ConsumerWidget {
  const BranchStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(branchSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Branch-wise Status')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rows) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Branch')),
                DataColumn(label: Text('Pending'), numeric: true),
                DataColumn(label: Text('Under Process'), numeric: true),
                DataColumn(label: Text('Overdue (>7d)'), numeric: true),
                DataColumn(label: Text('Oldest (d)'), numeric: true),
                DataColumn(label: Text('Avg age (d)'), numeric: true),
                DataColumn(label: Text('Done this month'), numeric: true),
              ],
              rows: [
                for (final r in rows)
                  DataRow(cells: [
                    DataCell(Text('${r['branch_name']}')),
                    DataCell(Text('${r['pending']}')),
                    DataCell(Text('${r['under_process']}')),
                    DataCell(Text('${r['overdue']}',
                        style: TextStyle(
                            color: (r['overdue'] as int) > 0
                                ? Colors.red
                                : null,
                            fontWeight: FontWeight.bold))),
                    DataCell(Text('${r['oldest_days']}')),
                    DataCell(Text('${r['avg_days']}')),
                    DataCell(Text('${r['completed_this_month']}')),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
