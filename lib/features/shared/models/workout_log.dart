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
}
