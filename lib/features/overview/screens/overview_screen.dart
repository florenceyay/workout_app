import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/workout_log.dart';
import '../../shared/models/exercise.dart';

enum _Period { weekly, monthly, yearly }

// Ordered category keys → display label
const _categoryLabels = <String, String>{
  'arms': 'Arms',
  'back': 'Back',
  'chest': 'Chest',
  'legs': 'Legs',
  'abs': 'Abs',
  'cardio': 'Cardio',
  'calisthenics': 'Body',
  'custom': 'Custom',
};

class OverviewScreen extends ConsumerStatefulWidget {
  const OverviewScreen({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  _Period _period = _Period.weekly;

  DateTime get _periodStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _Period.weekly:
        return today.subtract(const Duration(days: 6));
      case _Period.monthly:
        return today.subtract(const Duration(days: 29));
      case _Period.yearly:
        return today.subtract(const Duration(days: 364));
    }
  }

  int get _periodLengthDays {
    switch (_period) {
      case _Period.weekly:
        return 7;
      case _Period.monthly:
        return 30;
      case _Period.yearly:
        return 365;
    }
  }

  String get _periodLabel {
    switch (_period) {
      case _Period.weekly:
        return 'last 7 days';
      case _Period.monthly:
        return 'last 30 days';
      case _Period.yearly:
        return 'last year';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final logsStream = uid != null
        ? ref.watch(workoutServiceProvider).streamAllLogs(uid)
        : const Stream<List<WorkoutLog>>.empty();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<WorkoutLog>>(
        stream: logsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Merge same-exercise same-day logs so a category's count
          // reflects distinct sessions, not raw log entries.
          final allLogs = WorkoutLog.mergeSameDayLogs(snap.data ?? []);
          final start = _periodStart;
          final filtered = allLogs
              .where((l) =>
                  !l.date.isBefore(start) &&
                  l.date.isBefore(
                      DateTime.now().add(const Duration(days: 1))))
              .toList();

          // Build category breakdown using exercise list as source of truth for
          // category (in case older logs have stale/empty category fields).
          final exerciseCategoryMap = <String, String>{
            for (final ex in kExerciseList) ex.id: ex.category,
          };
          // Group logs by category so we can compute both counts and the
          // "usual day" per slice.
          final logsByCategory = <String, List<WorkoutLog>>{};
          final workoutDays = <String>{};
          for (final log in filtered) {
            final cat = exerciseCategoryMap[log.exerciseId] ?? log.category;
            if (cat.isEmpty) continue;
            logsByCategory.putIfAbsent(cat, () => []).add(log);
            workoutDays
                .add('${log.date.year}-${log.date.month}-${log.date.day}');
          }
          final categoryCounts = {
            for (final e in logsByCategory.entries) e.key: e.value.length,
          };

          final totalWorkouts = filtered.length;
          final daysLogged = workoutDays.length;
          final restDays = math.max(0, _periodLengthDays - daysLogged);

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _PeriodSelector(
                  period: _period,
                  onChanged: (p) => setState(() => _period = p),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: _StatBadge(
                        icon: Icons.fitness_center,
                        value: '$totalWorkouts',
                        label: totalWorkouts == 1
                            ? 'workout logged'
                            : 'workouts logged',
                        accent: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBadge(
                        icon: Icons.hotel,
                        value: '$restDays',
                        label: restDays == 1 ? 'rest day' : 'rest days',
                        accent: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _CategoryPieCard(
                  logsByCategory: logsByCategory,
                  totalWorkouts: totalWorkouts,
                  periodLabel: _periodLabel,
                ),
                const SizedBox(height: 20),

                _SuggestionBanner(
                  categoryCounts: categoryCounts,
                  totalWorkouts: totalWorkouts,
                  daysLogged: daysLogged,
                  period: _period,
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Weekly / Monthly / Yearly segmented toggle
// ──────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final _Period period;
  final ValueChanged<_Period> onChanged;
  const _PeriodSelector({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _tab('Weekly', _Period.weekly),
          _tab('Monthly', _Period.monthly),
          _tab('Yearly', _Period.yearly),
        ],
      ),
    );
  }

  Widget _tab(String label, _Period p) {
    final selected = p == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(p),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Stat badge (workouts logged / rest days)
// ──────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool accent;
  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = accent ? AppColors.accent : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: accent
                ? AppColors.accent.withValues(alpha: 0.3)
                : AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Category breakdown pie chart
// ──────────────────────────────────────────────

class _CategoryPieCard extends StatefulWidget {
  final Map<String, List<WorkoutLog>> logsByCategory;
  final int totalWorkouts;
  final String periodLabel;
  const _CategoryPieCard({
    required this.logsByCategory,
    required this.totalWorkouts,
    required this.periodLabel,
  });

  @override
  State<_CategoryPieCard> createState() => _CategoryPieCardState();
}

class _CategoryPieCardState extends State<_CategoryPieCard> {
  int _touchedIndex = -1;

  @override
  void didUpdateWidget(covariant _CategoryPieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset touched slice when the data set changes (e.g. period switch).
    if (oldWidget.logsByCategory != widget.logsByCategory) {
      _touchedIndex = -1;
    }
  }

  String _mostCommonDay(List<WorkoutLog> logs) {
    if (logs.isEmpty) return '—';
    final counts = <int, int>{};
    for (final l in logs) {
      counts[l.date.weekday] = (counts[l.date.weekday] ?? 0) + 1;
    }
    final topWeekday =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    const dayNames = {
      DateTime.monday: 'Mondays',
      DateTime.tuesday: 'Tuesdays',
      DateTime.wednesday: 'Wednesdays',
      DateTime.thursday: 'Thursdays',
      DateTime.friday: 'Fridays',
      DateTime.saturday: 'Saturdays',
      DateTime.sunday: 'Sundays',
    };
    return dayNames[topWeekday] ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    // Keep only categories with at least one log, sorted by count descending
    // so the largest slice gets the most prominent color tone.
    final entries = <MapEntry<String, List<WorkoutLog>>>[];
    for (final key in _categoryLabels.keys) {
      final logs = widget.logsByCategory[key];
      if (logs != null && logs.isNotEmpty) {
        entries.add(MapEntry(key, logs));
      }
    }
    entries.sort((a, b) => b.value.length.compareTo(a.value.length));
    final total = entries.fold<int>(0, (s, e) => s + e.value.length);
    final isEmpty = total == 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Muscle group breakdown',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            widget.periodLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),

          if (isEmpty)
            SizedBox(
              height: 220,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pie_chart_outline,
                        color: AppColors.textGhost, size: 48),
                    const SizedBox(height: 8),
                    const Text(
                      'No workouts in this period yet',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            // Fixed-size stack so the chart doesn't relayout on touch.
            SizedBox(
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 72,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          // Continuous "hover" behaviour: update _touchedIndex
                          // while the finger is on the chart, clear on release.
                          // Only setState when the index actually changes so
                          // most pointer events are no-ops (no rebuild).
                          final isEnd = event is FlTapUpEvent ||
                              event is FlLongPressEnd ||
                              event is FlPanEndEvent ||
                              event is FlPanCancelEvent ||
                              event is FlPointerExitEvent;
                          int next;
                          if (isEnd ||
                              response == null ||
                              response.touchedSection == null) {
                            next = -1;
                          } else {
                            next = response
                                .touchedSection!.touchedSectionIndex;
                            if (next < 0) next = -1;
                          }
                          if (next != _touchedIndex) {
                            setState(() => _touchedIndex = next);
                          }
                        },
                      ),
                      sections: [
                        for (var i = 0; i < entries.length; i++)
                          _buildSection(
                            entries[i],
                            total,
                            index: i,
                            totalSlices: entries.length,
                            isTouched: i == _touchedIndex,
                          ),
                      ],
                    ),
                  ),
                  // Center info — constrained so it doesn't push layout.
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: Center(
                      child: _CenterInfo(
                        touched: _touchedIndex >= 0 &&
                                _touchedIndex < entries.length
                            ? entries[_touchedIndex]
                            : null,
                        totalWorkouts: total,
                        mostCommonDay: _touchedIndex >= 0 &&
                                _touchedIndex < entries.length
                            ? _mostCommonDay(entries[_touchedIndex].value)
                            : '',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (!isEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Hold and drag over a slice for details',
                style: TextStyle(
                  color: AppColors.textGhost,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  PieChartSectionData _buildSection(
    MapEntry<String, List<WorkoutLog>> entry,
    int total, {
    required int index,
    required int totalSlices,
    required bool isTouched,
  }) {
    // Theme accent with varying opacity per slice — muted so it's easy on
    // the eyes. Largest slice (index 0 after sort) is brightest; smaller
    // slices fade. The gaps (sectionsSpace) keep slices visually separated.
    final t = totalSlices == 1 ? 0.0 : index / (totalSlices - 1);
    final opacity = 0.70 - (t * 0.45); // 0.70 → 0.25
    final color = AppColors.accent.withValues(alpha: opacity);

    final label = _categoryLabels[entry.key] ?? entry.key;
    final percent = (entry.value.length / total) * 100;
    // Hide inline label on tiny slices (<8%) to avoid clipping.
    final showLabel = percent >= 8;

    return PieChartSectionData(
      value: entry.value.length.toDouble(),
      color: color,
      title: '',
      // Smaller delta so the layout barely shifts when tapping a slice.
      radius: isTouched ? 68 : 62,
      badgeWidget:
          showLabel ? _SliceLabel(label: label) : null,
      // Lower offset → closer to the middle of the ring width.
      badgePositionPercentageOffset: 0.55,
    );
  }
}

// ──────────────────────────────────────────────
// Label rendered on each slice
// ──────────────────────────────────────────────

class _SliceLabel extends StatelessWidget {
  final String label;
  const _SliceLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF111318),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Center info (inside the doughnut)
// ──────────────────────────────────────────────

class _CenterInfo extends StatelessWidget {
  final MapEntry<String, List<WorkoutLog>>? touched;
  final int totalWorkouts;
  final String mostCommonDay;
  const _CenterInfo({
    required this.touched,
    required this.totalWorkouts,
    required this.mostCommonDay,
  });

  @override
  Widget build(BuildContext context) {
    if (touched == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$totalWorkouts',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'workouts',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    final key = touched!.key;
    final logs = touched!.value;
    final label = _categoryLabels[key] ?? key;
    final percent = (logs.length / totalWorkouts * 100).round();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Padding(
        key: ValueKey(key),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$percent%',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${logs.length} ${logs.length == 1 ? "workout" : "workouts"}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Usually on $mostCommonDay',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Suggestion banner
// ──────────────────────────────────────────────

class _Suggestion {
  final IconData icon;
  final String title;
  final String body;
  const _Suggestion(this.icon, this.title, this.body);
}

class _SuggestionBanner extends StatelessWidget {
  final Map<String, int> categoryCounts;
  final int totalWorkouts;
  final int daysLogged;
  final _Period period;
  const _SuggestionBanner({
    required this.categoryCounts,
    required this.totalWorkouts,
    required this.daysLogged,
    required this.period,
  });

  _Suggestion _generateSuggestion() {
    if (totalWorkouts == 0) {
      return const _Suggestion(
        Icons.rocket_launch,
        'Ready to start?',
        'No workouts logged yet in this period. Log your first session to see your muscle group balance.',
      );
    }

    final trained = categoryCounts.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toSet();

    final missing = <String>[];
    for (final key in ['legs', 'cardio', 'back', 'chest', 'arms', 'abs']) {
      if (!trained.contains(key)) missing.add(key);
    }

    if (missing.contains('legs')) {
      return const _Suggestion(
        Icons.directions_run,
        "Don't skip leg day!",
        'No leg workouts logged in this period. Squats, lunges, or deadlifts would round out your routine nicely.',
      );
    }
    if (missing.contains('cardio')) {
      return const _Suggestion(
        Icons.favorite,
        'Add some cardio',
        'No cardio sessions logged. A run or bike ride can boost recovery and heart health alongside your lifting.',
      );
    }
    if (missing.contains('back')) {
      return const _Suggestion(
        Icons.accessibility_new,
        'Balance your pushes with pulls',
        'Your back is missing from this period. Rows or pull-ups will keep your posture and shoulders healthy.',
      );
    }
    if (missing.contains('chest')) {
      return const _Suggestion(
        Icons.fitness_center,
        'Hit the chest',
        'No chest work logged. Bench or push-ups will balance your upper body.',
      );
    }
    if (missing.contains('abs')) {
      return const _Suggestion(
        Icons.self_improvement,
        'Core could use attention',
        'No ab work this period. A few minutes of core at the end of a session goes a long way.',
      );
    }

    if (totalWorkouts >= 4) {
      final dominant = categoryCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b);
      final share = dominant.value / totalWorkouts;
      if (share >= 0.6) {
        final name = _categoryLabels[dominant.key] ?? dominant.key;
        return _Suggestion(
          Icons.balance,
          'Watch the balance',
          '${(share * 100).round()}% of your workouts this period have been $name. Consider mixing in other muscle groups for a well-rounded routine.',
        );
      }
    }

    int expectedDays;
    switch (period) {
      case _Period.weekly:
        expectedDays = 3;
        break;
      case _Period.monthly:
        expectedDays = 12;
        break;
      case _Period.yearly:
        expectedDays = 150;
        break;
    }
    if (daysLogged < expectedDays) {
      return _Suggestion(
        Icons.calendar_month,
        'Build consistency',
        'You trained on $daysLogged ${daysLogged == 1 ? 'day' : 'days'} this period. Aiming for a regular cadence beats any single hard session.',
      );
    }

    return const _Suggestion(
      Icons.emoji_events,
      'Great balance!',
      'All major muscle groups are covered this period. Keep it up — consistency is the real cheat code.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _generateSuggestion();
    // Use ClipRRect + IntrinsicHeight so the accent strip on the left
    // hugs the rounded corners cleanly (non-uniform Border + borderRadius is
    // not allowed in Flutter, so we build it with a separate coloured strip).
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.divider),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent strip
              Container(width: 3, color: AppColors.accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(s.icon, color: AppColors.accent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.body,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
