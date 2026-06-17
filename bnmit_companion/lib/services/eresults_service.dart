import 'dart:math';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

const _baseUrl = 'https://bnmit-eresults.contineo.in/';

class EResultSubject {
  final String code;
  final String name;
  final String internalMarks;
  final String externalMarks;
  final String totalMarks;
  final String maxMarks;
  final String result;
  final String grade;

  const EResultSubject({
    required this.code,
    required this.name,
    required this.internalMarks,
    required this.externalMarks,
    required this.totalMarks,
    required this.maxMarks,
    required this.result,
    required this.grade,
  });

  bool get isPassed => result.trim().toUpperCase() == 'P';
}

class EResultData {
  final String usn;
  final String studentName;
  final String examName;
  final String semester;
  final String sgpa;
  final String cgpa;
  final List<EResultSubject> subjects;

  const EResultData({
    required this.usn,
    required this.studentName,
    required this.examName,
    required this.semester,
    required this.sgpa,
    required this.cgpa,
    required this.subjects,
  });

  int get passCount => subjects.where((s) => s.isPassed).length;
  int get failCount => subjects.where((s) => !s.isPassed).length;
}

class EResultsService {
  late final Dio _dio;
  late final CookieJar _cookieJar;

  EResultsService() {
    _cookieJar = CookieJar();
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 500,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': _baseUrl,
      },
    ));
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  /// Fetches a fresh session + captcha image bytes + hidden key.
  /// Call this before showing the screen, and again when the user refreshes captcha.
  Future<({Uint8List captchaBytes, String hiddenKey, String captchaRand})>
      loadCaptcha() async {
    // 1. Hit the landing page to establish session and get the hidden `key`
    final landingResp = await _dio.get('');
    final landingHtml = landingResp.data as String? ?? '';
    final hiddenKey = _extractHiddenKey(landingHtml);
    debugPrint('ERESULTS: hiddenKey=$hiddenKey');

    // 2. Fetch captcha image (same session cookie)
    final rand = (Random().nextDouble() * 1000).toStringAsFixed(4);
    final captchaUrl =
        'templates/exam1.0/captcha/get_captcha.php?rand=$rand';
    final captchaResp = await _dio.get(
      captchaUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final captchaBytes =
        Uint8List.fromList(captchaResp.data as List<int>);
    debugPrint('ERESULTS: captcha bytes=${captchaBytes.length}');

    return (
      captchaBytes: captchaBytes,
      hiddenKey: hiddenKey,
      captchaRand: rand,
    );
  }

  /// Reload just the captcha image without touching the session.
  Future<({Uint8List captchaBytes, String captchaRand})>
      reloadCaptcha() async {
    final rand = (Random().nextDouble() * 1000).toStringAsFixed(4);
    final captchaUrl =
        'templates/exam1.0/captcha/get_captcha.php?rand=$rand';
    final captchaResp = await _dio.get(
      captchaUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final captchaBytes =
        Uint8List.fromList(captchaResp.data as List<int>);
    return (captchaBytes: captchaBytes, captchaRand: rand);
  }

  /// Submit the form and return parsed result data.
  Future<EResultData> fetchResult({
    required String usn,
    required String dobDdMmYyyy, // format: DD-MM-YYYY
    required String captchaCode,
    required String hiddenKey,
  }) async {
    final response = await _dio.post(
      'index.php?option=com_examresult&task=getResult',
      data: FormData.fromMap({
        'key': hiddenKey,
        'usn': usn.toUpperCase(),
        'dob': dobDdMmYyyy,
        'securityCode': captchaCode,
      }),
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Referer': _baseUrl,
          'Origin': _baseUrl.replaceAll('/', '').replaceAll('https:', 'https:'),
        },
        responseType: ResponseType.plain,
      ),
    );

    final html = response.data as String? ?? '';
    debugPrint('ERESULTS: result HTML=${html.length} bytes');

    if (html.contains('Invalid security code') ||
        html.contains('invalid security') ||
        html.contains('security code')) {
      throw Exception('Invalid captcha. Please try again.');
    }
    if (html.contains('Invalid USN') ||
        html.contains('No records found') ||
        html.contains('not found')) {
      throw Exception('No result found for USN $usn.');
    }
    if (html.contains('Invalid') || html.contains('error') && !html.contains('<table')) {
      throw Exception('Could not fetch result. Please check your details.');
    }

    return _parseResult(html, usn);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _extractHiddenKey(String html) {
    final doc = html_parser.parse(html);
    // look for <input type="hidden" name="key" value="...">
    final input = doc.querySelector('input[name="key"]');
    if (input != null) {
      return input.attributes['value'] ?? '';
    }
    // fallback: simple value extraction between quotes after 'name="key"'
    final nameKeyIdx = html.indexOf('name="key"');
    if (nameKeyIdx >= 0) {
      final valueIdx = html.indexOf('value="', nameKeyIdx - 200 < 0 ? 0 : nameKeyIdx - 200);
      if (valueIdx >= 0) {
        final start = valueIdx + 7;
        final end = html.indexOf('"', start);
        if (end > start) return html.substring(start, end);
      }
    }
    return '';
  }

  EResultData _parseResult(String html, String usn) {
    final doc = html_parser.parse(html);

    // Student name & exam info — typically in headings / result header
    String studentName = '';
    String examName = '';
    String semester = '';

    // Try common result-header selectors
    final nameEl = doc.querySelector('.student-name') ??
        doc.querySelector('.result-name') ??
        doc.querySelector('h2') ??
        doc.querySelector('h3');
    if (nameEl != null) studentName = nameEl.text.trim();

    final examEl = doc.querySelector('.exam-name') ??
        doc.querySelector('.result-exam') ??
        doc.querySelector('h1');
    if (examEl != null) examName = examEl.text.trim();

    // SGPA / CGPA — often in a summary row or separate div
    String sgpa = '';
    String cgpa = '';
    for (final el in doc.querySelectorAll('td, p, span, div')) {
      final t = el.text.trim();
      if (t.toLowerCase().contains('sgpa') && sgpa.isEmpty) {
        // next sibling or next td value
        final next = el.nextElementSibling;
        if (next != null) sgpa = next.text.trim();
      }
      if (t.toLowerCase().contains('cgpa') && cgpa.isEmpty) {
        final next = el.nextElementSibling;
        if (next != null) cgpa = next.text.trim();
      }
    }

    // Try to find a value in the same td after SGPA label
    if (sgpa.isEmpty) {
      for (final row in doc.querySelectorAll('tr')) {
        final cells = row.querySelectorAll('td');
        for (int i = 0; i < cells.length - 1; i++) {
          final label = cells[i].text.toLowerCase();
          if (label.contains('sgpa')) sgpa = cells[i + 1].text.trim();
          if (label.contains('cgpa')) cgpa = cells[i + 1].text.trim();
          if (label.contains('semester')) semester = cells[i + 1].text.trim();
        }
      }
    }

    // Subject table — look for <table> with thead + tbody
    final subjects = <EResultSubject>[];
    final tables = doc.querySelectorAll('table');
    for (final table in tables) {
      final rows = table.querySelectorAll('tbody tr');
      if (rows.isEmpty) continue;

      // Detect header to map columns
      final headers = table
          .querySelectorAll('thead th, thead td')
          .map((e) => e.text.trim().toLowerCase())
          .toList();

      int codeIdx = -1, nameIdx = -1, intIdx = -1, extIdx = -1;
      int totalIdx = -1, maxIdx = -1, resultIdx = -1, gradeIdx = -1;

      for (int i = 0; i < headers.length; i++) {
        final h = headers[i];
        if (h.contains('code') || h.contains('sub code')) codeIdx = i;
        if (h.contains('subject') || h.contains('sub name')) nameIdx = i;
        if (h.contains('internal') || h.contains('cie') || h.contains('ia')) intIdx = i;
        if (h.contains('external') || h.contains('see') || h.contains('ese')) extIdx = i;
        if (h.contains('total') && totalIdx == -1) totalIdx = i;
        if (h.contains('max') && maxIdx == -1) maxIdx = i;
        if (h.contains('result') || h.contains('status')) resultIdx = i;
        if (h.contains('grade')) gradeIdx = i;
      }

      // If no header detected try positional assumption for known BNMIT result table
      // cols: SNo | Code | Subject | IA | EA | Total | Max | Grade | Result
      if (codeIdx == -1 && nameIdx == -1 && rows.isNotEmpty) {
        final firstCells = rows.first.querySelectorAll('td');
        if (firstCells.length >= 7) {
          codeIdx = 1;
          nameIdx = 2;
          intIdx = 3;
          extIdx = 4;
          totalIdx = 5;
          maxIdx = 6;
          gradeIdx = firstCells.length > 7 ? 7 : -1;
          resultIdx = firstCells.length > 8 ? 8 : -1;
        }
      }

      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.isEmpty) continue;
        String get(int idx) =>
            (idx >= 0 && idx < cells.length) ? cells[idx].text.trim() : '';

        final code = get(codeIdx);
        final name = get(nameIdx);
        if (code.isEmpty && name.isEmpty) continue;

        subjects.add(EResultSubject(
          code: code,
          name: name,
          internalMarks: get(intIdx),
          externalMarks: get(extIdx),
          totalMarks: get(totalIdx),
          maxMarks: get(maxIdx),
          grade: get(gradeIdx),
          result: get(resultIdx),
        ));
      }

      if (subjects.isNotEmpty) break; // found the results table
    }

    return EResultData(
      usn: usn.toUpperCase(),
      studentName: studentName,
      examName: examName,
      semester: semester,
      sgpa: sgpa,
      cgpa: cgpa,
      subjects: subjects,
    );
  }
}
