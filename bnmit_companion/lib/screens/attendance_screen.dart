import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:bnmit_companion/providers/attendance_provider.dart';
import 'package:bnmit_companion/core/theme.dart';
import 'package:bnmit_companion/models/attendance.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(attendanceSummaryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(attendanceSummaryProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(attendanceSummaryProvider.notifier).refresh(),
        child: attendanceAsync.when(
          data: (summary) => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: summary.subjects.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    // Summary card
                    _buildSummaryHeader(context, summary)
                        .animate()
                        .fadeIn()
                        .slideY(begin: 0.05),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Subject-wise Attendance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              }
              final subject = summary.subjects[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSubjectDetailCard(context, subject)
                    .animate(delay: (100 + (index - 1) * 60).ms)
                    .fadeIn()
                    .slideX(begin: 0.03),
              );
            },
          ),
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: colorScheme.error),
                const SizedBox(height: 16),
                Text('Failed to load attendance',
                    style: TextStyle(color: colorScheme.error)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref
                      .read(attendanceSummaryProvider.notifier)
                      .refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context, AttendanceSummary summary) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = summary.overallPercentage;
    final color = AppTheme.getAttendanceColor(percentage);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withAlpha(20),
            colorScheme.surfaceContainerLowest,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 52,
            lineWidth: 10,
            percent: (percentage / 100).clamp(0.0, 1.0),
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  'Overall',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurface.withAlpha(128),
                  ),
                ),
              ],
            ),
            progressColor: color,
            backgroundColor: color.withAlpha(30),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statRow(context, 'Subjects', '${summary.subjects.length}'),
                const SizedBox(height: 6),
                _statRow(
                  context,
                  'Above 80%',
                  '${summary.subjects.where((s) => s.percentage >= 80).length}',
                  color: AppTheme.attendanceGood,
                ),
                const SizedBox(height: 6),
                _statRow(
                  context,
                  'Below 80%',
                  '${summary.shortageCount}',
                  color: summary.shortageCount > 0
                      ? AppTheme.attendanceDanger
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(BuildContext context, String label, String value,
      {Color? color}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurface.withAlpha(153),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectDetailCard(
      BuildContext context, SubjectAttendance subject) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = AppTheme.getAttendanceColor(subject.percentage);

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subject.subjectCode,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${subject.percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
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
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (subject.percentage / 100).clamp(0.0, 1.0),
              minHeight: 8,
              color: color,
              backgroundColor: color.withAlpha(30),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat(context, '${subject.attendedClasses}', 'Present',
                  AppTheme.attendanceGood),
              const SizedBox(width: 16),
              _miniStat(context, '${subject.absentClasses}', 'Absent',
                  AppTheme.attendanceDanger),
              const SizedBox(width: 16),
              _miniStat(context, '${subject.totalClasses}', 'Total',
                  colorScheme.primary),
              const Spacer(),
              if (subject.isGood)
                Chip(
                  label: Text(
                    'Can skip ${subject.classesCanSkipFor75}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: AppTheme.attendanceGood.withAlpha(20),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                )
              else if (subject.isShortage)
                Chip(
                  label: Text(
                    'Need ${subject.classesNeededFor75} more',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: AppTheme.attendanceDanger.withAlpha(20),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(
      BuildContext context, String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
          ),
        ),
      ],
    );
  }
}
