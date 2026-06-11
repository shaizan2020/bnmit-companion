import 'package:bnmit_companion/core/constants.dart';
import 'package:bnmit_companion/models/marks.dart';
import 'package:bnmit_companion/services/auth_service.dart';
import 'package:bnmit_companion/services/scraper_service.dart';

class MarksService {
  final AuthService _authService;
  final ScraperService _scraperService = ScraperService();

  MarksService(this._authService);

  Future<List<SubjectMarks>> getAllMarks(List<Map<String, String>> subjects) async {
    final marksList = <SubjectMarks>[];
    for (final subject in subjects) {
      try {
        final marks = await getSubjectMarks(
          courseId: subject['courseId']!,
          secId: subject['secId']!,
          semId: subject['semId']!,
          subjectCode: subject['code']!,
        );
        marksList.add(marks);
      } catch (_) {
        // Skip failed subjects
      }
    }
    return marksList;
  }

  Future<SubjectMarks> getSubjectMarks({
    required String courseId,
    required String secId,
    required String semId,
    required String subjectCode,
  }) async {
    final html = await _authService.fetchPage(
      '/index.php?${AppConstants.cieParams}&courseId=$courseId&secId=$secId&semId=$semId',
    );
    return _scraperService.parseSubjectMarks(html, subjectCode);
  }
}
