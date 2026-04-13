import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/workout_log.dart';

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  final String exerciseId;
  final String exerciseName;

  const ExerciseDetailScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
  });

  @override
  ConsumerState<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

enum _ChartMode { avgWeight, firstSet }

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  _ChartMode _chartMode = _ChartMode.avgWeight;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    final weightUnit = ref.watch(unitPreferenceProvider);
    final distanceUnit = ref.watch(distanceUnitProvider);
    final stream = ref.watch(workoutServiceProvider).streamExerciseLogs(uid, widget.exerciseId);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseName, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Builder(builder: (context) {
            final pinned = ref
                .watch(pinnedQuickCheckProvider)
                .contains(widget.exerciseId);
            return IconButton(
              tooltip:
                  pinned ? 'Unpin from Quick Check' : 'Pin to Quick Check',
              icon: Icon(
                pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: pinned ? AppColors.accent : AppColors.textSecondary,
              ),
              onPressed: () async {
                await ref
                    .read(pinnedQuickCheckProvider.notifier)
                    .toggle(widget.exerciseId);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 1),
                    backgroundColor: AppColors.surface,
                    content: Text(
                      ref
                              .read(pinnedQuickCheckProvider)
                              .contains(widget.exerciseId)
                          ? 'Pinned to Quick Check'
                          : 'Unpinned from Quick Check',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
      body: StreamBuilder<List<WorkoutLog>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: AppColors.error)));
          }
          // Merge multiple logs of this exercise on the same day into a
          // single combined session. Sort ascending for chart ordering.
          final raw = snap.data ?? [];
          final logs = WorkoutLog.mergeSameDayLogs(raw)
            ..sort((a, b) => a.date.compareTo(b.date));

          if (logs.isEmpty) {
            return const Center(
              child: Text('No sessions logged yet.', style: TextStyle(color: AppColors.textSecondary)),
            );
          }

          final category = logs.first.category;
          final isCardio = category == 'cardio';
          final isBodyweight = category == 'bodyweight' || category == 'calisthenics';

          // Build a map of date → log for calendar events
          final logsByDay = <DateTime, WorkoutLog>{};
          for (final log in logs) {
            final day = DateTime(log.date.year, log.date.month, log.date.day);
            logsByDay[day] = log;
          }

          // Selected day's log
          final selectedLog = _selectedDay != null
              ? logsByDay[DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)]
              : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Toggle (only for normal weighted workouts)
              if (!isCardio && !isBodyweight) ...[
                Row(
                  children: [
                    _ToggleChip(
                      label: 'Avg Weight',
                      selected: _chartMode == _ChartMode.avgWeight,
                      onTap: () => setState(() => _chartMode = _ChartMode.avgWeight),
                    ),
                    const SizedBox(width: 8),
                    _ToggleChip(
                      label: 'First Set',
                      selected: _chartMode == _ChartMode.firstSet,
                      onTap: () => setState(() => _chartMode = _ChartMode.firstSet),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Chart
              _ProgressionChart(
                logs: logs,
                isCardio: isCardio,
                isBodyweight: isBodyweight,
                mode: _chartMode,
                weightUnit: weightUnit,
                distanceUnit: distanceUnit,
              ),
              const SizedBox(height: 24),

              // Calendar
              const Text('Sessions',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: TableCalendar(
                  firstDay: DateTime(2020),
                  lastDay: DateTime.now().add(const Duration(days: 1)),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                  eventLoader: (day) {
                    final key = DateTime(day.year, day.month, day.day);
                    return logsByDay.containsKey(key) ? [logsByDay[key]!] : [];
                  },
                  onDaySelected: (selected, focused) {
                    final key = DateTime(selected.year, selected.month, selected.day);
                    if (logsByDay.containsKey(key)) {
                      setState(() {
                        _selectedDay = isSameDay(_selectedDay, selected) ? null : selected;
                        _focusedDay = focused;
                      });
                    }
                  },
                  onPageChanged: (focused) => setState(() => _focusedDay = focused),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle: const TextStyle(color: AppColors.textPrimary),
                    weekendTextStyle: const TextStyle(color: AppColors.textPrimary),
                    selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    todayTextStyle: const TextStyle(color: AppColors.textPrimary),
                    disabledTextStyle: const TextStyle(color: AppColors.textGhost),
                    outsideTextStyle: const TextStyle(color: AppColors.textGhost),
                    markerDecoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    markerSize: 6,
                    markersMaxCount: 1,
                  ),
                  headerStyle: const HeaderStyle(
                    titleTextStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                    leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textSecondary),
                    rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    weekendStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ),

              // Selected day session detail
              if (selectedLog != null) ...[
                const SizedBox(height: 16),
                _SessionDetail(log: selectedLog),
              ] else ...[
                const SizedBox(height: 12),
                const Center(
                  child: Text('Tap a highlighted day to see your session',
                      style: TextStyle(color: AppColors.textGhost, fontSize: 13)),
                ),
              ],

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Progression chart
// ──────────────────────────────────────────────

class _ProgressionChart extends StatelessWidget {
  final List<WorkoutLog> logs;
  final bool isCardio;
  final bool isBodyweight;
  final _ChartMode mode;
  final String weightUnit;
  final String distanceUnit;
  const _ProgressionChart({
    required this.logs,
    required this.isCardio,
    required this.isBodyweight,
    required this.mode,
    required this.weightUnit,
    required this.distanceUnit,
  });

  // Convert a kg value to the user's preferred display unit.
  double _wDisplay(double kg) => weightUnit == 'lb' ? kg * 2.20462 : kg;
  // Convert a km value to user's preferred distance unit.
  double _dDisplay(double km) => distanceUnit == 'mi' ? km * 0.621371 : km;

  // Computes the y-value for a given log based on category/mode.
  double _yValue(WorkoutLog log) {
    if (isCardio) {
      // Average speed across the session: total distance / total time (per hour).
      final totalDist = log.sets.fold<double>(0, (a, s) => a + s.distance);
      final totalMin = log.sets.fold<double>(0, (a, s) => a + s.durationMinutes);
      if (totalMin == 0) return 0;
      final speedKmh = totalDist / (totalMin / 60.0);
      return _dDisplay(speedKmh);
    }
    if (isBodyweight) {
      // Total reps across all sets in the session.
      return log.sets.fold<double>(0, (a, s) => a + s.reps).toDouble();
    }
    if (mode == _ChartMode.firstSet) {
      return log.sets.isEmpty ? 0 : _wDisplay(log.sets.first.weight);
    }
    // Avg weight across sets.
    if (log.sets.isEmpty) return 0;
    final avg = log.sets.fold<double>(0, (a, s) => a + s.weight) / log.sets.length;
    return _wDisplay(avg);
  }

  String _yLabel() {
    if (isCardio) return distanceUnit == 'mi' ? 'mph' : 'km/h';
    if (isBodyweight) return 'reps';
    return weightUnit;
  }

  String _tooltipExtra(WorkoutLog log) {
    if (isCardio) {
      final totalDist = log.sets.fold<double>(0, (a, s) => a + s.distance);
      final totalMin = log.sets.fold<double>(0, (a, s) => a + s.durationMinutes);
      final d = _dDisplay(totalDist);
      final dStr = d % 1 == 0 ? d.toStringAsFixed(0) : d.toStringAsFixed(2);
      final mStr = totalMin % 1 == 0 ? totalMin.toStringAsFixed(0) : totalMin.toStringAsFixed(1);
      return '$dStr $distanceUnit • $mStr min';
    }
    if (isBodyweight) {
      return '${log.sets.length} ${log.sets.length == 1 ? 'set' : 'sets'}';
    }
    if (mode == _ChartMode.firstSet) {
      final s = log.sets.isNotEmpty ? log.sets.first : null;
      return s == null ? '' : '${_fmt(_wDisplay(s.weight))} $weightUnit × ${s.reps} reps';
    }
    return '${log.sets.length} ${log.sets.length == 1 ? 'set' : 'sets'}';
  }

  @override
  Widget build(BuildContext context) {
    if (logs.length < 2) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Center(
          child: Text('Log more sessions to see your chart.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
      );
    }

    // Logs are sorted descending in the stream — chart wants ascending by date.
    final ordered = [...logs]..sort((a, b) => a.date.compareTo(b.date));
    final values = ordered.map(_yValue).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).clamp(1.0, double.infinity);
    final spots = List.generate(ordered.length, (i) => FlSpot(i.toDouble(), values[i]));
    final yLabel = _yLabel();

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: LineChart(
        LineChartData(
          minY: (minVal - range * 0.1).clamp(0, double.infinity),
          maxY: maxVal + range * 0.1,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(_fmt(v),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ),
            ),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: AppColors.accent,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) =>
                    FlDotCirclePainter(radius: 3, color: AppColors.accent, strokeWidth: 0),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.accent.withValues(alpha: 0.08),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              tooltipBorder: const BorderSide(color: AppColors.divider),
              getTooltipItems: (spots) => spots.map((s) {
                final log = ordered[s.x.toInt()];
                final extra = _tooltipExtra(log);
                return LineTooltipItem(
                  '${_fmt(s.y)} $yLabel\n',
                  TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 13),
                  children: [
                    TextSpan(
                      text: '${log.date.day}/${log.date.month}${extra.isNotEmpty ? '  •  $extra' : ''}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ──────────────────────────────────────────────
// Selected day session detail
// ──────────────────────────────────────────────

class _SessionDetail extends StatelessWidget {
  final WorkoutLog log;
  const _SessionDetail({required this.log});

  @override
  Widget build(BuildContext context) {
    final isBodyweight = log.category == 'bodyweight' || log.category == 'calisthenics';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_formatDate(log.date),
                  style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (log.isPersonalRecord)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.prGold, borderRadius: BorderRadius.circular(4)),
                  child: const Text('PR', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...log.sets.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text('Set ${i + 1}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ),
                  Text(
                    isBodyweight
                        ? '${s.reps} reps'
                        : '${_fmtW(s.weight)} kg × ${s.reps} reps',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  ),
                ],
              ),
            );
          }),
          if (!isBodyweight && log.totalVolume > 0) ...[
            const Divider(color: AppColors.divider, height: 16),
            Text('Total volume: ${_fmtW(log.totalVolume)} kg',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _fmtW(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ──────────────────────────────────────────────
// Toggle chip
// ──────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AppColors.accent : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
