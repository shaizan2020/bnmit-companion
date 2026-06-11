import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bnmit_companion/models/marks.dart';
import 'package:bnmit_companion/services/marks_service.dart';
import 'package:bnmit_companion/providers/auth_provider.dart';

final marksServiceProvider = Provider<MarksService>((ref) {
  return MarksService(ref.read(authServiceProvider));
});

/// Key format: "courseId|secId|semId|subjectCode"
/// Using a String key so FutureProvider.family uses value equality (no infinite-rebuild bug).
final subjectMarksProvider = FutureProvider.family
    .autoDispose<SubjectMarks, String>((ref, key) async {
  final parts = key.split('|');
  final service = ref.read(marksServiceProvider);
  return service.getSubjectMarks(
    courseId: parts[0],
    secId: parts[1],
    semId: parts[2],
    subjectCode: parts[3],
  );
});
