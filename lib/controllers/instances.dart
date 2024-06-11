import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/services/supabase.dart';
import 'package:squad_quest/models/instance.dart';

final instancesProvider =
    AsyncNotifierProvider<InstancesController, List<Instance>>(
        InstancesController.new);

class InstancesController extends AsyncNotifier<List<Instance>> {
  @override
  Future<List<Instance>> build() async {
    return fetch();
  }

  Future<List<Instance>> fetch() async {
    final supabase = ref.read(supabaseProvider);

    return supabase
        .from('instances')
        .select('*, topic(*), created_by(*)')
        .order('start_time_min', ascending: true)
        .withConverter((data) => data.map(Instance.fromMap).toList());
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(fetch);
  }
}
