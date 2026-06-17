import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:bnmit_companion/services/auth_service.dart';

class ExamHistoryService {
  final AuthService _authService;

  ExamHistoryService(this._authService);

  /// Fetch the list of semesters + all grade card data from the getResult page.
  /// No secondary network calls are made — everything is extracted in one request.
  Future<ExamHistoryData> fetchHistory(String usn) async {
    final html = await _authService.fetchPage(
      'index.php?option=com_history&task=getResult&usn=$usn',
    );
    debugPrint('EXAM HISTORY: fetched ${html.length} bytes for usn=$usn');
    return _parseHistory(html, usn);
  }

  /// Returns the cached grade card for the given semester (no network request).
  GradeCardDetails? getCachedDetails(ExamHistoryData data, SemesterResult semester) {
    return data.gradeCards[semester.semId];
  }

  // ─── Parser ───────────────────────────────────────────────────────────────

  ExamHistoryData _parseHistory(String html, String usn) {
    final doc = html_parser.parse(html);
    final semesters = <SemesterResult>[];
    final gradeCards = <String, GradeCardDetails>{};

    // ── Cumulative stats from the credits-sec1 card ──────────────────────
    String overallCgpa = '';
    String creditsEarnedSoFar = '';
    String creditsToBeEarned = '';
    final creditsSec = doc.querySelector('.credits-sec1');
    if (creditsSec != null) {
      final paras = creditsSec.querySelectorAll('p');
      // The page has: CGPA value | Credits Earned So Far | Credits to be Earned
      // We pull the first number-like <p> for CGPA, etc.
      // The labels are in sibling spans/text; we grab them by position/text.
      for (final p in paras) {
        final t = p.text.trim();
        if (t.isNotEmpty && RegExp(r'^\d+\.?\d*$').hasMatch(t)) {
          if (overallCgpa.isEmpty) {
            overallCgpa = t;
          } else if (creditsEarnedSoFar.isEmpty) {
            creditsEarnedSoFar = t;
          } else if (creditsToBeEarned.isEmpty) {
            creditsToBeEarned = t;
          }
        }
      }
    }

    // ── Result cards ────────────────────────────────────────────────────
    final resultCards = doc.querySelectorAll('.result-data');
    debugPrint('EXAM HISTORY PARSE: found ${resultCards.length} .result-data card(s)');

    for (final card in resultCards) {
      // Each card contains a <table class="res-table"> inside .uk-overflow-auto
      final table = card.querySelector('table.res-table');
      if (table == null) continue;

      final caption = table.querySelector('caption');
      if (caption == null) continue;

      // ── Extract exam label (text before first <span>) ──────────────
      String label = '';
      for (final node in caption.nodes) {
        if (node.nodeType == dom.Node.TEXT_NODE) {
          final t = node.text?.trim() ?? '';
          if (t.isNotEmpty) {
            label = t;
            break;
          }
        }
      }

      // ── Extract examId from the Print link ──────────────────────────
      final link = caption.querySelector('a[href*="historyEngine"]');
      final href = link?.attributes['href'] ?? '';
      final examId = _extractParam(href, 'examId');

      if (examId.isEmpty) continue;

      // ── Extract SGPA / CGPA / credit counts from caption spans ──────
      String sgpa = '';
      String cgpa = '';
      String credReg = '';
      String credEarned = '';

      for (final span in caption.querySelectorAll('span.uk-label')) {
        final cls = span.attributes['class'] ?? '';
        final text = span.text.trim();
        if (cls.contains('cn-bgcolor1')) {
          // SGPA: " SGPA: 7.57"
          sgpa = _extractTrailingNumber(text);
        } else if (cls.contains('cn-bgcolor4')) {
          // CGPA: " CGPA: 7.45" or " CGPA: CGPA: 7.42"
          cgpa = _extractTrailingNumber(text);
        } else if (cls.contains('cn-color-green')) {
          // Credits Registered: 21
          credReg = _extractTrailingNumber(text);
        } else if (cls.contains('cn-bgcolor3')) {
          // Credits Earned: 21
          credEarned = _extractTrailingNumber(text);
        }
      }

      // ── Parse subject rows ──────────────────────────────────────────
      final subjects = <SubjectRow>[];
      final rows = table.querySelectorAll('tbody tr');

      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 4) continue;

        // Column order: COURSE CODE | SUBJECT NAME | Credits Reg. | Credits Earned | GPA | Grade
        final code         = cells.isNotEmpty ? cells[0].text.trim() : '';
        final name         = cells.length > 1 ? cells[1].text.trim() : '';
        final creditsReg   = cells.length > 2 ? cells[2].text.trim() : '';
        final creditsEarned = cells.length > 3 ? cells[3].text.trim() : '';
        final gpa          = cells.length > 4 ? cells[4].text.trim() : '';
        final grade        = cells.length > 5 ? cells[5].text.trim() : '';

        if (code.isEmpty && name.isEmpty) continue;

        subjects.add(SubjectRow(
          code: code,
          name: name,
          creditsReg: creditsReg,
          creditsEarned: creditsEarned,
          gpa: gpa,
          grade: grade,
        ));
      }

      debugPrint('EXAM HISTORY PARSE: label="$label" examId="$examId" '
          'subjects=${subjects.length} SGPA=$sgpa');

      final sem = SemesterResult(label: label.isEmpty ? 'Semester ${semesters.length + 1}' : label, semId: examId);
      semesters.add(sem);

      gradeCards[examId] = GradeCardDetails(
        semLabel: sem.label,
        examName: label,
        subjects: subjects,
        sgpa: sgpa,
        cgpa: cgpa.isNotEmpty ? cgpa : overallCgpa,
        creditsRegistered: credReg,
        creditsEarned: credEarned,
        creditsEarnedSoFar: creditsEarnedSoFar,
        creditsToBeEarned: creditsToBeEarned,
      );
    }

    // ── Lateral entry: re-label semesters starting from Sem 3 ───────────
    final lateral = _isLateral(usn);
    if (lateral) {
      for (var i = 0; i < semesters.length; i++) {
        final s = semesters[i];
        final semNum = i + 3;
        final enrichedLabel =
            s.label.isEmpty || s.label.startsWith('Semester')
                ? 'Semester $semNum'
                : '${s.label} (Sem $semNum)';
        final updated = SemesterResult(label: enrichedLabel, semId: s.semId);
        semesters[i] = updated;
        // Update gradeCard label too
        final gc = gradeCards[s.semId];
        if (gc != null) {
          gradeCards[s.semId] = gc.copyWith(semLabel: enrichedLabel);
        }
      }
    }

    debugPrint('EXAM HISTORY PARSE: total semesters = ${semesters.length}');
    return ExamHistoryData(
      usn: usn,
      semesters: semesters,
      gradeCards: gradeCards,
      isLateral: lateral,
      overallCgpa: overallCgpa,
      creditsEarnedSoFar: creditsEarnedSoFar,
      creditsToBeEarned: creditsToBeEarned,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  bool _isLateral(String usn) {
    if (usn.length < 3) return false;
    return usn.substring(usn.length - 3).startsWith('4');
  }

  String _extractParam(String url, String param) {
    final regex = RegExp('$param=([^&\'"\\s]+)');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? '';
  }

  /// Extracts the trailing number from a string like "SGPA: 7.57" or "Credits Registered: 21".
  String _extractTrailingNumber(String text) {
    final match = RegExp(r'([\d.]+)\s*$').firstMatch(text.trim());
    return match?.group(1) ?? '';
  }
}

// ─── Data models ──────────────────────────────────────────────────────────────

class ExamHistoryData {
  final String usn;
  final List<SemesterResult> semesters;
  final Map<String, GradeCardDetails> gradeCards;
  final bool isLateral;
  final String overallCgpa;
  final String creditsEarnedSoFar;
  final String creditsToBeEarned;

  ExamHistoryData({
    required this.usn,
    required this.semesters,
    required this.gradeCards,
    this.isLateral = false,
    this.overallCgpa = '',
    this.creditsEarnedSoFar = '',
    this.creditsToBeEarned = '',
  });
}

class SemesterResult {
  final String label;
  final String semId;

  SemesterResult({required this.label, required this.semId});
}

class GradeCardDetails {
  final String semLabel;
  final String examName;
  final List<SubjectRow> subjects;
  final String sgpa;
  final String cgpa;
  final String creditsRegistered;
  final String creditsEarned;
  final String creditsEarnedSoFar;
  final String creditsToBeEarned;

  GradeCardDetails({
    required this.semLabel,
    required this.examName,
    required this.subjects,
    required this.sgpa,
    required this.cgpa,
    this.creditsRegistered = '',
    this.creditsEarned = '',
    this.creditsEarnedSoFar = '',
    this.creditsToBeEarned = '',
  });

  GradeCardDetails copyWith({
    String? semLabel,
    String? examName,
    List<SubjectRow>? subjects,
    String? sgpa,
    String? cgpa,
    String? creditsRegistered,
    String? creditsEarned,
    String? creditsEarnedSoFar,
    String? creditsToBeEarned,
  }) {
    return GradeCardDetails(
      semLabel: semLabel ?? this.semLabel,
      examName: examName ?? this.examName,
      subjects: subjects ?? this.subjects,
      sgpa: sgpa ?? this.sgpa,
      cgpa: cgpa ?? this.cgpa,
      creditsRegistered: creditsRegistered ?? this.creditsRegistered,
      creditsEarned: creditsEarned ?? this.creditsEarned,
      creditsEarnedSoFar: creditsEarnedSoFar ?? this.creditsEarnedSoFar,
      creditsToBeEarned: creditsToBeEarned ?? this.creditsToBeEarned,
    );
  }
}

class SubjectRow {
  final String code;
  final String name;
  final String creditsReg;
  final String creditsEarned;
  final String gpa;
  final String grade;

  SubjectRow({
    required this.code,
    required this.name,
    required this.creditsReg,
    required this.creditsEarned,
    required this.gpa,
    required this.grade,
  });

  /// Passed = credits earned >= credits registered (both non-zero),
  /// or grade is non-empty and not 'F' / 'AB' / 'W'.
  bool get isPassed {
    final reg = double.tryParse(creditsReg) ?? 0;
    final earned = double.tryParse(creditsEarned) ?? 0;
    if (reg > 0 && earned > 0) return earned >= reg;
    if (grade.isNotEmpty) {
      final g = grade.toUpperCase();
      return g != 'F' && g != 'AB' && g != 'W' && g != '-';
    }
    return true;
  }
}
