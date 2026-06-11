import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:bnmit_companion/providers/auth_provider.dart';
import 'package:bnmit_companion/providers/attendance_provider.dart';
import 'package:bnmit_companion/core/theme.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final attendanceAsync = ref.watch(attendanceSummaryProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final user = authState.valueOrNull?.user;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(attendanceSummaryProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            // App Bar with greeting
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary,
                        colorScheme.primaryContainer,
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
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.white.withAlpha(51),
                                child: Text(
                                  user?.initials ?? 'S',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hello, ${user?.displayName ?? 'Student'} 👋',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${user?.usn ?? ''} • ${user?.branch ?? ''} • Sem ${user?.semester ?? ''}',
                                      style: TextStyle(
                                        color: Colors.white.withAlpha(200),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
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
                  // Overall Attendance Card
                  attendanceAsync.when(
                    data: (summary) => _buildOverallAttendanceCard(
                      context,
                      summary.overallPercentage,
                      summary.subjects.length,
                      summary.shortageCount,
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05),
                    loading: () => _buildLoadingCard(context),
                    error: (e, _) => _buildErrorCard(context, e.toString(), () {
                      ref.read(attendanceSummaryProvider.notifier).refresh();
                    }),
                  ),
                  const SizedBox(height: 16),

                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ).animate(delay: 200.ms).fadeIn(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildQuickAction(
                        context,
                        icon: Icons.fact_check,
                        label: 'Attendance',
                        color: const Color(0xFF2196F3),
                        onTap: () => context.go('/attendance'),
                      ),
                      const SizedBox(width: 12),
                      _buildQuickAction(
                        context,
                        icon: Icons.assessment,
                        label: 'CIE Marks',
                        color: const Color(0xFFFF9800),
                        onTap: () => context.go('/marks'),
                      ),
                      const SizedBox(width: 12),
                      _buildQuickAction(
                        context,
                        icon: Icons.history_edu_rounded,
                        label: 'Exam History',
                        color: const Color(0xFF9C27B0),
                        onTap: () => context.go('/exam-history'),
                      ),
                    ],
                  ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.05),
                  const SizedBox(height: 20),

                  // Subject-wise Attendance
                  Text(
                    'Subject Attendance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ).animate(delay: 400.ms).fadeIn(),
                  const SizedBox(height: 12),

                  attendanceAsync.when(
                    data: (summary) => Column(
                      children: summary.subjects.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final subject = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildSubjectCard(context, subject)
                              .animate(delay: (500 + idx * 80).ms)
                              .fadeIn()
                              .slideX(begin: 0.05),
                        );
                      }).toList(),
                    ),
                    loading: () => Column(
                      children: List.generate(
                        4,
                        (_) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildLoadingCard(context),
                        ),
                      ),
                    ),
                    error: (e, _) => _buildErrorCard(context, e.toString(), () {
                      ref.read(attendanceSummaryProvider.notifier).refresh();
                    }),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallAttendanceCard(
      BuildContext context, double percentage, int subjects, int shortageCount) {
    final colorScheme = Theme.of(context).colorScheme;
    final attendanceColor = AppTheme.getAttendanceColor(percentage);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerLowest,
            colorScheme.surfaceContainerLow,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withAlpha(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 48,
            lineWidth: 8,
            percent: (percentage / 100).clamp(0.0, 1.0),
            center: Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: attendanceColor,
              ),
            ),
            progressColor: attendanceColor,
            backgroundColor: attendanceColor.withAlpha(30),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 1200,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Attendance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$subjects subjects enrolled',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withAlpha(153),
                  ),
                ),
                if (shortageCount > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.attendanceDanger.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚠️ $shortageCount below 80%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.attendanceDanger,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: color.withAlpha(18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(38)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, dynamic subject) {
    final colorScheme = Theme.of(context).colorScheme;
    final percentage = subject.percentage;
    final color = AppTheme.getAttendanceColor(percentage);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withAlpha(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.subjectName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${subject.subjectCode} • ${subject.attendedClasses}/${subject.totalClasses} classes',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withAlpha(128),
                  ),
                ),
              ],
            ),
          ),
          // Circular mini progress
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              strokeWidth: 3.5,
              color: color,
              backgroundColor: color.withAlpha(30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorCard(
      BuildContext context, String error, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline,
              color: Theme.of(context).colorScheme.error, size: 32),
          const SizedBox(height: 8),
          Text(error,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
