class SubjectAttendance {
  final String subjectCode;
  final String subjectName;
  final int totalClasses;
  final int attendedClasses;
  final int absentClasses;
  final double percentage;
  final String courseId;
  final String secId;
  final String semId;
  final List<AttendanceRecord> presentRecords;
  final List<AttendanceRecord> absentRecords;
  final List<String> facultyNames;

  const SubjectAttendance({
    required this.subjectCode,
    required this.subjectName,
    required this.totalClasses,
    required this.attendedClasses,
    required this.absentClasses,
    required this.percentage,
    required this.courseId,
    required this.secId,
    required this.semId,
    this.presentRecords = const [],
    this.absentRecords = const [],
    this.facultyNames = const [],
  });

  bool get isShortage => percentage < 75;
  bool get isWarning => percentage >= 75 && percentage < 80;
  bool get isGood => percentage >= 80;

  int get classesNeededFor75 {
    if (percentage >= 75) return 0;
    // Formula: (attended + x) / (total + x) >= 0.75
    // attended + x >= 0.75 * total + 0.75 * x
    // 0.25x >= 0.75 * total - attended
    // x >= (0.75 * total - attended) / 0.25
    final needed = ((0.75 * totalClasses - attendedClasses) / 0.25).ceil();
    return needed > 0 ? needed : 0;
  }

  int get classesCanSkipFor75 {
    if (percentage < 75) return 0;
    // Formula: attended / (total + x) >= 0.75
    // attended >= 0.75 * total + 0.75 * x
    // 0.75x <= attended - 0.75 * total
    // x <= (attended - 0.75 * total) / 0.75
    final canSkip = ((attendedClasses - 0.75 * totalClasses) / 0.75).floor();
    return canSkip > 0 ? canSkip : 0;
  }
}

class AttendanceRecord {
  final int slNo;
  final String date;
  final String time;
  final String status;

  const AttendanceRecord({
    required this.slNo,
    required this.date,
    required this.time,
    required this.status,
  });

  bool get isPresent => status.trim().toLowerCase() == 'present';
}

class AttendanceSummary {
  final List<SubjectAttendance> subjects;
  final int shortageCount;

  const AttendanceSummary({
    required this.subjects,
    required this.shortageCount,
  });

  double get overallPercentage {
    if (subjects.isEmpty) return 0;
    final totalAttended = subjects.fold<int>(0, (sum, s) => sum + s.attendedClasses);
    final totalClasses = subjects.fold<int>(0, (sum, s) => sum + s.totalClasses);
    if (totalClasses == 0) return 0;
    return (totalAttended / totalClasses) * 100;
  }
}
