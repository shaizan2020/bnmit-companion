import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bnmit_companion/providers/attendance_provider.dart';
import 'package:bnmit_companion/providers/marks_provider.dart';
import 'package:bnmit_companion/core/theme.dart';
import 'package:bnmit_companion/models/marks.dart';

class MarksScreen extends ConsumerWidget {
  const MarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(attendanceSummaryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('CIE Marks')),
      body: attendanceAsync.when(
        data: (summary) {
          final subjects = summary.subjects;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMarksCard(context, ref, subject)
                    .animate(delay: (index * 80).ms)
                    .fadeIn()
                    .slideY(begin: 0.03),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load marks'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(attendanceSummaryProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarksCard(BuildContext context, WidgetRef ref, dynamic subject) {
    final colorScheme = Theme.of(context).colorScheme;
    // Use a stable String key (value equality) to prevent FutureProvider.family
    // from treating each rebuild as a new provider instance (Map uses ref equality).
    final key =
        '${subject.courseId}|${subject.secId}|${subject.semId}|${subject.subjectCode}';
    final marksAsync = ref.watch(subjectMarksProvider(key));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withAlpha(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subject.subjectCode,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.secondary,
                  ),
                ),
              ),
              const Spacer(),
              marksAsync.when(
                data: (marks) {
                  if (marks.components.isEmpty) {
                    return Chip(
                      label: const Text('No marks yet',
                          style: TextStyle(fontSize: 11)),
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    );
                  }
                  final color = AppTheme.getMarksColor(marks.percentage);
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${marks.totalObtained.toStringAsFixed(0)}/${marks.totalMax.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => Icon(Icons.error_outline,
                    size: 20, color: colorScheme.error),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subject.subjectName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          marksAsync.when(
            data: (marks) {
              if (marks.components.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  const SizedBox(height: 12),
                  ...marks.components.map((c) => _buildComponentRow(context, c)),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentRow(BuildContext context, CIEComponent component) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = component.isAvailable
        ? AppTheme.getMarksColor(component.percentage)
        : colorScheme.onSurface.withAlpha(102);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              component.name,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withAlpha(178),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: component.isAvailable
                    ? (component.percentage / 100).clamp(0.0, 1.0)
                    : 0,
                minHeight: 6,
                color: color,
                backgroundColor: color.withAlpha(30),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              component.isAvailable
                  ? '${component.obtained!.toStringAsFixed(0)}/${component.maxMarks.toStringAsFixed(0)}'
                  : '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
