import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bnmit_companion/services/exam_history_service.dart';
import 'package:bnmit_companion/providers/auth_provider.dart';

final examHistoryServiceProvider = Provider<ExamHistoryService>((ref) {
  return ExamHistoryService(ref.read(authServiceProvider));
});

/// Fetches all semester results + grade card details in one request.
final examHistoryProvider =
    FutureProvider.autoDispose<ExamHistoryData>((ref) async {
  final service = ref.read(examHistoryServiceProvider);
  final authState = ref.watch(authStateProvider).valueOrNull;
  final usn = authState?.user?.usn ?? '';
  if (usn.isEmpty) throw Exception('USN not available. Please log in again.');
  return service.fetchHistory(usn);
});

/// Currently selected semester index (null = none selected yet).
final selectedSemesterIndexProvider = StateProvider<int?>((ref) => null);

/// Returns cached grade card for selected semester — no extra network call.
final gradeCardProvider =
    Provider.autoDispose<GradeCardDetails?>((ref) {
  final historyAsync = ref.watch(examHistoryProvider);
  final selectedIndex = ref.watch(selectedSemesterIndexProvider);

  return historyAsync.when(
    data: (data) {
      if (selectedIndex == null || selectedIndex >= data.semesters.length) {
        return null;
      }
      final sem = data.semesters[selectedIndex];
      return data.gradeCards[sem.semId];
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
