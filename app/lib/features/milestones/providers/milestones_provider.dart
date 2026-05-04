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
    state = AsyncData(
      [...?state.value, m]..sort((a, b) => a.date.compareTo(b.date)),
    );
  }

  Future<void> remove(String id) async {
    await _service.delete(id);
    final List<Milestone> currentList = state.value ?? [];
    state = AsyncData(currentList.where((m) => m.id != id).toList());
  }

  Future<void> updateMilestone(Milestone updated) async {
    final List<Milestone> list = [...?state.value];
    final idx = list.indexWhere((m) => m.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
      list.sort((a, b) => a.date.compareTo(b.date));
      state = AsyncData(list);
    }
  }
}

final milestonesProvider =
    AsyncNotifierProvider<MilestonesNotifier, List<Milestone>>(
      MilestonesNotifier.new,
    );