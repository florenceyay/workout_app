import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/providers/providers.dart';
import '../../shared/models/workout_log.dart';
import 'exercise_detail_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox();

    final logsStream = ref.watch(workoutServiceProvider).streamAllLogs(uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<WorkoutLog>>(
        stream: logsStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(child: Text('Error loading history.', style: TextStyle(color: AppColors.textSecondary)));
          }

          final allLogs = snap.data ?? [];

          if (allLogs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart, color: AppColors.textGhost, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'No workouts logged yet.\nLog your first session!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            );
          }

          // Derive top exercises by frequency
          final freq = <String, int>{};
          final exerciseNames = <String, String>{};
          for (final log in allLogs) {
            freq[log.exerciseId] = (freq[log.exerciseId] ?? 0) + 1;
            exerciseNames[log.exerciseId] = log.exerciseName;
          }
          final topExercises = freq.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final quickChips = topExercises.take(6).toList();

          // Group all logs by date
          final grouped = _groupByDate(allLogs);
          final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: dates.length + 1, // +1 for the header
            itemBuilder: (context, index) {
              if (index == 0) {
                // Header: quick check chips + section label
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick check chips
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Text('Quick Check',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                    ),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: quickChips.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final exerciseId = quickChips[i].key;
                          final name = exerciseNames[exerciseId] ?? '';
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExerciseDetailScreen(
                                  exerciseId: exerciseId,
                                  exerciseName: name,
                                ),
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                              ),
                              child: Text(name,
                                  style: TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14)),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.divider, height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: Text('All Sessions',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                    ),
                  ],
                );
              }

              final date = dates[index - 1];
              final dayLogs = grouped[date]!;
              return _DateGroup(
                date: date,
                logs: dayLogs,
                onTap: (log) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExerciseDetailScreen(
                      exerciseId: log.exerciseId,
                      exerciseName: log.exerciseName,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<WorkoutLog>> _groupByDate(List<WorkoutLog> logs) {
    final map = <String, List<WorkoutLog>>{};
    for (final log in logs) {
      final key = '${log.date.year}-${log.date.month.toString().padLeft(2, '0')}-${log.date.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(log);
    }
    return map;
  }
}

class _DateGroup extends StatelessWidget {
  final String date;
  final List<WorkoutLog> logs;
  final ValueChanged<WorkoutLog> onTap;

  const _DateGroup({required this.date, required this.logs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.parse(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            _formatDate(parsed),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
        ...logs.map((log) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SessionCard(log: log, onTap: () => onTap(log)),
            )),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) return 'Yesterday';
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _SessionCard extends StatelessWidget {
  final WorkoutLog log;
  final VoidCallback onTap;
  const _SessionCard({required this.log, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBodyweight = log.category == 'bodyweight';
    final topSet = log.sets.isEmpty ? null : log.sets.reduce((a, b) => a.weight > b.weight ? a : b);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(log.exerciseName,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      if (log.isPersonalRecord) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.prGold,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('PR',
                              style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isBodyweight
                        ? '${log.sets.length} sets · ${log.sets.map((s) => s.reps).join(' / ')} reps'
                        : topSet != null
                            ? '${_fmtW(topSet.weight)} kg × ${topSet.reps}  ·  ${log.sets.length} sets'
                            : '',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  String _fmtW(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
