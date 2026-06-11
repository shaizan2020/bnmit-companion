import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:bnmit_companion/models/user.dart';
import 'package:bnmit_companion/models/attendance.dart';
import 'package:bnmit_companion/models/marks.dart';
import 'package:bnmit_companion/models/timetable.dart';
import 'package:bnmit_companion/core/constants.dart';

class ScraperService {
  /// Extract CSRF token from HTML (hidden input with 32-char hex name)
  String? extractCsrfToken(String html) {
    final doc = html_parser.parse(html);
    final hiddenInputs = doc.querySelectorAll('input[type="hidden"]');
    for (final input in hiddenInputs) {
      final name = input.attributes['name'] ?? '';
      // CSRF token is a 32-char hex string
      if (RegExp(r'^[a-f0-9]{32}$').hasMatch(name)) {
        return name;
      }
    }
    return null;
  }

  /// Parse user profile from dashboard HTML
  User parseUserProfile(String html, {String? portalUrl}) {
    final doc = html_parser.parse(html);

    // Extract student name: <h3> inside cn-stu-data
    String name = 'Student';
    final nameEl = doc.querySelector('.cn-stu-data h3');
    if (nameEl != null) {
      name = nameEl.text.trim();
    }

    // Extract USN: <h2> inside cn-stu-data1
    String usn = '';
    final usnEl = doc.querySelector('.cn-stu-data1 h2');
    if (usnEl != null) {
      usn = usnEl.text.trim();
    }

    // Extract branch, semester, section from <p> inside cn-stu-data1
    String branch = '';
    String semester = '';
    String section = '';
    final infoEl = doc.querySelector('.cn-stu-data1.uk-text-right p') ??
        doc.querySelector('.cn-mobile-text p');
    if (infoEl != null) {
      final text = infoEl.text.trim();
      // Format: "B.E-CS,  SEM 06,  SEC C"
      final parts = text.split(',').map((s) => s.trim()).toList();
      if (parts.isNotEmpty) branch = parts[0];
      if (parts.length > 1) {
        semester = parts[1].replaceAll(RegExp(r'SEM\s*', caseSensitive: false), '').trim();
      }
      if (parts.length > 2) {
        section = parts[2].replaceAll(RegExp(r'SEC\s*', caseSensitive: false), '').trim();
      }
    }

    // Profile image
    String? profileImageUrl;
    final imgEl = doc.querySelector('.cn-stu-data img');
    if (imgEl != null) {
      final src = imgEl.attributes['src'] ?? '';
      if (src.isNotEmpty) {
        final activePortalUrl = portalUrl ?? AppConstants.portalUrl;
        profileImageUrl = src.startsWith('http') ? src : '$activePortalUrl/$src';
      }
    }

    // Last updated
    String? lastUpdated;
    final updateEl = doc.querySelector('.cn-last-update');
    if (updateEl != null) {
      lastUpdated = updateEl.text.replaceAll('Last Updated On:', '').trim();
    }

    return User(
      usn: usn,
      name: name,
      branch: branch,
      semester: semester,
      section: section,
      profileImageUrl: profileImageUrl,
      lastUpdated: lastUpdated,
    );
  }

  /// Parse attendance summary from dashboard page
  /// The dashboard contains billboard.js chart data with percentages
  AttendanceSummary parseDashboardAttendance(String html) {
    final doc = html_parser.parse(html);
    final subjects = <SubjectAttendance>[];

    // Debug: how many tables on this page?
    final allTables = doc.querySelectorAll('table');
    print('SCRAPER: parseDashboardAttendance — found ${allTables.length} table(s), html length=${html.length}');

    // Extract subject info from the course table (skip empty/stub tables)
    html_dom.Element? courseTable;
    for (final table in allTables) {
      if (table.querySelectorAll('tbody tr').isNotEmpty) {
        courseTable = table;
        break;
      }
    }
    if (courseTable != null) {
      final rows = courseTable.querySelectorAll('tbody tr');
      print('SCRAPER: first table has ${rows.length} tbody rows');
      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length >= 2) {
          final code = cells[0].text.trim();
          final name = cells[1].text.trim();

          // Extract courseId, secId, semId from attendance link
          String courseId = '';
          String secId = '';
          String semId = '';
          final attendLink = row.querySelector('a[href*="attendencelist"]');
          if (attendLink != null) {
            final href = attendLink.attributes['href'] ?? '';
            courseId = _extractParam(href, 'courseId');
            secId = _extractParam(href, 'secId');
            semId = _extractParam(href, 'semId');
          }

          print('SCRAPER: subject row — code=$code, name=$name, courseId=$courseId, link=${attendLink != null}');
          subjects.add(SubjectAttendance(
            subjectCode: code,
            subjectName: name,
            totalClasses: 0,
            attendedClasses: 0,
            absentClasses: 0,
            percentage: 0,
            courseId: courseId,
            secId: secId,
            semId: semId,
          ));
        }
      }
    } else {
      print('SCRAPER: NO table found on dashboard page!');
    }

    // Extract attendance percentages from chart data
    // Pattern: columns: [["23CSE161",86],["23CSE162",88],...]
    final percentageRegex = RegExp(r'\["([^"]+)",(\d+)\]');
    final scriptElements = doc.querySelectorAll('script');
    final bbScripts = scriptElements.where((s) => s.text.contains('bb.generate')).toList();
    print('SCRAPER: found ${bbScripts.length} bb.generate script block(s)');

    // Find the chart with percentages (second bb.generate call usually)
    int chartIndex = 0;
    for (final script in scriptElements) {
      final text = script.text;
      if (text.contains('bb.generate')) {
        chartIndex++;
        if (chartIndex == 2) {
          // This is the percentage chart
          final matches = percentageRegex.allMatches(text);
          final matchList = matches.toList();
          print('SCRAPER: percentage chart (chartIndex=2) has ${matchList.length} data point(s)');
          for (final match in matchList) {
            final code = match.group(1)!;
            final percentage = double.tryParse(match.group(2)!) ?? 0;
            final idx = subjects.indexWhere((s) => s.subjectCode == code);
            print('SCRAPER: percentage match — code=$code, pct=$percentage, subjectIdx=$idx');
            if (idx >= 0) {
              final s = subjects[idx];
              subjects[idx] = SubjectAttendance(
                subjectCode: s.subjectCode,
                subjectName: s.subjectName,
                totalClasses: s.totalClasses,
                attendedClasses: s.attendedClasses,
                absentClasses: s.absentClasses,
                percentage: percentage,
                courseId: s.courseId,
                secId: s.secId,
                semId: s.semId,
              );
            }
          }
          break;
        }
      }
    }

    // Also try to get total classes from the first chart
    chartIndex = 0;
    for (final script in scriptElements) {
      final text = script.text;
      if (text.contains('bb.generate')) {
        chartIndex++;
        if (chartIndex == 1) {
          // This is the total classes chart
          final matches = percentageRegex.allMatches(text);
          final matchList = matches.toList();
          print('SCRAPER: total classes chart (chartIndex=1) has ${matchList.length} data point(s)');
          for (final match in matchList) {
            final code = match.group(1)!;
            final total = int.tryParse(match.group(2)!) ?? 0;
            final idx = subjects.indexWhere((s) => s.subjectCode == code);
            if (idx >= 0) {
              final s = subjects[idx];
              final attended = (s.percentage * total / 100).round();
              subjects[idx] = SubjectAttendance(
                subjectCode: s.subjectCode,
                subjectName: s.subjectName,
                totalClasses: total,
                attendedClasses: attended,
                absentClasses: total - attended,
                percentage: s.percentage,
                courseId: s.courseId,
                secId: s.secId,
                semId: s.semId,
              );
            }
          }
          break;
        }
      }
    }

    // Count shortages
    final shortageCount = subjects.where((s) => s.percentage < 80).length;
    print('SCRAPER: parseDashboardAttendance done — ${subjects.length} subjects, $shortageCount shortage(s)');

    return AttendanceSummary(
      subjects: subjects,
      shortageCount: shortageCount,
    );
  }

  /// Parse detailed attendance for a specific subject
  SubjectAttendance parseSubjectAttendance(String html, String subjectCode) {
    final doc = html_parser.parse(html);

    // Parse subject name from active tab
    String subjectName = subjectCode;
    final activeTab = doc.querySelector('.uk-active');
    if (activeTab != null) {
      final tooltip = activeTab.attributes['uk-tooltip'] ?? '';
      final titleMatch = RegExp(r'title:\s*([^;]+)').firstMatch(tooltip);
      if (titleMatch != null) {
        subjectName = titleMatch.group(1)!.trim();
      }
    }

    // Parse faculty names
    final facultyNames = <String>[];
    final facultyCards = doc.querySelectorAll('.md-card-head-text');
    for (final card in facultyCards) {
      final text = card.nodes.first.text?.trim() ?? '';
      if (text.isNotEmpty && !text.contains('CSE') && !text.contains('MEC')) {
        facultyNames.add(text.trim());
      }
    }

    // Parse present count
    int presentCount = 0;
    int absentCount = 0;
    // Try specific cn-attend / cn-absent class spans first
    final presentSpan = doc.querySelector('.cn-attend');
    final absentSpan = doc.querySelector('.cn-absent');
    if (presentSpan != null) {
      final text = presentSpan.text.trim();
      final m = RegExp(r'Present\s*\[?\s*(\d+)\s*\]?').firstMatch(text);
      if (m != null) presentCount = int.parse(m.group(1)!);
    }
    if (absentSpan != null) {
      final text = absentSpan.text.trim();
      final m = RegExp(r'Absent\s*\[?\s*(\d+)\s*\]?').firstMatch(text);
      if (m != null) absentCount = int.parse(m.group(1)!);
    }
    // Fallback: scan all uk-label spans
    if (presentCount == 0 && absentCount == 0) {
      final labels = doc.querySelectorAll('.uk-label');
      for (final label in labels) {
        final text = label.text.trim();
        final presentMatch = RegExp(r'Present\s*\[?\s*(\d+)\s*\]?').firstMatch(text);
        final absentMatch = RegExp(r'Absent\s*\[?\s*(\d+)\s*\]?').firstMatch(text);
        if (presentMatch != null) {
          presentCount = int.parse(presentMatch.group(1)!);
        }
        if (absentMatch != null) {
          absentCount = int.parse(absentMatch.group(1)!);
        }
      }
    }

    final totalClasses = presentCount + absentCount;
    final percentage = totalClasses > 0 ? (presentCount / totalClasses) * 100 : 0.0;

    // Parse present records
    final presentRecords = <AttendanceRecord>[];
    final presentTable = doc.querySelector('.cn-present-table table:first-child tbody') ??
        doc.querySelector('.cn-attend-list tbody');
    if (presentTable != null) {
      final rows = presentTable.querySelectorAll('tr');
      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length >= 4) {
          presentRecords.add(AttendanceRecord(
            slNo: int.tryParse(cells[0].text.trim()) ?? 0,
            date: cells[1].text.trim(),
            time: cells[2].text.trim().replaceAll(RegExp(r'\s+'), ' '),
            status: cells[3].text.trim(),
          ));
        }
      }
    }

    // Parse absent records
    final absentRecords = <AttendanceRecord>[];
    final absentTable = doc.querySelectorAll('.cn-present-table table');
    if (absentTable.length > 1) {
      final absentBody = absentTable[1].querySelector('tbody');
      if (absentBody != null) {
        final rows = absentBody.querySelectorAll('tr');
        for (final row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.length >= 4) {
            absentRecords.add(AttendanceRecord(
              slNo: int.tryParse(cells[0].text.trim()) ?? 0,
              date: cells[1].text.trim(),
              time: cells[2].text.trim().replaceAll(RegExp(r'\s+'), ' '),
              status: cells[3].text.trim(),
            ));
          }
        }
      }
    }

    // Extract IDs from tab links
    String courseId = '';
    String secId = '';
    String semId = '';
    final activeLink = doc.querySelector('.uk-active a');
    if (activeLink != null) {
      final onclick = activeLink.attributes['onclick'] ?? '';
      courseId = _extractParam(onclick, 'courseId');
      secId = _extractParam(onclick, 'secId');
      semId = _extractParam(onclick, 'semId');
    }

    return SubjectAttendance(
      subjectCode: subjectCode,
      subjectName: subjectName,
      totalClasses: totalClasses,
      attendedClasses: presentCount,
      absentClasses: absentCount,
      percentage: percentage,
      courseId: courseId,
      secId: secId,
      semId: semId,
      presentRecords: presentRecords,
      absentRecords: absentRecords,
      facultyNames: facultyNames,
    );
  }

  /// Parse CIE marks from the CIE details page
  /// The portal uses a horizontal table (table.cn-cie-table):
  /// - thead th elements are component names (CIE1, CIE2, Assign1, Final IA, Attendance ...)
  /// - a single tbody row has values like "7.00/30", "12.00/30", "29/50", "86%"
  SubjectMarks parseSubjectMarks(String html, String subjectCode) {
    final doc = html_parser.parse(html);

    // Parse subject name from caption or header
    String subjectName = subjectCode;
    final cieTable = doc.querySelector('table.cn-cie-table');
    if (cieTable != null) {
      final caption = cieTable.querySelector('caption');
      if (caption != null) {
        final captionText = caption.text.trim();
        final nameMatch = RegExp(r'(.+?)\(').firstMatch(captionText);
        if (nameMatch != null) {
          subjectName = nameMatch.group(1)!.trim();
        } else if (captionText.isNotEmpty) {
          subjectName = captionText.trim();
        }
      }
    }
    // Fallback: look for th with colspan
    if (subjectName == subjectCode) {
      final header = doc.querySelector('th[colspan]');
      if (header != null) {
        final text = header.text.trim();
        final nameMatch = RegExp(r'(.+?)\(').firstMatch(text);
        if (nameMatch != null) subjectName = nameMatch.group(1)!.trim();
      }
    }

    // Parse faculty names
    final facultyNames = <String>[];
    final facultyCards = doc.querySelectorAll('.md-card-head-text');
    for (final card in facultyCards) {
      final text = card.nodes.isNotEmpty ? (card.nodes.first.text?.trim() ?? '') : '';
      if (text.isNotEmpty && !text.contains('CSE') && !text.contains('MEC')) {
        facultyNames.add(text.trim());
      }
    }

    // Parse CIE components from the horizontal cn-cie-table
    // The table has spacer <th> and <td> elements between each named pair.
    // Strategy: collect only non-empty th texts, collect only meaningful td texts,
    // then zip them together.
    final components = <CIEComponent>[];
    if (cieTable != null) {
      final allHeaders = cieTable.querySelectorAll('thead th');
      final firstRow = cieTable.querySelector('tbody tr');
      if (firstRow != null) {
        final allCells = firstRow.querySelectorAll('td');

        // Extract meaningful header names (skip blank spacers)
        final namedHeaders = allHeaders
            .map((th) => th.text.trim())
            .where((h) => h.isNotEmpty)
            .toList();

        // Extract meaningful cell values (skip blank/space-only spacers and inline scripts)
        final namedValues = allCells
            .map((td) => td.text.trim())
            .where((v) => v.isNotEmpty && v != ' ' && !v.contains('document.getElementById'))
            .toList();

        print('CIE SCRAPER: namedHeaders=$namedHeaders');
        print('CIE SCRAPER: namedValues=$namedValues');

        for (int i = 0; i < namedHeaders.length && i < namedValues.length; i++) {
          final headerText = namedHeaders[i];
          final marksText = namedValues[i];

          // Skip attendance / eligibility columns
          final lowerHeader = headerText.toLowerCase();
          if (lowerHeader.contains('attend') || lowerHeader.contains('eligib')) {
            continue;
          }

          // Parse "obtained/max" format (e.g. "7.00/30", "29/50")
          final slashMatch = RegExp(r'([\d.]+)\s*/\s*([\d.]+)').firstMatch(marksText);
          if (slashMatch != null) {
            components.add(CIEComponent(
              name: headerText,
              obtained: double.tryParse(slashMatch.group(1)!),
              maxMarks: double.tryParse(slashMatch.group(2)!) ?? 0,
            ));
          } else {
            final value = double.tryParse(marksText.replaceAll('%', ''));
            if (value != null) {
              components.add(CIEComponent(
                name: headerText,
                obtained: value,
                maxMarks: 50,
              ));
            }
          }
        }
      }
    }

    print('CIE SCRAPER: subjectCode=$subjectCode subjectName=$subjectName components=${components.length}');

    // Extract IDs from active tab link
    String courseId = '';
    String secId = '';
    String semId = '';
    final activeTab = doc.querySelector('.uk-active a');
    if (activeTab != null) {
      final onclick = activeTab.attributes['onclick'] ?? '';
      courseId = _extractParam(onclick, 'courseId');
      secId = _extractParam(onclick, 'secId');
      semId = _extractParam(onclick, 'semId');
    }

    return SubjectMarks(
      subjectCode: subjectCode,
      subjectName: subjectName,
      courseId: courseId,
      secId: secId,
      semId: semId,
      components: components,
      facultyNames: facultyNames,
    );
  }

  /// Parse timetable from the timetable page
  WeekTimetable parseTimetable(String html) {
    final doc = html_parser.parse(html);
    final days = <TimetableDay>[];

    // Parse week navigation
    String? prevStart, prevEnd, nextStart, nextEnd;
    final prevLink = doc.querySelector('.cn-previous');
    final nextLink = doc.querySelector('.cn-next');

    if (prevLink != null) {
      final href = prevLink.attributes['href'] ?? '';
      prevStart = _extractParam(href, 'prevstart');
      prevEnd = _extractParam(href, 'prevend');
    }
    if (nextLink != null) {
      final href = nextLink.attributes['href'] ?? '';
      nextStart = _extractParam(href, 'nextstart');
      nextEnd = _extractParam(href, 'nextend');
    }

    // Parse timetable table (varies by portal version)
    final tables = doc.querySelectorAll('table');
    for (final table in tables) {
      final headers = table.querySelectorAll('th');
      if (headers.length > 1 && headers.any((h) => 
          h.text.contains('Mon') || h.text.contains('Tue') || 
          h.text.contains('Period') || h.text.contains('Time'))) {
        // Found timetable table
        final rows = table.querySelectorAll('tbody tr');
        for (final row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.isNotEmpty) {
            // Parse each cell as a period
            // Structure depends on portal layout
          }
        }
      }
    }

    return WeekTimetable(
      days: days,
      prevWeekStart: prevStart,
      prevWeekEnd: prevEnd,
      nextWeekStart: nextStart,
      nextWeekEnd: nextEnd,
    );
  }

  /// Get all subject tabs from attendance/CIE page
  List<Map<String, String>> parseSubjectTabs(String html) {
    final doc = html_parser.parse(html);
    final tabs = <Map<String, String>>[];

    final tabElements = doc.querySelectorAll('ul[uk-tab] li');
    for (final tab in tabElements) {
      final link = tab.querySelector('a');
      if (link != null) {
        final code = link.text.trim();
        final tooltip = tab.attributes['uk-tooltip'] ?? '';
        final nameMatch = RegExp(r'title:\s*([^;]+)').firstMatch(tooltip);
        final name = nameMatch?.group(1)?.trim() ?? code;

        final onclick = link.attributes['onclick'] ?? '';
        final courseId = _extractParam(onclick, 'courseId');
        final secId = _extractParam(onclick, 'secId');
        final semId = _extractParam(onclick, 'semId');

        tabs.add({
          'code': code,
          'name': name,
          'courseId': courseId,
          'secId': secId,
          'semId': semId,
        });
      }
    }

    return tabs;
  }

  String _extractParam(String url, String param) {
    final regex = RegExp('$param=([^&\'"]+)');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? '';
  }
}
