import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:bnmit_companion/providers/exam_history_provider.dart';
import 'package:bnmit_companion/providers/auth_provider.dart';
import 'package:bnmit_companion/services/exam_history_service.dart';

class ExamHistoryScreen extends ConsumerWidget {
  const ExamHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(examHistoryProvider);
    final colorScheme = Theme.of(context).colorScheme;

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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6750A4), Color(0xFF9C27B0)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
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
                          mainAxisSize: MainAxisSize.min,
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
                              'Download previous semester marks cards',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
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
                historyAsync.when(
                  data: (data) {
                    if (data.semesters.isEmpty) {
                      return _buildEmptyState(context, data);
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withAlpha(80),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.primary.withAlpha(40),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: colorScheme.primary, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Tap Download to save a marks card to your device.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 300.ms),
                        const SizedBox(height: 16),
                        Text(
                          '${data.semesters.length} semester${data.semesters.length == 1 ? '' : 's'} found',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurface.withAlpha(153),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...data.semesters.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SemesterCard(
                              semester: entry.value,
                              usn: data.usn,
                              index: entry.key,
                            ).animate(delay: (entry.key * 80).ms)
                              .fadeIn()
                              .slideY(begin: 0.05),
                          );
                        }),
                      ],
                    );
                  },
                  loading: () => _buildLoading(context),
                  error: (e, _) => _buildError(context, e.toString(), ref),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ExamHistoryData data) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.history_edu_outlined,
              size: 64, color: colorScheme.onSurface.withAlpha(60)),
          const SizedBox(height: 20),
          Text(
            'No Exam History Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Previous semester results will appear here once published on the Contineo portal.',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withAlpha(128),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'USN: ${data.usn}',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error, WidgetRef ref) {
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
          Text(error,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(examHistoryProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─── Semester Card Widget ───────────────────────────────────────────────────

class _SemesterCard extends ConsumerStatefulWidget {
  final SemesterResult semester;
  final String usn;
  final int index;

  const _SemesterCard({
    required this.semester,
    required this.usn,
    required this.index,
  });

  @override
  ConsumerState<_SemesterCard> createState() => _SemesterCardState();
}

class _SemesterCardState extends ConsumerState<_SemesterCard> {
  bool _isDownloading = false;
  String? _savedPath;

  static const List<Color> _colors = [
    Color(0xFF6750A4),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFBF360C),
    Color(0xFF00838F),
    Color(0xFF6A1B9A),
    Color(0xFF558B2F),
    Color(0xFF4527A0),
  ];

  Color get _accentColor => _colors[widget.index % _colors.length];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _accentColor;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(40), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withAlpha(15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(Icons.school_rounded, color: color, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.semester.label.isNotEmpty
                            ? widget.semester.label
                            : 'Semester ${widget.index + 1}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (widget.usn.isNotEmpty)
                        Text(
                          widget.usn,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withAlpha(128),
                          ),
                        ),
                    ],
                  ),
                ),
                // Marks Card chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withAlpha(60)),
                  ),
                  child: Text(
                    'Marks Card',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Download button
                Expanded(
                  child: _isDownloading
                      ? Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withAlpha(15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('Downloading...',
                                    style: TextStyle(fontSize: 13, color: color)),
                              ],
                            ),
                          ),
                        )
                      : _savedPath != null
                          ? _buildOpenButton(color)
                          : _buildDownloadButton(color),
                ),
                if (_savedPath != null) ...[
                  const SizedBox(width: 8),
                  // Share button
                  IconButton(
                    onPressed: () => _share(),
                    icon: const Icon(Icons.share_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    tooltip: 'Share',
                  ),
                ],
              ],
            ),
          ),

          if (_savedPath != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Saved: ${_savedPath!.split('/').last}',
                      style: const TextStyle(fontSize: 11, color: Colors.green),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(Color color) {
    return ElevatedButton.icon(
      onPressed: _download,
      icon: const Icon(Icons.download_rounded, size: 18),
      label: const Text('Download Marks Card'),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildOpenButton(Color color) {
    return OutlinedButton.icon(
      onPressed: _openFile,
      icon: const Icon(Icons.open_in_new_rounded, size: 18),
      label: const Text('Open Marks Card'),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _download() async {
    setState(() => _isDownloading = true);
    try {
      final service = ref.read(examHistoryServiceProvider);
      final bytes = await service.downloadMarksCard(
        widget.semester.semId,
        widget.usn,
      );

      // Determine file extension from content
      final ext = _detectExtension(bytes);
      final safeName = (widget.semester.label.isNotEmpty
              ? widget.semester.label
              : 'sem_${widget.index + 1}')
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .toLowerCase();

      // Save to Downloads folder
      final dir = await _getDownloadsDir();
      final file = File('${dir.path}/bnmit_marks_$safeName.$ext');
      await file.writeAsBytes(bytes);

      if (mounted) {
        setState(() => _savedPath = file.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Downloads: bnmit_marks_$safeName.$ext'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: _openFile,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _openFile() async {
    if (_savedPath == null) return;
    final result = await OpenFile.open(_savedPath!);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open file: ${result.message}')),
      );
    }
  }

  Future<void> _share() async {
    if (_savedPath == null) return;
    await Share.shareXFiles(
      [XFile(_savedPath!)],
      subject: 'BNMIT Marks Card - ${widget.semester.label}',
    );
  }

  String _detectExtension(Uint8List bytes) {
    // PDF magic: %PDF
    if (bytes.length > 4 &&
        bytes[0] == 0x25 && bytes[1] == 0x50 &&
        bytes[2] == 0x44 && bytes[3] == 0x46) {
      return 'pdf';
    }
    // PNG magic
    if (bytes.length > 4 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 &&
        bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'png';
    }
    // JPEG magic
    if (bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'jpg';
    }
    return 'pdf'; // Default to PDF
  }

  Future<Directory> _getDownloadsDir() async {
    // Try /storage/emulated/0/Download first
    final downloadDir = Directory('/storage/emulated/0/Download/BNMIT Companion');
    if (await downloadDir.exists() || await downloadDir.create(recursive: true) != null) {
      return downloadDir;
    }
    // Fallback to app documents directory
    return getApplicationDocumentsDirectory();
  }
}
