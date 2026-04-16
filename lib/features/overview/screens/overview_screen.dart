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

/// Whether the user wants a rolling window ("last N days") or a calendar-
/// aligned window ("this week / month / year").
enum _PeriodMode { rolling, calendar }

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
  _PeriodMode _mode = _PeriodMode.rolling;

  DateTime get _periodStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (_period) {
      case _Period.weekly:
        if (_mode == _PeriodMode.calendar) {
          // "This week" — since last Sunday.
          final weekday = today.weekday % 7; // Sun=0
          return today.subtract(Duration(days: weekday));
        }
        return today.subtract(const Duration(days: 6));
      case _Period.monthly:
        if (_mode == _PeriodMode.calendar) {
          // "This month" — since the 1st.
          return DateTime(today.year, today.month, 1);
        }
        return today.subtract(const Duration(days: 29));
      case _Period.yearly:
        if (_mode == _PeriodMode.calendar) {
          // "This year" — since Jan 1.
          return DateTime(today.year, 1, 1);
        }
        return today.subtract(const Duration(days: 364));
    }
  }

  int get _periodLengthDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = _periodStart;
    return today.difference(start).inDays + 1;
  }

  String get _periodLabel {
    switch (_period) {
      case _Period.weekly:
        return _mode == _PeriodMode.calendar ? 'this week' : 'last 7 days';
      case _Period.monthly:
        if (_mode == _PeriodMode.calendar) {
          const months = [
            '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
          ];
          return 'since ${months[DateTime.now().month]} 1';
        }
        return 'last 30 days';
      case _Period.yearly:
        return _mode == _PeriodMode.calendar
            ? 'since Jan 1'
            : 'last 365 days';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeBrightnessProvider); // rebuild on light/dark toggle
    AppColors.accent = ref.watch(displayAccentProvider);
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
          final allLogs = WorkoutLog.mergeSameDayLogs(snap.data ?? []);
          final start = _periodStart;
          final filtered = allLogs
              .where((l) =>
                  !l.date.isBefore(start) &&
                  l.date.isBefore(
                      DateTime.now().add(const Duration(days: 1))))
              .toList();

          final exerciseCategoryMap = <String, String>{
            for (final ex in kExerciseList) ex.id: ex.category,
          };
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
                  mode: _mode,
                  onChanged: (p, m) => setState(() {
                    _period = p;
                    _mode = m;
                  }),
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
// Weekly / Monthly / Yearly segmented toggle with dropdowns
// ──────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final _Period period;
  final _PeriodMode mode;
  final void Function(_Period, _PeriodMode) onChanged;
  const _PeriodSelector({
    required this.period,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _tab(context, 'Weekly', _Period.weekly),
          _tab(context, 'Monthly', _Period.monthly),
          _tab(context, 'Yearly', _Period.yearly),
        ],
      ),
    );
  }

  List<PopupMenuEntry<_PeriodMode>> _menuItems(_Period p) {
    switch (p) {
      case _Period.weekly:
        return [
          _modeItem(_PeriodMode.rolling, 'Last 7 days', p),
          _modeItem(_PeriodMode.calendar, 'This week', p),
        ];
      case _Period.monthly:
        const months = [
          '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        final monthLabel = 'Since ${months[DateTime.now().month]} 1';
        return [
          _modeItem(_PeriodMode.rolling, 'Last 30 days', p),
          _modeItem(_PeriodMode.calendar, monthLabel, p),
        ];
      case _Period.yearly:
        return [
          _modeItem(_PeriodMode.rolling, 'Last 365 days', p),
          _modeItem(_PeriodMode.calendar, 'Since Jan 1', p),
        ];
    }
  }

  PopupMenuItem<_PeriodMode> _modeItem(
      _PeriodMode m, String label, _Period p) {
    final isActive = p == period && m == mode;
    return PopupMenuItem<_PeriodMode>(
      value: m,
      child: Row(
        children: [
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.check, size: 16, color: AppColors.accent),
            ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.accent : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, String label, _Period p) {
    final selected = p == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // If tapping the already-selected period, show dropdown options.
          // If tapping a different period, just switch to it (keep mode).
          if (selected) {
            _showMenu(context, p);
          } else {
            onChanged(p, mode);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 3),
                Icon(
                  Icons.expand_more,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context, _Period p) async {
    // Position the popup menu below the tab.
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final result = await showMenu<_PeriodMode>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        offset.dx + box.size.width,
        0,
      ),
      items: _menuItems(p),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.divider, width: 0.5),
      ),
      elevation: 8,
    );
    if (result != null) {
      onChanged(p, result);
    }
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
        borderRadius: BorderRadius.circular(14),
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
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
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
// Category breakdown pie chart — 3D style
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

class _CategoryPieCardState extends State<_CategoryPieCard>
    with SingleTickerProviderStateMixin {
  int _touchedIndex = -1;

  @override
  void didUpdateWidget(covariant _CategoryPieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  List<MapEntry<String, List<WorkoutLog>>> _sortedEntries() {
    final entries = <MapEntry<String, List<WorkoutLog>>>[];
    for (final key in _categoryLabels.keys) {
      final logs = widget.logsByCategory[key];
      if (logs != null && logs.isNotEmpty) {
        entries.add(MapEntry(key, logs));
      }
    }
    entries.sort((a, b) => b.value.length.compareTo(a.value.length));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _sortedEntries();
    final total = entries.fold<int>(0, (s, e) => s + e.value.length);
    final isEmpty = total == 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Muscle group breakdown',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            widget.periodLabel,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),

          if (isEmpty)
            SizedBox(
              height: 180,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pie_chart_outline,
                        color: AppColors.textGhost, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'No workouts in this period yet',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Shadow layer — drawn behind the main chart
                  if (_touchedIndex >= 0 && _touchedIndex < entries.length)
                    CustomPaint(
                      size: const Size(220, 220),
                      painter: _DonutShadowPainter(
                        entries: entries,
                        total: total,
                        touchedIndex: _touchedIndex,
                        accent: AppColors.accent,
                      ),
                    ),
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 56,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
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
                  // Center info
                  SizedBox(
                    width: 100,
                    height: 100,
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
            const SizedBox(height: 4),
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
    final t = totalSlices == 1 ? 0.0 : index / (totalSlices - 1);
    final opacity = 0.70 - (t * 0.45); // 0.70 → 0.25
    final color = AppColors.accent.withValues(alpha: opacity);

    final label = _categoryLabels[entry.key] ?? entry.key;
    final percent = (entry.value.length / total) * 100;
    final showLabel = percent >= 8;

    return PieChartSectionData(
      value: entry.value.length.toDouble(),
      color: color,
      title: '',
      // 3D effect: touched slice is significantly larger
      radius: isTouched ? 72 : 50,
      badgeWidget: showLabel ? _SliceLabel(label: label) : null,
      badgePositionPercentageOffset: 0.55,
    );
  }
}

// ──────────────────────────────────────────────
// Custom painter to draw shadow under the touched slice
// ──────────────────────────────────────────────

class _DonutShadowPainter extends CustomPainter {
  final List<MapEntry<String, List<WorkoutLog>>> entries;
  final int total;
  final int touchedIndex;
  final Color accent;

  _DonutShadowPainter({
    required this.entries,
    required this.total,
    required this.touchedIndex,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (touchedIndex < 0 || touchedIndex >= entries.length) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = 72.0 + 56.0; // touched radius + centerSpaceRadius
    final innerRadius = 56.0;

    // Compute the start angle and sweep for the touched slice.
    const startOffset = -90.0; // fl_chart startDegreeOffset
    const gapDeg = 3.0 * 360 / (2 * math.pi * 56); // approximate gap in degrees
    double runningAngle = startOffset;
    double sliceStart = 0;
    double sliceSweep = 0;

    for (var i = 0; i < entries.length; i++) {
      final sweep = (entries[i].value.length / total) * 360.0;
      if (i == touchedIndex) {
        sliceStart = runningAngle;
        sliceSweep = sweep;
        break;
      }
      runningAngle += sweep;
    }

    // Draw a soft shadow arc slightly offset (simulating depth).
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final shadowOffset = Offset(2, 3); // slight down-right offset for depth
    final shadowCenter = center + shadowOffset;

    final path = Path();
    final startRad = sliceStart * math.pi / 180;
    final sweepRad = sliceSweep * math.pi / 180;

    // Outer arc
    path.addArc(
      Rect.fromCircle(center: shadowCenter, radius: outerRadius),
      startRad,
      sweepRad,
    );
    // Line to inner arc end
    final innerEndX = shadowCenter.dx + innerRadius * math.cos(startRad + sweepRad);
    final innerEndY = shadowCenter.dy + innerRadius * math.sin(startRad + sweepRad);
    path.lineTo(innerEndX, innerEndY);
    // Inner arc (reverse direction)
    path.arcTo(
      Rect.fromCircle(center: shadowCenter, radius: innerRadius),
      startRad + sweepRad,
      -sweepRad,
      false,
    );
    path.close();

    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant _DonutShadowPainter old) =>
      old.touchedIndex != touchedIndex || old.total != total || old.accent != accent;
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
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'workouts',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$percent%',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${logs.length} ${logs.length == 1 ? "workout" : "workouts"}',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Usually on\n$mostCommonDay',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.body,
                              style: TextStyle(
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
