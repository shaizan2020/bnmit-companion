import 'dart:io';
import 'dart:typed_data';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:bnmit_companion/models/exam_result.dart';
import 'package:bnmit_companion/services/auth_service.dart';

class ExamHistoryService {
  final AuthService _authService;

  ExamHistoryService(this._authService);

  /// Correct endpoint: option=com_history&task=getResult&usn=<USN>
  Future<ExamHistoryData> fetchHistory(String usn) async {
    final html = await _authService.fetchPage(
      'index.php?option=com_history&task=getResult&usn=$usn',
    );
    return _parseHistory(html, usn);
  }

  /// Download the marks card file from the portal.
  /// Returns raw bytes of the file (PDF or image).
  Future<Uint8List> downloadMarksCard(String semId, String usn) async {
    // Try direct PDF download link format used by Contineo
    final possibleUrls = [
      'index.php?option=com_history&task=downloadResult&semId=$semId&usn=$usn',
      'index.php?option=com_history&task=markscard&semId=$semId&usn=$usn',
      'index.php?option=com_history&task=download&semId=$semId&usn=$usn',
      'index.php?option=com_history&task=printResult&semId=$semId&usn=$usn',
    ];

    for (final url in possibleUrls) {
      try {
        final bytes = await _authService.fetchBytes(url);
        if (bytes.isNotEmpty && bytes.length > 500) {
          return bytes;
        }
      } catch (_) {
        continue;
      }
    }
    throw Exception('Could not download marks card. The portal may not support direct download.');
  }

  ExamHistoryData _parseHistory(String html, String usn) {
    final doc = html_parser.parse(html);
    final semesters = <SemesterResult>[];
    String? downloadBaseUrl;

    // Look for semester sections / cards
    // The portal typically shows a list of semester results
    // Each may have a "Download" or "View" button

    // Strategy 1: Look for table rows with semester data
    final tables = doc.querySelectorAll('table');
    for (final table in tables) {
      final rows = table.querySelectorAll('tr');
      for (final row in rows) {
        final cells = row.querySelectorAll('td, th');
        if (cells.length >= 2) {
          final rowText = row.text.trim().toLowerCase();
          // Skip header rows
          if (rowText.contains('semester') && cells.length <= 3) continue;

          // Check if this row contains semester info
          final semMatch = RegExp(r'sem[a-z\s]*(\d+)', caseSensitive: false)
              .firstMatch(row.text);
          if (semMatch != null || row.text.contains('20') || _hasDownloadLink(row)) {
            final downloadLink = _findDownloadLink(row);
            final semId = downloadLink != null 
                ? _extractParam(downloadLink, 'semId') 
                : semMatch?.group(1) ?? '';
            
            if (downloadLink != null || semId.isNotEmpty) {
              final label = _extractSemLabel(cells);
              if (label.isNotEmpty) {
                semesters.add(SemesterResult(
                  label: label,
                  semId: semId,
                  downloadUrl: downloadLink,
                ));
              }
            }
          }
        }
      }
    }

    // Strategy 2: Look for list items or cards with download buttons
    if (semesters.isEmpty) {
      final downloadLinks = doc.querySelectorAll(
          'a[href*="download"], a[href*="Download"], a[href*="markscard"], '
          'a[href*="result"], button[onclick*="download"]');
      
      for (final link in downloadLinks) {
        final href = link.attributes['href'] ?? 
                     link.attributes['onclick'] ?? '';
        final semId = _extractParam(href, 'semId');
        final label = link.text.trim().isEmpty
            ? (_closestText(link, 'tr') ?? _closestText(link, 'div') ?? '')
            : link.text.trim();
        
        if (href.isNotEmpty) {
          semesters.add(SemesterResult(
            label: _cleanLabel(label),
            semId: semId,
            downloadUrl: href,
          ));
        }
      }
    }

    // Strategy 3: Look for any "Exam History" section divs
    if (semesters.isEmpty) {
      final cards = doc.querySelectorAll(
          '.cn-result, .result-card, .md-card, [class*="result"], [class*="history"]');
      for (final card in cards) {
        final link = _findDownloadLink(card);
        final semId = link != null ? _extractParam(link, 'semId') : '';
        final label = card.querySelector('h3, h4, .title, strong')?.text.trim() 
            ?? card.text.trim().split('\n').first;
        if (label.isNotEmpty) {
          semesters.add(SemesterResult(
            label: _cleanLabel(label),
            semId: semId,
            downloadUrl: link,
          ));
        }
      }
    }

    // Strategy 4: Look for any anchor with semId param
    if (semesters.isEmpty) {
      final allLinks = doc.querySelectorAll('a[href*="semId"]');
      for (final link in allLinks) {
        final href = link.attributes['href'] ?? '';
        final semId = _extractParam(href, 'semId');
        final label = link.text.trim();
        if (semId.isNotEmpty && label.isNotEmpty) {
          semesters.add(SemesterResult(
            label: label,
            semId: semId,
            downloadUrl: href,
          ));
        }
      }
    }

    return ExamHistoryData(
      usn: usn,
      semesters: semesters,
      rawHtml: html,
    );
  }

  bool _hasDownloadLink(html_dom.Element el) {
    return el.querySelector('a[href*="download"], a[href*="Download"], a[href*="semId"]') != null;
  }

  String? _findDownloadLink(html_dom.Element el) {
    final link = el.querySelector(
        'a[href*="download"], a[href*="Download"], '
        'a[href*="markscard"], a[href*="semId"], a[href*="result"]');
    return link?.attributes['href'];
  }

  /// Walk up the DOM tree to find an ancestor matching [tag] and return its text
  String? _closestText(html_dom.Element el, String tag) {
    html_dom.Node? node = el.parent;
    while (node != null) {
      if (node is html_dom.Element && node.localName == tag) {
        return node.text.trim();
      }
      node = node.parent;
    }
    return null;
  }

  String _extractSemLabel(List<html_dom.Element> cells) {
    for (final cell in cells) {
      final text = cell.text.trim();
      if (text.isNotEmpty && !text.toLowerCase().contains('action') && 
          !text.toLowerCase().contains('download')) {
        return text;
      }
    }
    return '';
  }

  String _cleanLabel(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _extractParam(String url, String param) {
    final regex = RegExp('$param=([^&\'"\\s]+)');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? '';
  }
}

class ExamHistoryData {
  final String usn;
  final List<SemesterResult> semesters;
  final String rawHtml;

  ExamHistoryData({
    required this.usn,
    required this.semesters,
    required this.rawHtml,
  });
}

class SemesterResult {
  final String label;
  final String semId;
  final String? downloadUrl;

  SemesterResult({
    required this.label,
    required this.semId,
    this.downloadUrl,
  });
}
