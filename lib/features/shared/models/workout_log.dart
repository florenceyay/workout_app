import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutSet {
  final double weight;
  final int reps;
  // Cardio fields — distance in km, duration in minutes (decimal allowed).
  final double distance;
  final double durationMinutes;

  const WorkoutSet({
    required this.weight,
    required this.reps,
    this.distance = 0,
    this.durationMinutes = 0,
  });

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      reps: (map['reps'] as num?)?.toInt() ?? 0,
      distance: (map['distance'] as num?)?.toDouble() ?? 0,
      durationMinutes: (map['durationMinutes'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'weight': weight,
        'reps': reps,
        if (distance > 0) 'distance': distance,
        if (durationMinutes > 0) 'durationMinutes': durationMinutes,
      };
}

class WorkoutLog {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final String category;
  final DateTime date;
  final List<WorkoutSet> sets;
  final double totalVolume;
  final bool isPersonalRecord;

  const WorkoutLog({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.category,
    required this.date,
    required this.sets,
    required this.totalVolume,
    required this.isPersonalRecord,
  });

  double get maxWeight => sets.isEmpty ? 0 : sets.map((s) => s.weight).reduce((a, b) => a > b ? a : b);

  factory WorkoutLog.fromMap(Map<String, dynamic> map, String id) {
    final rawSets = map['sets'] as List<dynamic>? ?? [];
    final sets = rawSets.map((s) => WorkoutSet.fromMap(s as Map<String, dynamic>)).toList();
    return WorkoutLog(
      id: id,
      exerciseId: map['exerciseId'] as String? ?? '',
      exerciseName: map['exerciseName'] as String? ?? '',
      category: map['category'] as String? ?? '',
      date: (map['date'] as Timestamp).toDate(),
      sets: sets,
      totalVolume: (map['totalVolume'] as num?)?.toDouble() ?? 0,
      isPersonalRecord: map['isPersonalRecord'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'category': category,
        'date': Timestamp.fromDate(date),
        'sets': sets.map((s) => s.toMap()).toList(),
        'totalVolume': totalVolume,
        'isPersonalRecord': isPersonalRecord,
      };

  static double computeVolume(List<WorkoutSet> sets) {
    return sets.fold(0, (sum, s) => sum + s.weight * s.reps);
  }

  // Merge logs that are for the same exercise on the same calendar day into
  // a single combined log. Sets are concatenated in chronological order
  // (earliest time first), total volume is summed, and PR flag is OR-ed.
  // The merged log's date is taken from the earliest log of the day so the
  // session "starts" at the first time the user logged that day.
  static List<WorkoutLog> mergeSameDayLogs(List<WorkoutLog> logs) {
    if (logs.isEmpty) return logs;
    // Group by (exerciseId, y-m-d)
    final groups = <String, List<WorkoutLog>>{};
    for (final log in logs) {
      final dayKey =
          '${log.exerciseId}|${log.date.year}-${log.date.month}-${log.date.day}';
      groups.putIfAbsent(dayKey, () => []).add(log);
    }
    final merged = <WorkoutLog>[];
    for (final group in groups.values) {
      if (group.length == 1) {
        merged.add(group.first);
        continue;
      }
      // Sort chronologically (earliest first) so sets read in order.
      group.sort((a, b) => a.date.compareTo(b.date));
      final first = group.first;
      final allSets = <WorkoutSet>[
        for (final g in group) ...g.sets,
      ];
      final totalVolume =
          group.fold<double>(0, (s, g) => s + g.totalVolume);
      final anyPR = group.any((g) => g.isPersonalRecord);
      merged.add(WorkoutLog(
        id: first.id,
        exerciseId: first.exerciseId,
        exerciseName: first.exerciseName,
        category: first.category,
        date: first.date,
        sets: allSets,
        totalVolume: totalVolume,
        isPersonalRecord: anyPR,
      ));
    }
    // Preserve original ordering (newest first) by sorting descending by date.
    merged.sort((a, b) => b.date.compareTo(a.date));
    return merged;
  }
}
