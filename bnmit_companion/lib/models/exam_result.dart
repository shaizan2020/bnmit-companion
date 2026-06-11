class ExamResult {
  final String semester;
  final String examType;
  final List<SubjectResult> subjects;

  const ExamResult({
    required this.semester,
    required this.examType,
    required this.subjects,
  });

  double get sgpa {
    if (subjects.isEmpty) return 0;
    final total = subjects.fold<double>(0, (sum, s) => sum + (s.sgpa ?? 0));
    return total / subjects.length;
  }

  int get totalCredits =>
      subjects.fold<int>(0, (sum, s) => sum + (s.credits ?? 0));

  int get passCount => subjects.where((s) => s.isPassed).length;
  int get failCount => subjects.where((s) => !s.isPassed).length;
}

class SubjectResult {
  final String subjectCode;
  final String subjectName;
  final String? grade;
  final double? marks;
  final double? maxMarks;
  final int? credits;
  final double? sgpa;
  final bool isPassed;

  const SubjectResult({
    required this.subjectCode,
    required this.subjectName,
    this.grade,
    this.marks,
    this.maxMarks,
    this.credits,
    this.sgpa,
    required this.isPassed,
  });

  double get percentage =>
      (maxMarks != null && maxMarks! > 0 && marks != null)
          ? (marks! / maxMarks!) * 100
          : 0;
}
