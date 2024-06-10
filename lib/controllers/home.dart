// import 'dart:async';
// import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squad_quest/services/supabase.dart';

final instancesListProvider =
    AsyncNotifierProvider<InstancesList, List<Map>>(InstancesList.new);

class InstancesList extends AsyncNotifier<List<Map>> {
  @override
  Future<List<Map>> build() async {
    return fetch();
  }

  Future<List<Map>> fetch() async {
    final supabase = ref.read(supabaseProvider);

    final instances = await supabase
        .from('instances')
        .select('*, topic(*), created_by(*)')
        .order('start_time_min', ascending: true);

    return instances;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(fetch);
  }
}

class HomeController extends AsyncNotifier<void> {
  @override
  void build() {}
}
