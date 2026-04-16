import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/mini_progress_chart.dart';
import '../../shared/models/workout_log.dart';
import '../../shared/models/exercise.dart';
import 'exercise_detail_screen.dart';

enum _HistoryMode { byDay, byMuscle }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _HistoryMode _mode = _HistoryMode.byDay;

  @override
  Widget build(BuildContext context) {
    ref.watch(themeBrightnessProvider); // rebuild on light/dark toggle
    // Sync the global so child StatelessWidgets that read AppColors.accent
    // directly get the correct value on the same build frame.
    AppColors.accent = ref.watch(displayAccentProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    final logsStream = ref.watch(workoutServiceProvider).streamAllLogs(uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<WorkoutLog>>(
        stream: logsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
                child: Text('Error loading history.',
                    style: TextStyle(color: AppColors.textSecondary)));
          }

          // Merge multiple same-exercise logs on the same day into a
          // single combined session (sets concatenated, volume summed).
          final allLogs = WorkoutLog.mergeSameDayLogs(snap.data ?? []);

          return Column(
            children: [
              // Top toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _HistoryModeToggle(
                  mode: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
              ),
              Expanded(
                child: allLogs.isEmpty
                    ? _EmptyState()
                    : _mode == _HistoryMode.byDay
                        ? _ByDayView(
                            logs: allLogs,
                            quickCheck: _QuickCheckBar(logs: allLogs),
                          )
                        : _ByMuscleView(
                            logs: allLogs,
                            quickCheck: _QuickCheckBar(logs: allLogs),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Empty state
// ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, color: AppColors.textGhost, size: 48),
          const SizedBox(height: 12),
          Text(
            'No workouts logged yet.\nLog your first session!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Segmented toggle (Day-by-day / By muscle group)
// ──────────────────────────────────────────────

class _HistoryModeToggle extends StatelessWidget {
  final _HistoryMode mode;
  final ValueChanged<_HistoryMode> onChanged;
  const _HistoryModeToggle({required this.mode, required this.onChanged});

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
          _tab('Day-by-day', _HistoryMode.byDay),
          _tab('Muscle group', _HistoryMode.byMuscle),
        ],
      ),
    );
  }

  Widget _tab(String label, _HistoryMode m) {
    final selected = m == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(m),
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
// Day-by-day view: one row per day, expands on tap
// ──────────────────────────────────────────────

class _ByDayView extends StatefulWidget {
  final List<WorkoutLog> logs;
  final Widget quickCheck;
  const _ByDayView({required this.logs, required this.quickCheck});

  @override
  State<_ByDayView> createState() => _ByDayViewState();
}

class _ByDayViewState extends State<_ByDayView> {
  final Set<String> _expanded = <String>{};

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // Group logs by date
    final grouped = <String, List<WorkoutLog>>{};
    for (final log in widget.logs) {
      grouped.putIfAbsent(_dateKey(log.date), () => []).add(log);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: dates.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) return widget.quickCheck;
        final key = dates[i - 1];
        final dayLogs = grouped[key]!;
        final parsed = DateTime.parse(key);
        final isOpen = _expanded.contains(key);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() {
                  if (isOpen) {
                    _expanded.remove(key);
                  } else {
                    _expanded.add(key);
                  }
                }),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(parsed),
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${dayLogs.length} workout${dayLogs.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isOpen ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (isOpen) ...[
                Divider(height: 1, color: AppColors.divider),
                ...dayLogs.map((log) => _SessionRow(
                      log: log,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseDetailScreen(
                            exerciseId: log.exerciseId,
                            exerciseName: log.exerciseName,
                          ),
                        ),
                      ),
                    )),
                const SizedBox(height: 4),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Yesterday';
    }
    final dayName = days[d.weekday - 1];
    return '$dayName, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ──────────────────────────────────────────────
// Single workout row inside a day entry
// ──────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  final WorkoutLog log;
  final VoidCallback onTap;
  const _SessionRow({required this.log, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBodyweight =
        log.category == 'bodyweight' || log.category == 'calisthenics';
    final topSet = log.sets.isEmpty
        ? null
        : log.sets.reduce((a, b) => a.weight > b.weight ? a : b);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          log.exerciseName,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (log.isPersonalRecord) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.prGold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PR',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isBodyweight
                        ? '${log.sets.length} set${log.sets.length == 1 ? '' : 's'} · ${log.sets.map((s) => s.reps).join(' / ')} reps'
                        : topSet != null
                            ? '${_fmtW(topSet.weight)} kg × ${topSet.reps}  ·  ${log.sets.length} set${log.sets.length == 1 ? '' : 's'}'
                            : '',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  String _fmtW(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

// ──────────────────────────────────────────────
// By-muscle-group view: grid of category badges
// ──────────────────────────────────────────────

class _ByMuscleView extends ConsumerWidget {
  final List<WorkoutLog> logs;
  final Widget quickCheck;
  const _ByMuscleView({required this.logs, required this.quickCheck});

  static const _categories = [
    {'key': 'arms', 'label': 'Arms', 'asset': 'assets/icons/arms.png'},
    {'key': 'back', 'label': 'Back', 'asset': 'assets/icons/back.png'},
    {'key': 'chest', 'label': 'Chest', 'asset': 'assets/icons/chest.png'},
    {'key': 'legs', 'label': 'Legs', 'asset': 'assets/icons/legs.png'},
    {'key': 'abs', 'label': 'Abs', 'asset': 'assets/icons/abs.png'},
    {'key': 'cardio', 'label': 'Cardio', 'asset': 'assets/icons/cardio.png'},
    {
      'key': 'calisthenics',
      'label': 'Body-\nweight',
      'asset': 'assets/icons/bodyweight.png'
    },
    {'key': 'custom', 'label': 'Custom', 'asset': 'assets/icons/custom.png'},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Build category → count (using kExerciseList as source of truth)
    final exerciseCategoryMap = <String, String>{
      for (final ex in kExerciseList) ex.id: ex.category,
    };
    final categoryCounts = <String, int>{};
    final logsByCategory = <String, List<WorkoutLog>>{};
    for (final log in logs) {
      final cat = exerciseCategoryMap[log.exerciseId] ?? log.category;
      if (cat.isEmpty) continue;
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      logsByCategory.putIfAbsent(cat, () => []).add(log);
    }

    final tint = ref.watch(displayAccentProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        quickCheck,
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, i) {
            final cat = _categories[i];
            final key = cat['key'] as String;
            return _MuscleBadge(
              label: cat['label'] as String,
              asset: cat['asset'] as String,
              tint: tint,
              count: categoryCounts[key] ?? 0,
              progression: computeProgression(logsByCategory[key] ?? const []),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _SubcategoryHistoryScreen(
                      categoryKey: key,
                      categoryLabel: kCategoryLabels[key] ?? key,
                      logs: logs,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Muscle badge (grid tile) — no mini calendar
// ──────────────────────────────────────────────

class _MuscleBadge extends StatelessWidget {
  final String label;
  final String asset;
  final Color tint;
  final int count;
  final List<double> progression;
  final VoidCallback onTap;

  const _MuscleBadge({
    required this.label,
    required this.asset,
    required this.tint,
    required this.count,
    required this.progression,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(
                        asset,
                        width: 64,
                        height: 64,
                        color: tint,
                        filterQuality: FilterQuality.medium,
                      ),
                      SizedBox(
                        width: 90,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Mini progression chart (top-right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: SizedBox(
                      width: 64,
                      height: 32,
                      child: MiniProgressChart(
                        points: progression,
                        color: tint,
                      ),
                    ),
                  ),
                  // Log count (bottom-right)
                  Positioned(
                    bottom: 2,
                    right: 12,
                    child: SizedBox(
                      width: 70,
                      child: Text(
                        count == 0
                            ? 'No logs'
                            : '$count log${count == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
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

// MiniProgressChart & computeProgression → shared/widgets/mini_progress_chart.dart

// ──────────────────────────────────────────────
// Quick Check — horizontally scrolling chips of top exercises
// ──────────────────────────────────────────────

class _QuickCheckEntry {
  final String id;
  final String name;
  final bool pinned;
  const _QuickCheckEntry(
      {required this.id, required this.name, required this.pinned});
}

class _QuickCheckBar extends ConsumerWidget {
  final List<WorkoutLog> logs;
  const _QuickCheckBar({required this.logs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final freq = <String, int>{};
    final names = <String, String>{};
    for (final log in logs) {
      freq[log.exerciseId] = (freq[log.exerciseId] ?? 0) + 1;
      names[log.exerciseId] = log.exerciseName;
    }
    // Pinned come first (in pin order), then the most-frequent exercises.
    final pinnedIds = ref.watch(pinnedQuickCheckProvider);
    final pinnedSet = pinnedIds.toSet();

    // Fallback names for pinned exercises the user never logged.
    final exerciseById = <String, Exercise>{
      for (final ex in kExerciseList) ex.id: ex,
    };

    final chips = <_QuickCheckEntry>[];
    for (final id in pinnedIds) {
      final name = names[id] ?? exerciseById[id]?.name;
      if (name == null) continue;
      chips.add(_QuickCheckEntry(id: id, name: name, pinned: true));
    }
    final top = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in top) {
      if (pinnedSet.contains(e.key)) continue;
      chips.add(_QuickCheckEntry(
          id: e.key, name: names[e.key] ?? '', pinned: false));
      if (chips.length >= 6) break;
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
            child: Text(
              'Quick Check',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final entry = chips[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExerciseDetailScreen(
                        exerciseId: entry.id,
                        exerciseName: entry.name,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (entry.pinned) ...[
                          Icon(Icons.push_pin,
                              size: 11, color: AppColors.accent),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          entry.name,
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Subcategory drill-down screen (for a single muscle group)
// ──────────────────────────────────────────────

class _SubcategoryHistoryScreen extends ConsumerStatefulWidget {
  final String categoryKey;
  final String categoryLabel;
  final List<WorkoutLog> logs;
  const _SubcategoryHistoryScreen({
    required this.categoryKey,
    required this.categoryLabel,
    required this.logs,
  });

  @override
  ConsumerState<_SubcategoryHistoryScreen> createState() =>
      _SubcategoryHistoryScreenState();
}

class _SubcategoryHistoryScreenState
    extends ConsumerState<_SubcategoryHistoryScreen> {
  final Set<String> _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final subcategories =
        kSubcategoriesByCategory[widget.categoryKey] ?? const <String>[];

    // Build exercise → {name, subcategory, count} from both built-in list
    // and any custom logs that don't resolve to a built-in exercise.
    final exerciseMeta = <String, Exercise>{
      for (final ex in kExerciseList)
        if (ex.category == widget.categoryKey) ex.id: ex,
    };

    // Count logs per exerciseId, gather subcategory, and also bucket the
    // full log list per subcategory so we can render a mini progression
    // chart for each subcategory card.
    final counts = <String, int>{};
    final displayName = <String, String>{};
    final exerciseSub = <String, String>{};
    final logsBySub = <String, List<WorkoutLog>>{};
    for (final log in widget.logs) {
      final meta = exerciseMeta[log.exerciseId];
      // Only include logs belonging to this category
      final logCategory = meta?.category ?? log.category;
      if (logCategory != widget.categoryKey) continue;
      counts[log.exerciseId] = (counts[log.exerciseId] ?? 0) + 1;
      displayName[log.exerciseId] = meta?.name ?? log.exerciseName;
      final sub =
          meta?.subcategory ?? (log.category == 'custom' ? 'custom' : '');
      exerciseSub[log.exerciseId] = sub;
      if (sub.isNotEmpty) {
        logsBySub.putIfAbsent(sub, () => []).add(log);
      }
    }
    final tint = ref.watch(displayAccentProvider);

    // Group exercise ids by subcategory
    final idsBySub = <String, List<String>>{};
    for (final entry in counts.entries) {
      final sub = exerciseSub[entry.key] ?? '';
      if (sub.isEmpty) continue;
      idsBySub.putIfAbsent(sub, () => []).add(entry.key);
    }
    // Sort ids in each bucket by count desc, then name
    for (final list in idsBySub.values) {
      list.sort((a, b) {
        final c = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
        if (c != 0) return c;
        return (displayName[a] ?? '').compareTo(displayName[b] ?? '');
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryLabel,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: subcategories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final sub = subcategories[i];
          final label = kSubcategoryLabels[sub] ?? sub;
          final ids = idsBySub[sub] ?? const <String>[];
          final isOpen = _expanded.contains(sub);
          final totalLogs =
              ids.fold<int>(0, (s, id) => s + (counts[id] ?? 0));

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() {
                    if (isOpen) {
                      _expanded.remove(sub);
                    } else {
                      _expanded.add(sub);
                    }
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                ids.isEmpty
                                    ? 'No workouts logged'
                                    : '${ids.length} exercise${ids.length == 1 ? '' : 's'}  ·  $totalLogs log${totalLogs == 1 ? '' : 's'}',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Mini progression chart for just this subcategory
                        SizedBox(
                          width: 72,
                          height: 34,
                          child: MiniProgressChart(
                            points: computeProgression(
                                logsBySub[sub] ?? const []),
                            color: tint,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          isOpen ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOpen && ids.isNotEmpty) ...[
                  Divider(height: 1, color: AppColors.divider),
                  ...ids.map((id) {
                    final name = displayName[id] ?? id;
                    final c = counts[id] ?? 0;
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseDetailScreen(
                            exerciseId: id,
                            exerciseName: name,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              '$c log${c == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.chevron_right,
                                color: AppColors.textSecondary, size: 18),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
