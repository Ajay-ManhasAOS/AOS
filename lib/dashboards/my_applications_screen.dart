import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final myAgingProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = Supabase.instance.client;
  final res = await db
      .from('v_request_aging')
      .select()
      .eq('created_by', db.auth.currentUser!.id)
      .order('days_open', ascending: false);
  return List<Map<String, dynamic>>.from(res);
});

class MyApplicationsScreen extends ConsumerWidget {
  const MyApplicationsScreen({super.key});

  Color _ageColor(int d) =>
      d <= 3 ? Colors.green : (d <= 7 ? Colors.orange : Colors.red);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAgingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Applications')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rows) {
          final pending =
              rows.where((r) => r['status'] == 'initiated').toList();
          final inProc =
              rows.where((r) => r['status'] == 'under_process').toList();

          Widget section(String title, List<Map<String, dynamic>> list) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('$title (${list.length})',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  if (list.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('None')),
                  for (final r in list)
                    Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 6,
                          backgroundColor: _ageColor(r['days_open'] as int),
                        ),
                        title: Text('${r['customer_name']}'),
                        subtitle: Text('${r['service_name']}'),
                        trailing: Text(
                          r['days_open'] == 0 ? 'Today' : '${r['days_open']} d',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(myAgingProvider.future),
            child: ListView(children: [
              section('Pending', pending),
              section('Under Process', inProc),
            ]),
          );
        },
      ),
    );
  }
}
