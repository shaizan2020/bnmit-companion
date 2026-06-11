class SubjectMarks {
  final String subjectCode;
  final String subjectName;
  final String courseId;
  final String secId;
  final String semId;
  final List<CIEComponent> components;
  final List<String> facultyNames;

  const SubjectMarks({
    required this.subjectCode,
    required this.subjectName,
    required this.courseId,
    required this.secId,
    required this.semId,
    this.components = const [],
    this.facultyNames = const [],
  });

  double get totalObtained =>
      components.fold<double>(0, (sum, c) => sum + (c.obtained ?? 0));

  double get totalMax =>
      components.fold<double>(0, (sum, c) => sum + c.maxMarks);

  double get percentage => totalMax > 0 ? (totalObtained / totalMax) * 100 : 0;
}

class CIEComponent {
  final String name;
  final double? obtained;
  final double maxMarks;

  const CIEComponent({
    required this.name,
    this.obtained,
    required this.maxMarks,
  });

  double get percentage =>
      maxMarks > 0 && obtained != null ? (obtained! / maxMarks) * 100 : 0;

  bool get isAvailable => obtained != null;
}
