import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bnmit_companion/providers/exam_history_provider.dart';
import 'package:bnmit_companion/providers/auth_provider.dart';
import 'package:bnmit_companion/models/exam_result.dart';

class ExamHistoryScreen extends ConsumerStatefulWidget {
  const ExamHistoryScreen({super.key});

  @override
  ConsumerState<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends ConsumerState<ExamHistoryScreen> {
  String? _selectedSemId;
  bool _isGeneratingPdf = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sessionsAsync = ref.watch(examSessionsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF6750A4),
                      const Color(0xFF9C27B0).withAlpha(204),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(38),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.history_edu_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Exam History',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Previous semester results',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Semester picker
                sessionsAsync.when(
                  data: (sessions) {
                    if (sessions.isEmpty) {
                      return _buildEmptyState(context);
                    }
                    // Auto-select first session
                    if (_selectedSemId == null && sessions.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() => _selectedSemId = sessions.first['semId']);
                      });
                    }
                    return _buildSessionPicker(context, sessions);
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => _buildErrorState(
                    context,
                    'Could not load exam sessions.\n$e',
                    () => ref.invalidate(examSessionsProvider),
                  ),
                ),
                const SizedBox(height: 16),

                // Exam result
                if (_selectedSemId != null) ...[
                  Consumer(
                    builder: (context, ref, _) {
                      final resultAsync =
                          ref.watch(examResultProvider(_selectedSemId!));
                      return resultAsync.when(
                        data: (result) => _buildMarksCard(context, result),
                        loading: () => _buildResultLoading(context),
                        error: (e, _) => _buildErrorState(
                          context,
                          'Could not load result.\n$e',
                          () => ref.invalidate(
                              examResultProvider(_selectedSemId!)),
                        ),
                      );
                    },
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPicker(
      BuildContext context, List<Map<String, String>> sessions) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Semester',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final isSelected = _selectedSemId == session['semId'];
              return FilterChip(
                label: Text(
                  session['label'] ?? 'Sem ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.primary,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedSemId = session['semId']);
                },
                backgroundColor: colorScheme.surfaceContainerLow,
                selectedColor: colorScheme.primary,
                checkmarkColor: colorScheme.onPrimary,
              );
            },
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildMarksCard(BuildContext context, ExamResult result) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authStateProvider).valueOrNull?.user;

    return Column(
      children: [
        // Summary Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6750A4).withAlpha(20),
                const Color(0xFF9C27B0).withAlpha(10),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF6750A4).withAlpha(40),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.semester,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6750A4),
                          ),
                        ),
                        if (user != null)
                          Text(
                            '${user.name} • ${user.usn}',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Download button
                  _isGeneratingPdf
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton.filled(
                          onPressed: () =>
                              _downloadMarksCard(context, result, user),
                          icon: const Icon(Icons.download_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF6750A4),
                            foregroundColor: Colors.white,
                          ),
                          tooltip: 'Download Marks Card',
                        ),
                ],
              ),
              if (result.subjects.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatChip(
                      context,
                      label: 'Total',
                      value: '${result.subjects.length}',
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      context,
                      label: 'Pass',
                      value: '${result.passCount}',
                      color: const Color(0xFF4CAF50),
                    ),
                    const SizedBox(width: 8),
                    if (result.failCount > 0)
                      _buildStatChip(
                        context,
                        label: 'Fail',
                        value: '${result.failCount}',
                        color: Colors.red,
                      ),
                    const Spacer(),
                    // Share button
                    TextButton.icon(
                      onPressed: () =>
                          _shareMarksCard(context, result, user),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05),

        const SizedBox(height: 16),

        // Subject Results
        if (result.subjects.isEmpty)
          _buildNoResultsCard(context)
        else
          ...result.subjects.asMap().entries.map((entry) {
            final i = entry.key;
            final subject = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSubjectResultCard(context, subject)
                  .animate(delay: (i * 60).ms)
                  .fadeIn()
                  .slideX(begin: 0.04),
            );
          }),
      ],
    );
  }

  Widget _buildSubjectResultCard(BuildContext context, SubjectResult subject) {
    final colorScheme = Theme.of(context).colorScheme;
    final passColor =
        subject.isPassed ? const Color(0xFF4CAF50) : Colors.red;
    final marksColor = subject.percentage >= 75
        ? const Color(0xFF4CAF50)
        : subject.percentage >= 50
            ? const Color(0xFFFF9800)
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: passColor.withAlpha(40),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Pass/Fail indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: passColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // Subject code chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subject.subjectCode,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.secondary,
                  ),
                ),
              ),
              const Spacer(),
              // Grade badge
              if (subject.grade != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: passColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: passColor.withAlpha(60)),
                  ),
                  child: Text(
                    'Grade: ${subject.grade}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: passColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subject.subjectName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          if (subject.marks != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (subject.percentage / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      color: marksColor,
                      backgroundColor: marksColor.withAlpha(30),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  subject.maxMarks != null
                      ? '${subject.marks!.toStringAsFixed(0)}/${subject.maxMarks!.toStringAsFixed(0)}'
                      : '${subject.marks!.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: marksColor,
                  ),
                ),
              ],
            ),
          ],
          if (subject.credits != null || subject.sgpa != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (subject.credits != null)
                  _buildInfoChip(
                      context, 'Credits: ${subject.credits}', colorScheme),
                if (subject.credits != null && subject.sgpa != null)
                  const SizedBox(width: 8),
                if (subject.sgpa != null)
                  _buildInfoChip(
                      context, 'GP: ${subject.sgpa!.toStringAsFixed(2)}',
                      colorScheme),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: passColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subject.isPassed ? 'PASS' : 'FAIL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: passColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(
      BuildContext context, {
        required String label,
        required String value,
        required Color color,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withAlpha(180)),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
      BuildContext context, String text, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: colorScheme.onSurface.withAlpha(178),
        ),
      ),
    );
  }

  Widget _buildNoResultsCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.school_outlined,
            size: 48,
            color: colorScheme.onSurface.withAlpha(80),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found for this semester',
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.onSurface.withAlpha(153),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Results may not be published yet or this semester has no recorded data.',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withAlpha(102),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultLoading(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.history_edu_outlined, size: 56,
              color: colorScheme.onSurface.withAlpha(80)),
          const SizedBox(height: 16),
          Text(
            'No exam history available',
            style: TextStyle(
                fontSize: 16, color: colorScheme.onSurface.withAlpha(153)),
          ),
          const SizedBox(height: 8),
          Text(
            'Exam results will appear here once they are published on the portal.',
            style: TextStyle(
                fontSize: 13, color: colorScheme.onSurface.withAlpha(102)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, String message, VoidCallback onRetry) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withAlpha(40)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error, size: 36),
          const SizedBox(height: 12),
          Text(
            message,
            style:
                TextStyle(fontSize: 13, color: colorScheme.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ─── PDF Generation ─────────────────────────────────────────────────────────

  Future<void> _downloadMarksCard(BuildContext context, ExamResult result, dynamic user) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final pdfBytes = await _generatePdf(result, user);
      final dir = await getTemporaryDirectory();
      final safeName = result.semester.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
      final file = File('${dir.path}/marks_card_$safeName.pdf');
      await file.writeAsBytes(pdfBytes);

      if (!context.mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Marks Card - ${result.semester}',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not generate PDF: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _shareMarksCard(BuildContext context, ExamResult result, dynamic user) async {
    setState(() => _isGeneratingPdf = true);
    try {
      final pdfBytes = await _generatePdf(result, user);
      final dir = await getTemporaryDirectory();
      final safeName = result.semester.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
      final file = File('${dir.path}/marks_card_$safeName.pdf');
      await file.writeAsBytes(pdfBytes);

      if (!context.mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'BNMIT Marks Card - ${result.semester}',
        text: 'My marks card from BNMIT Companion app',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share marks card: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<Uint8List> _generatePdf(ExamResult result, dynamic user) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'B.N.M. INSTITUTE OF TECHNOLOGY',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.deepPurple,
                      ),
                    ),
                    pw.Text(
                      'BNMIT Companion — Marks Card',
                      style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.deepPurple50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.deepPurple200),
                  ),
                  child: pw.Text(
                    result.semester,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.deepPurple800,
                    ),
                  ),
                ),
              ],
            ),
            pw.Divider(color: PdfColors.deepPurple100, thickness: 1.5),
            if (user != null)
              pw.Row(
                children: [
                  pw.Text('Name: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text(user.name ?? '', style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(width: 24),
                  pw.Text('USN: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text(user.usn ?? '', style: const pw.TextStyle(fontSize: 11)),
                  pw.SizedBox(width: 24),
                  pw.Text('Branch: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text('${user.branch ?? ''} Sem ${user.semester ?? ''}',
                      style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated by BNMIT Companion App',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          ],
        ),
        build: (context) => [
          // Summary section
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.deepPurple50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfStat('Total Subjects', '${result.subjects.length}'),
                _pdfStat('Passed', '${result.passCount}', color: PdfColors.green700),
                _pdfStat('Failed', '${result.failCount}', color: PdfColors.red700),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Table of results
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(0.8),
              5: const pw.FlexColumnWidth(0.8),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.deepPurple),
                children: [
                  _pdfTableHeader('Code'),
                  _pdfTableHeader('Subject Name'),
                  _pdfTableHeader('Marks'),
                  _pdfTableHeader('Grade'),
                  _pdfTableHeader('Credits'),
                  _pdfTableHeader('Result'),
                ],
              ),
              // Data rows
              ...result.subjects.map((subject) {
                final isPass = subject.isPassed;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isPass ? PdfColors.white : PdfColors.red50,
                  ),
                  children: [
                    _pdfTableCell(subject.subjectCode),
                    _pdfTableCell(subject.subjectName),
                    _pdfTableCell(
                      subject.marks != null
                          ? (subject.maxMarks != null
                              ? '${subject.marks!.toStringAsFixed(0)}/${subject.maxMarks!.toStringAsFixed(0)}'
                              : '${subject.marks!.toStringAsFixed(0)}')
                          : '—',
                    ),
                    _pdfTableCell(subject.grade ?? '—'),
                    _pdfTableCell(subject.credits?.toString() ?? '—'),
                    _pdfTableCell(
                      isPass ? 'PASS' : 'FAIL',
                      color: isPass ? PdfColors.green700 : PdfColors.red700,
                      bold: true,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _pdfStat(String label, String value, {PdfColor? color}) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: color ?? PdfColors.deepPurple800,
          ),
        ),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _pdfTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _pdfTableCell(String text, {PdfColor? color, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          color: color ?? PdfColors.grey900,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
