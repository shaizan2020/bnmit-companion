import 'package:bnmit_companion/core/constants.dart';
import 'package:bnmit_companion/models/timetable.dart';
import 'package:bnmit_companion/services/auth_service.dart';
import 'package:bnmit_companion/services/scraper_service.dart';

class TimetableService {
  final AuthService _authService;
  final ScraperService _scraperService = ScraperService();

  TimetableService(this._authService);

  Future<WeekTimetable> getCurrentWeekTimetable() async {
    final html = await _authService.fetchPage(
      '/index.php?${AppConstants.timetableParams}',
    );
    return _scraperService.parseTimetable(html);
  }

  Future<WeekTimetable> getWeekTimetable({
    required String start,
    required String end,
    required String type,
  }) async {
    final params = type == 'prev'
        ? 'prevstart=$start&prevend=$end&type=prev'
        : 'nextstart=$start&nextend=$end&type=next';

    final html = await _authService.fetchPage(
      '/index.php?${AppConstants.timetableParams}&j=${type == 'next' ? '1' : ''}&$params',
    );
    return _scraperService.parseTimetable(html);
  }
}
