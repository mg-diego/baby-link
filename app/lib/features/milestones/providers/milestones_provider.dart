import 'package:app/shared/models/milestone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/milestone_service.dart';

final _service = MilestoneService();

class MilestonesNotifier extends AsyncNotifier<List<Milestone>> {
  late String _babyId;

  void init(String babyId) => _babyId = babyId;

  @override
  Future<List<Milestone>> build() async => [];

  Future<void> load(String babyId) async {
    _babyId = babyId;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.fetchAll(babyId));
  }

  Future<void> add(Milestone m) async {
    state = AsyncData([...state.value ?? [], m]
      ..sort((a, b) => a.date.compareTo(b.date)));
  }

  Future<void> remove(String id) async {
    await _service.delete(id);
    state = AsyncData(
      (state.value ?? []).where((m) => m.id != id).toList(),
    );
  }
}

final milestonesProvider =
    AsyncNotifierProvider<MilestonesNotifier, List<Milestone>>(
        MilestonesNotifier.new);