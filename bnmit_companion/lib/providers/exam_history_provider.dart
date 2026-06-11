import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bnmit_companion/models/exam_result.dart';
import 'package:bnmit_companion/services/exam_history_service.dart';
import 'package:bnmit_companion/providers/auth_provider.dart';

final examHistoryServiceProvider = Provider<ExamHistoryService>((ref) {
  return ExamHistoryService(ref.read(authServiceProvider));
});

/// Provider for the list of available exam sessions
final examSessionsProvider = FutureProvider.autoDispose<List<Map<String, String>>>((ref) async {
  final service = ref.read(examHistoryServiceProvider);
  return service.fetchExamSessions();
});

/// Provider for a specific exam result by semId
final examResultProvider = FutureProvider.family.autoDispose<ExamResult, String>((ref, semId) async {
  final service = ref.read(examHistoryServiceProvider);
  return service.fetchExamResult(semId);
});
