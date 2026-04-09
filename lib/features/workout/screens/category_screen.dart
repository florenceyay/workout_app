import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/workout_log.dart';
import '../../shared/models/exercise.dart';
import 'exercise_list_screen.dart';
import 'subcategory_screen.dart';
import 'logging_screen.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  List<WorkoutLog> _recentLogs = [];
  int _weekStreak = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { if (mounted) setState(() => _loaded = true); return; }
    final svc = ref.read(workoutServiceProvider);
    final results = await Future.wait([
      svc.getRecentLogs(uid).catchError((_) => <WorkoutLog>[]),
      svc.getWeeklyStreak(uid).catchError((_) => 0),
    ]);
    if (mounted) setState(() {
      _recentLogs = results[0] as List<WorkoutLog>;
      _weekStreak = results[1] as int;
      _loaded = true;
    });
  }

  static const _categories = [
    {'key': 'arms',         'label': 'Arms',          'asset': 'assets/icons/arms.png'},
    {'key': 'back',         'label': 'Back',          'asset': 'assets/icons/back.png'},
    {'key': 'chest',        'label': 'Chest',         'asset': 'assets/icons/chest.png'},
    {'key': 'legs',         'label': 'Legs',          'asset': 'assets/icons/legs.png'},
    {'key': 'abs',          'label': 'Abs',           'asset': 'assets/icons/abs.png'},
    {'key': 'cardio',       'label': 'Cardio',        'asset': 'assets/icons/cardio.png'},
    {'key': 'calisthenics', 'label': 'Body-\nweight', 'asset': 'assets/icons/bodyweight.png'},
    {'key': 'custom',       'label': 'Custom',        'asset': 'assets/icons/custom.png'},
  ];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final logsStream = uid != null
        ? ref.watch(workoutServiceProvider).streamAllLogs(uid)
        : const Stream<List<WorkoutLog>>.empty();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Workout', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => _showProfileMenu(context),
          ),
        ],
      ),
      body: StreamBuilder<List<WorkoutLog>>(
        stream: logsStream,
        builder: (context, snap) {
          // Build category → set of logged dates
          // Look up category from exercise list using exerciseId for accuracy
          final allLogs = snap.data ?? [];
          final exerciseCategoryMap = <String, String>{
            for (final ex in kExerciseList) ex.id: ex.category,
          };
          final categoryDates = <String, Set<DateTime>>{};
          for (final log in allLogs) {
            // Prefer category from exercise list (in case log has stale/empty category)
            final category = exerciseCategoryMap[log.exerciseId] ?? log.category;
            if (category.isEmpty) continue;
            categoryDates.putIfAbsent(category, () => {});
            categoryDates[category]!.add(
              DateTime(log.date.year, log.date.month, log.date.day),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StreakCard(days: _weekStreak),
                const SizedBox(height: 20),

                if (_loaded && _recentLogs.isNotEmpty) ...[
                  Text('Quick Log', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentLogs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final log = _recentLogs[i];
                        return _QuickLogChip(
                          label: log.exerciseName,
                          onTap: () => _showLastSessionSheet(log),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                Text('Category', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    final key = cat['key'] as String;
                    return _CategoryTile(
                      label: cat['label'] as String,
                      asset: cat['asset'] as String,
                      tint: ref.watch(themeColorProvider),
                      loggedDates: categoryDates[key] ?? {},
                      onTap: () {
                        final hasSubcategories =
                            (kSubcategoriesByCategory[key]?.length ?? 0) > 1;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => hasSubcategories
                                ? SubcategoryScreen(category: key)
                                : ExerciseListScreen(initialCategory: key),
                          ),
                        ).then((_) => _loadData());
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLastSessionSheet(WorkoutLog log) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(log.exerciseName,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Text(_formatDate(log.date),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Last session', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ...log.sets.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final isBodyweight = log.category == 'bodyweight' || log.category == 'calisthenics';
              final weightStr = isBodyweight
                  ? ''
                  : '${s.weight % 1 == 0 ? s.weight.toStringAsFixed(0) : s.weight.toStringAsFixed(1)} kg  ×  ';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(width: 52, child: Text('Set ${i + 1}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                    Text('$weightStr${s.reps} reps',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _goToLogging(log.exerciseId, log.exerciseName, log.category);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Log Workout', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  void _goToLogging(String exerciseId, String exerciseName, String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoggingScreen(exerciseId: exerciseId, exerciseName: exerciseName, category: category),
      ),
    ).then((_) => _loadData());
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      isScrollControlled: true,
      builder: (_) => _SettingsSheet(ref: ref),
    );
  }
}

// ──────────────────────────────────────────────
// Category tile with mini dot calendar
// ──────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final String label;
  final String asset;
  final Color tint;
  final Set<DateTime> loggedDates;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.asset,
    required this.tint,
    required this.loggedDates,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lastLogged = loggedDates.isEmpty
        ? null
        : loggedDates.reduce((a, b) => a.isAfter(b) ? a : b);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset(
                  asset,
                  width: 40,
                  height: 40,
                  color: tint,
                  filterQuality: FilterQuality.medium,
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    label,
                    style: const TextStyle(
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
            Positioned(
              top: 8,
              right: 12,
              child: _MiniCalendar(loggedDates: loggedDates),
            ),
            Positioned(
              bottom: 2,
              right: 12,
              child: SizedBox(
                width: 70,
                child: Text(
                  lastLogged == null
                      ? 'No logs'
                      : 'Last logged:\n${_formatLastLogged(lastLogged)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastLogged(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayName = days[date.weekday == 7 ? 0 : date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName $monthName ${date.day}';
  }
}

// ──────────────────────────────────────────────
// Mini calendar showing current month
// ──────────────────────────────────────────────

class _MiniCalendar extends StatelessWidget {
  final Set<DateTime> loggedDates;
  const _MiniCalendar({required this.loggedDates});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final currentMonth = DateTime(today.year, today.month);
    final firstDay = currentMonth;
    final lastDay = DateTime(today.year, today.month + 1, 0);

    // Calculate starting position (0 = Monday, 6 = Sunday)
    final startWeekday = firstDay.weekday == 7 ? 0 : firstDay.weekday - 1;
    final totalDays = lastDay.day;
    final totalCells = ((startWeekday + totalDays + 6) ~/ 7) * 7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate((totalCells / 7).ceil(), (weekIndex) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(7, (dayInWeek) {
            final cellIndex = weekIndex * 7 + dayInWeek;
            final dayOfMonth = cellIndex - startWeekday + 1;
            final isCurrentMonth = dayOfMonth >= 1 && dayOfMonth <= totalDays;

            if (!isCurrentMonth) {
              return Padding(
                padding: const EdgeInsets.only(right: 3, bottom: 3),
                child: SizedBox(
                  width: 6,
                  height: 6,
                  child: Container(color: Colors.transparent),
                ),
              );
            }

            final day = DateTime(today.year, today.month, dayOfMonth);
            final isLogged = loggedDates.contains(day);
            final isToday = day.year == today.year &&
                day.month == today.month &&
                day.day == today.day;

            return Padding(
              padding: const EdgeInsets.only(right: 3, bottom: 3),
              child: Builder(
                builder: (ctx) {
                  // Outline color: white in dark theme, accent in light theme
                  final outlineColor = Theme.of(ctx).brightness == Brightness.dark
                      ? Colors.white
                      : AppColors.accent;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Logged dot (fill)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isLogged ? AppColors.accent : AppColors.divider,
                        ),
                      ),
                      // Today outline (ring)
                      if (isToday)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: outlineColor,
                              width: 1,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          }),
        );
      }),
    );
  }
}

// ──────────────────────────────────────────────
// Streak card
// ──────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final int days;
  const _StreakCard({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department, color: AppColors.accent, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$days ${days == 1 ? 'day' : 'days'} this week',
                  style: Theme.of(context).textTheme.titleMedium),
              Text('Keep it up!', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Quick log chip
// ──────────────────────────────────────────────

class _QuickLogChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickLogChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Text(label, style: TextStyle(
            color: AppColors.accent, fontWeight: FontWeight.w500, fontSize: 14)),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Settings sheet
// ──────────────────────────────────────────────

class _SettingsSheet extends ConsumerWidget {
  final WidgetRef ref;
  const _SettingsSheet({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitPref = ref.watch(unitPreferenceProvider);
    final distancePref = ref.watch(distanceUnitProvider);
    final themeColor = ref.watch(themeColorProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),

            // Weight unit toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Weight Unit', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        ref.read(unitPreferenceProvider.notifier).set('kg');
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: unitPref == 'kg' ? AppColors.accent : AppColors.divider,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('kg', style: TextStyle(
                          color: unitPref == 'kg' ? Colors.black : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        )),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        ref.read(unitPreferenceProvider.notifier).set('lb');
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: unitPref == 'lb' ? AppColors.accent : AppColors.divider,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('lb', style: TextStyle(
                          color: unitPref == 'lb' ? Colors.black : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        )),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Distance unit toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Distance Unit', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        ref.read(distanceUnitProvider.notifier).set('km');
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: distancePref == 'km' ? AppColors.accent : AppColors.divider,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('km', style: TextStyle(
                          color: distancePref == 'km' ? Colors.black : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        )),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        ref.read(distanceUnitProvider.notifier).set('mi');
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: distancePref == 'mi' ? AppColors.accent : AppColors.divider,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('mi', style: TextStyle(
                          color: distancePref == 'mi' ? Colors.black : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        )),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 24),

            // Theme color picker
            const Text('Theme Color', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: themeColors.map((color) {
                final isSelected = color == themeColor;
                return GestureDetector(
                  onTap: () {
                    ref.read(themeColorProvider.notifier).set(color);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: AppColors.textPrimary, width: 3) : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 24),

            // Sign out
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.textSecondary),
              title: const Text('Sign out'),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authServiceProvider).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}
