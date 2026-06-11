import 'package:bnmit_companion/core/constants.dart';
import 'package:bnmit_companion/models/attendance.dart';
import 'package:bnmit_companion/services/auth_service.dart';
import 'package:bnmit_companion/services/scraper_service.dart';

class AttendanceService {
  final AuthService _authService;
  final ScraperService _scraperService = ScraperService();

  AttendanceService(this._authService);

  Future<AttendanceSummary> getAttendanceSummary() async {
    final html = await _authService.fetchPage(
      '/index.php?${AppConstants.dashboardParams}',
    );
    return _scraperService.parseDashboardAttendance(html);
  }

  Future<SubjectAttendance> getSubjectAttendance({
    required String courseId,
    required String secId,
    required String semId,
    required String subjectCode,
  }) async {
    final html = await _authService.fetchPage(
      '/index.php?${AppConstants.attendanceParams}&courseId=$courseId&secId=$secId&semId=$semId',
    );
    return _scraperService.parseSubjectAttendance(html, subjectCode);
  }
}
