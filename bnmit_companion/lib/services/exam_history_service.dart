import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:bnmit_companion/models/exam_result.dart';
import 'package:bnmit_companion/services/auth_service.dart';
import 'package:bnmit_companion/core/constants.dart';

class ExamHistoryService {
  final AuthService _authService;

  ExamHistoryService(this._authService);

  /// Fetch list of available exam history semesters/sessions
  Future<List<Map<String, String>>> fetchExamSessions() async {
    final html = await _authService.fetchPage(
      'index.php?${AppConstants.examHistoryParams}',
    );
    return _parseExamSessions(html);
  }

  /// Fetch exam result for a specific semester
  Future<ExamResult> fetchExamResult(String semId) async {
    final html = await _authService.fetchPage(
      'index.php?${AppConstants.examHistoryParams}&semId=$semId',
    );
    return _parseExamResult(html, semId);
  }

  List<Map<String, String>> _parseExamSessions(String html) {
    final doc = html_parser.parse(html);
    final sessions = <Map<String, String>>[];

    // Look for semester selection dropdown or links
    final selectEl = doc.querySelector('select[name="semId"]') ??
        doc.querySelector('select');
    if (selectEl != null) {
      final options = selectEl.querySelectorAll('option');
      for (final opt in options) {
        final value = opt.attributes['value'] ?? '';
        final label = opt.text.trim();
        if (value.isNotEmpty && label.isNotEmpty) {
          sessions.add({'semId': value, 'label': label});
        }
      }
    }

    // Alternatively look for tab or list items
    if (sessions.isEmpty) {
      final tabs = doc.querySelectorAll('ul[uk-tab] li a, .uk-tab li a');
      for (final tab in tabs) {
        final href = tab.attributes['href'] ?? '';
        final onclick = tab.attributes['onclick'] ?? '';
        final label = tab.text.trim();
        final semId = _extractParam(href.isNotEmpty ? href : onclick, 'semId');
        if (semId.isNotEmpty) {
          sessions.add({'semId': semId, 'label': label});
        }
      }
    }

    // Look for table rows that might be semester links
    if (sessions.isEmpty) {
      final links = doc.querySelectorAll('a[href*="semId"]');
      for (final link in links) {
        final href = link.attributes['href'] ?? '';
        final semId = _extractParam(href, 'semId');
        final label = link.text.trim();
        if (semId.isNotEmpty && label.isNotEmpty) {
          sessions.add({'semId': semId, 'label': label});
        }
      }
    }

    return sessions;
  }

  ExamResult _parseExamResult(String html, String semId) {
    final doc = html_parser.parse(html);
    final subjects = <SubjectResult>[];

    String semester = 'Semester $semId';
    String examType = 'Examination';

    // Try to parse a heading for semester/exam name
    final heading = doc.querySelector('h1, h2, h3, .cn-head, .page-title');
    if (heading != null) {
      final text = heading.text.trim();
      if (text.isNotEmpty) {
        semester = text;
      }
    }

    // Parse results table — Contineo uses various table structures
    final tables = doc.querySelectorAll('table');
    html_dom.Element? resultsTable;

    for (final table in tables) {
      final headers = table.querySelectorAll('th');
      final headerTexts = headers.map((h) => h.text.trim().toLowerCase()).toList();
      // Identify the marks table by looking for subject/marks related headers
      if (headerTexts.any((h) =>
          h.contains('subject') ||
          h.contains('code') ||
          h.contains('marks') ||
          h.contains('grade') ||
          h.contains('credit'))) {
        resultsTable = table;
        break;
      }
    }

    if (resultsTable != null) {
      final headerCells = resultsTable.querySelectorAll('thead th');
      final headers = headerCells.map((h) => h.text.trim().toLowerCase()).toList();

      // Find column indices
      int codeIdx = _findColumnIndex(headers, ['code', 'sub code', 'course code']);
      int nameIdx = _findColumnIndex(headers, ['subject', 'name', 'course name', 'title']);
      int marksIdx = _findColumnIndex(headers, ['marks', 'obtained', 'total']);
      int maxIdx = _findColumnIndex(headers, ['max', 'maximum', 'out of']);
      int gradeIdx = _findColumnIndex(headers, ['grade']);
      int creditIdx = _findColumnIndex(headers, ['credit', 'cr']);
      int sgpaIdx = _findColumnIndex(headers, ['sgpa', 'gpa', 'grade point']);
      int resultIdx = _findColumnIndex(headers, ['result', 'status', 'pass', 'fail']);

      final rows = resultsTable.querySelectorAll('tbody tr');
      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.isEmpty) continue;

        String getCell(int idx) =>
            idx >= 0 && idx < cells.length ? cells[idx].text.trim() : '';

        final code = getCell(codeIdx);
        final name = getCell(nameIdx);
        if (code.isEmpty && name.isEmpty) continue;

        final marksText = getCell(marksIdx);
        final maxText = getCell(maxIdx);
        final gradeText = getCell(gradeIdx);
        final creditText = getCell(creditIdx);
        final sgpaText = getCell(sgpaIdx);
        final resultText = getCell(resultIdx).toLowerCase();

        final marks = double.tryParse(marksText);
        final maxMarks = double.tryParse(maxText);
        final credits = int.tryParse(creditText);
        final sgpa = double.tryParse(sgpaText);

        // Determine pass/fail
        bool isPassed = true;
        if (resultText.isNotEmpty) {
          isPassed = resultText.contains('pass') ||
              resultText.contains('p') ||
              resultText == 'p';
          if (resultText.contains('fail') || resultText.contains('f') || resultText == 'f') {
            isPassed = false;
          }
        } else if (gradeText.isNotEmpty) {
          isPassed = gradeText != 'F' && gradeText != 'AB' && gradeText != 'X';
        } else if (marks != null && maxMarks != null && maxMarks > 0) {
          isPassed = (marks / maxMarks) >= 0.35; // 35% is typical pass criterion
        }

        subjects.add(SubjectResult(
          subjectCode: code.isNotEmpty ? code : 'N/A',
          subjectName: name.isNotEmpty ? name : 'Subject',
          grade: gradeText.isNotEmpty ? gradeText : null,
          marks: marks,
          maxMarks: maxMarks,
          credits: credits,
          sgpa: sgpa,
          isPassed: isPassed,
        ));
      }
    }

    // If no structured table found, try looking for any result data
    if (subjects.isEmpty) {
      // Try to look for individual result cards or divs
      final cards = doc.querySelectorAll('.cn-result-card, .result-item, .md-card');
      for (final card in cards) {
        final codeEl = card.querySelector('.subject-code, [class*="code"]');
        final nameEl = card.querySelector('.subject-name, [class*="name"]');
        if (codeEl != null || nameEl != null) {
          subjects.add(SubjectResult(
            subjectCode: codeEl?.text.trim() ?? 'N/A',
            subjectName: nameEl?.text.trim() ?? 'Subject',
            isPassed: true,
          ));
        }
      }
    }

    return ExamResult(
      semester: semester,
      examType: examType,
      subjects: subjects,
    );
  }

  int _findColumnIndex(List<String> headers, List<String> keywords) {
    for (int i = 0; i < headers.length; i++) {
      for (final kw in keywords) {
        if (headers[i].contains(kw)) return i;
      }
    }
    return -1;
  }

  String _extractParam(String url, String param) {
    final regex = RegExp('$param=([^&\'"]+)');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? '';
  }
}
