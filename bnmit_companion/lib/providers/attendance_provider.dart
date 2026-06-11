import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bnmit_companion/models/attendance.dart';
import 'package:bnmit_companion/services/attendance_service.dart';
import 'package:bnmit_companion/providers/auth_provider.dart';

final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  return AttendanceService(ref.read(authServiceProvider));
});

final attendanceSummaryProvider =
    AsyncNotifierProvider<AttendanceSummaryNotifier, AttendanceSummary>(
        AttendanceSummaryNotifier.new);

class AttendanceSummaryNotifier extends AsyncNotifier<AttendanceSummary> {
  @override
  Future<AttendanceSummary> build() async {
    final service = ref.read(attendanceServiceProvider);
    return service.getAttendanceSummary();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(attendanceServiceProvider);
      return service.getAttendanceSummary();
    });
  }
}

final subjectAttendanceProvider = FutureProvider.family
    .autoDispose<SubjectAttendance, Map<String, String>>((ref, params) async {
  final service = ref.read(attendanceServiceProvider);
  return service.getSubjectAttendance(
    courseId: params['courseId']!,
    secId: params['secId']!,
    semId: params['semId']!,
    subjectCode: params['code']!,
  );
});
