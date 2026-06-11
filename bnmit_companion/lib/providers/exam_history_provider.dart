import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bnmit_companion/services/exam_history_service.dart';
import 'package:bnmit_companion/providers/auth_provider.dart';

final examHistoryServiceProvider = Provider<ExamHistoryService>((ref) {
  return ExamHistoryService(ref.read(authServiceProvider));
});

/// Provider that fetches exam history using the student's USN
final examHistoryProvider = FutureProvider.autoDispose<ExamHistoryData>((ref) async {
  final service = ref.read(examHistoryServiceProvider);
  final authState = ref.watch(authStateProvider).valueOrNull;
  final usn = authState?.user?.usn ?? '';
  if (usn.isEmpty) throw Exception('USN not available. Please log in again.');
  return service.fetchHistory(usn);
});
