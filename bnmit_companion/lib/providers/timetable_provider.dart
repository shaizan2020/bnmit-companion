import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bnmit_companion/models/timetable.dart';
import 'package:bnmit_companion/services/timetable_service.dart';
import 'package:bnmit_companion/providers/auth_provider.dart';

final timetableServiceProvider = Provider<TimetableService>((ref) {
  return TimetableService(ref.read(authServiceProvider));
});

final timetableProvider =
    AsyncNotifierProvider<TimetableNotifier, WeekTimetable>(
        TimetableNotifier.new);

class TimetableNotifier extends AsyncNotifier<WeekTimetable> {
  @override
  Future<WeekTimetable> build() async {
    final service = ref.read(timetableServiceProvider);
    return service.getCurrentWeekTimetable();
  }

  Future<void> loadPreviousWeek(String start, String end) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(timetableServiceProvider);
      return service.getWeekTimetable(start: start, end: end, type: 'prev');
    });
  }

  Future<void> loadNextWeek(String start, String end) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(timetableServiceProvider);
      return service.getWeekTimetable(start: start, end: end, type: 'next');
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(timetableServiceProvider);
      return service.getCurrentWeekTimetable();
    });
  }
}
