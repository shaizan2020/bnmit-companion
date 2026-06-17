import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bnmit_companion/providers/exam_history_provider.dart';
import 'package:bnmit_companion/services/exam_history_service.dart';

class ExamHistoryScreen extends ConsumerWidget {
  const ExamHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(examHistoryProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
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
                              'Select a semester to view results',
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

          // ── Content ───────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                historyAsync.when(
                  data: (data) => _ExamHistoryBody(data: data),
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

  Widget _buildLoading(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 80,
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

// ─── Body with semester selector + grade card display ─────────────────────────

class _ExamHistoryBody extends ConsumerWidget {
  final ExamHistoryData data;

  const _ExamHistoryBody({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedIndex = ref.watch(selectedSemesterIndexProvider);
    final gradeCard = ref.watch(gradeCardProvider);

    if (data.semesters.isEmpty) return _buildEmpty(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Lateral banner ────────────────────────────────────────────────
        if (data.isLateral)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withAlpha(100),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.secondary.withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(Icons.school_outlined,
                    color: colorScheme.secondary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Lateral entry — semesters from Sem 3',
                  style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),

        // ── Overall summary pill (CGPA + total credits) ───────────────────
        if (data.overallCgpa.isNotEmpty || data.creditsEarnedSoFar.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6750A4), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (data.overallCgpa.isNotEmpty)
                  _overallStat('Overall CGPA', data.overallCgpa),
                if (data.creditsEarnedSoFar.isNotEmpty)
                  _overallStat('Credits Earned', data.creditsEarnedSoFar),
                if (data.creditsToBeEarned.isNotEmpty)
                  _overallStat('Credits Left', data.creditsToBeEarned),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms),

        // ── Semester dropdown ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF6750A4).withAlpha(60),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedIndex,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF6750A4)),
              hint: const Text(
                'Select a semester',
                style: TextStyle(fontSize: 15),
              ),
              items: data.semesters.asMap().entries.map((entry) {
                return DropdownMenuItem<int>(
                  value: entry.key,
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6750A4).withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + (data.isLateral ? 3 : 1)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6750A4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.value.label,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (idx) {
                ref.read(selectedSemesterIndexProvider.notifier).state = idx;
              },
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03),

        const SizedBox(height: 20),

        // ── Grade card or prompt ──────────────────────────────────────────
        if (selectedIndex == null)
          _buildSelectPrompt(context)
        else if (gradeCard == null)
          _buildNoDetails(context)
        else
          _GradeCardView(details: gradeCard)
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.05),
      ],
    );
  }

  Widget _overallStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
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
          Text('No records yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(
            'Contineo hasn\'t published any semester results yet.',
            style: TextStyle(
                fontSize: 13, color: colorScheme.onSurface.withAlpha(128)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectPrompt(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF6750A4).withAlpha(30), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(Icons.touch_app_rounded,
              size: 48, color: const Color(0xFF6750A4).withAlpha(120)),
          const SizedBox(height: 16),
          Text(
            'Select a semester above',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Your subject-wise results will appear instantly',
            style: TextStyle(
                fontSize: 13, color: colorScheme.onSurface.withAlpha(120)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildNoDetails(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline,
              size: 40, color: colorScheme.onSurface.withAlpha(80)),
          const SizedBox(height: 12),
          Text('No details available for this semester.',
              style:
                  TextStyle(fontSize: 14, color: colorScheme.onSurface),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Grade Card Detail View ────────────────────────────────────────────────────

class _GradeCardView extends StatelessWidget {
  final GradeCardDetails details;

  const _GradeCardView({required this.details});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const accent = Color(0xFF6750A4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary card ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6750A4), Color(0xFF9C27B0)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(60),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                details.semLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              if (details.examName.isNotEmpty &&
                  details.examName != details.semLabel) ...[
                const SizedBox(height: 2),
                Text(
                  details.examName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 14),
              // SGPA / CGPA / Credits chips
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  if (details.sgpa.isNotEmpty) _statChip('SGPA', details.sgpa),
                  if (details.cgpa.isNotEmpty) _statChip('CGPA', details.cgpa),
                  if (details.creditsRegistered.isNotEmpty)
                    _statChip('Cr. Reg', details.creditsRegistered),
                  if (details.creditsEarned.isNotEmpty)
                    _statChip('Cr. Earned', details.creditsEarned),
                  if (details.subjects.isNotEmpty)
                    _statChip('Subjects', '${details.subjects.length}'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Pass/fail counts ──────────────────────────────────────────────
        if (details.subjects.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: _countCard(context,
                    icon: Icons.check_circle_rounded,
                    label: 'Passed',
                    count:
                        '${details.subjects.where((s) => s.isPassed).length}',
                    color: Colors.green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _countCard(context,
                    icon: Icons.cancel_rounded,
                    label: 'Failed',
                    count:
                        '${details.subjects.where((s) => !s.isPassed).length}',
                    color: Colors.red),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _countCard(context,
                    icon: Icons.book_rounded,
                    label: 'Total',
                    count: '${details.subjects.length}',
                    color: accent),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Subjects header ───────────────────────────────────────────
          Text(
            'Subject Results',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface),
          ),
          const SizedBox(height: 10),

          // ── Subject cards ─────────────────────────────────────────────
          ...details.subjects.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SubjectCard(subject: entry.value, index: entry.key)
                  .animate(delay: (entry.key * 55).ms)
                  .fadeIn()
                  .slideY(begin: 0.04),
            );
          }),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(Icons.table_chart_outlined,
                    size: 40, color: colorScheme.onSurface.withAlpha(80)),
                const SizedBox(height: 10),
                Text(
                  'No subject data available for this semester.',
                  style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withAlpha(160)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _countCard(BuildContext context, {
    required IconData icon,
    required String label,
    required String count,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(count,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: colorScheme.onSurface.withAlpha(140))),
        ],
      ),
    );
  }
}

// ─── Subject Card ──────────────────────────────────────────────────────────────

class _SubjectCard extends StatelessWidget {
  final SubjectRow subject;
  final int index;

  const _SubjectCard({required this.subject, required this.index});

  static const List<Color> _colors = [
    Color(0xFF6750A4),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFF00838F),
    Color(0xFF6A1B9A),
    Color(0xFF4527A0),
    Color(0xFF558B2F),
    Color(0xFFBF360C),
  ];

  Color get _accent => _colors[index % _colors.length];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = subject.isPassed ? _accent : Colors.red.shade700;
    final passColor = subject.isPassed ? Colors.green : Colors.red;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Index bubble
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject name
                  Text(
                    subject.name.isNotEmpty ? subject.name : subject.code,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface),
                  ),
                  if (subject.code.isNotEmpty && subject.name.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subject.code,
                      style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withAlpha(140)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Stats chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (subject.gpa.isNotEmpty)
                        _chip(context, 'GPA', subject.gpa, color),
                      if (subject.grade.isNotEmpty)
                        _chip(context, 'Grade', subject.grade, color),
                      if (subject.creditsReg.isNotEmpty)
                        _chip(context, 'Cr. Reg', subject.creditsReg, color),
                      if (subject.creditsEarned.isNotEmpty)
                        _chip(context, 'Cr. Earned', subject.creditsEarned,
                            passColor),
                    ],
                  ),
                ],
              ),
            ),
            // Pass / Fail badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: passColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: passColor.withAlpha(80)),
              ),
              child: Text(
                subject.isPassed ? 'PASS' : 'FAIL',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: passColor,
                    letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
      BuildContext context, String label, String value, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                  fontSize: 11, color: colorScheme.onSurface.withAlpha(140)),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
