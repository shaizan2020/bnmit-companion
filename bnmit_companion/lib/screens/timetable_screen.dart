import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bnmit_companion/providers/timetable_provider.dart';

class TimetableScreen extends ConsumerWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timetableAsync = ref.watch(timetableProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(timetableProvider.notifier).refresh(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(timetableProvider.notifier).refresh(),
        child: timetableAsync.when(
          data: (timetable) {
            if (timetable.days.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 64,
                      color: colorScheme.onSurface.withAlpha(64),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No timetable data available',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Timetable may not be published yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withAlpha(102),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (timetable.prevWeekStart != null)
                          OutlinedButton.icon(
                            onPressed: () => ref
                                .read(timetableProvider.notifier)
                                .loadPreviousWeek(
                                  timetable.prevWeekStart!,
                                  timetable.prevWeekEnd!,
                                ),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Previous Week'),
                          ),
                        const SizedBox(width: 12),
                        if (timetable.nextWeekStart != null)
                          OutlinedButton.icon(
                            onPressed: () => ref
                                .read(timetableProvider.notifier)
                                .loadNextWeek(
                                  timetable.nextWeekStart!,
                                  timetable.nextWeekEnd!,
                                ),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Next Week'),
                          ),
                      ],
                    ).animate().fadeIn(delay: 300.ms),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: timetable.days.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    children: [
                      // Week navigation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (timetable.prevWeekStart != null)
                            TextButton.icon(
                              onPressed: () => ref
                                  .read(timetableProvider.notifier)
                                  .loadPreviousWeek(
                                    timetable.prevWeekStart!,
                                    timetable.prevWeekEnd!,
                                  ),
                              icon: const Icon(Icons.arrow_back_ios, size: 16),
                              label: const Text('Previous'),
                            )
                          else
                            const SizedBox(),
                          if (timetable.nextWeekStart != null)
                            TextButton.icon(
                              onPressed: () => ref
                                  .read(timetableProvider.notifier)
                                  .loadNextWeek(
                                    timetable.nextWeekStart!,
                                    timetable.nextWeekEnd!,
                                  ),
                              icon: const Icon(Icons.arrow_forward_ios, size: 16),
                              label: const Text('Next'),
                            )
                          else
                            const SizedBox(),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }

                final day = timetable.days[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildDayCard(context, day)
                      .animate(delay: (index * 100).ms)
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
                Text('Failed to load timetable'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(timetableProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCard(BuildContext context, dynamic day) {
    final colorScheme = Theme.of(context).colorScheme;
    final isToday = day.isToday;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? colorScheme.primary.withAlpha(100)
              : colorScheme.outline.withAlpha(20),
          width: isToday ? 2 : 1,
        ),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isToday
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerLow,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Text(
                  '${day.dayName} ${day.date}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isToday
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (day.periods.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No classes scheduled',
                style: TextStyle(
                  color: colorScheme.onSurface.withAlpha(102),
                  fontSize: 13,
                ),
              ),
            )
          else
            ...day.periods.map<Widget>((period) => _buildPeriodTile(
                  context,
                  period,
                )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildPeriodTile(BuildContext context, dynamic period) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.subjectName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  '${period.timeRange} • ${period.faculty}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withAlpha(128),
                  ),
                ),
              ],
            ),
          ),
          if (period.room.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                period.room,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withAlpha(153),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
