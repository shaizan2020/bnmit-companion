class TimetableDay {
  final String dayName;
  final String date;
  final List<ClassPeriod> periods;

  const TimetableDay({
    required this.dayName,
    required this.date,
    this.periods = const [],
  });

  bool get isToday {
    final now = DateTime.now();
    final parts = date.split('-');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]) ?? 0;
      final month = int.tryParse(parts[1]) ?? 0;
      final year = int.tryParse(parts[2]) ?? 0;
      return now.day == day && now.month == month && now.year == year;
    }
    return false;
  }
}

class ClassPeriod {
  final String subjectCode;
  final String subjectName;
  final String faculty;
  final String startTime;
  final String endTime;
  final String room;
  final String? type; // Lecture, Lab, Tutorial

  const ClassPeriod({
    required this.subjectCode,
    required this.subjectName,
    required this.faculty,
    required this.startTime,
    required this.endTime,
    this.room = '',
    this.type,
  });

  String get timeRange => '$startTime - $endTime';
}

class WeekTimetable {
  final List<TimetableDay> days;
  final String? prevWeekStart;
  final String? prevWeekEnd;
  final String? nextWeekStart;
  final String? nextWeekEnd;

  const WeekTimetable({
    required this.days,
    this.prevWeekStart,
    this.prevWeekEnd,
    this.nextWeekStart,
    this.nextWeekEnd,
  });
}
