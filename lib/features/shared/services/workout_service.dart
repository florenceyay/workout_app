import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout_log.dart';
import '../models/exercise.dart';

class WorkoutService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _logsRef(String uid) =>
      _db.collection('users').doc(uid).collection('logs');

  // Seed exercises on first login
  Future<void> seedExercisesIfNeeded() async {
    final existing = await _db.collection('exercises').limit(1).get();
    if (existing.docs.isNotEmpty) return;
    final batch = _db.batch();
    for (final ex in kDefaultExercises) {
      final ref = _db.collection('exercises').doc();
      batch.set(ref, ex);
    }
    await batch.commit();
  }

  // Get all exercises
  Future<List<Exercise>> getExercises() async {
    final snap = await _db.collection('exercises').orderBy('name').get();
    return snap.docs.map((d) => Exercise.fromMap(d.data(), d.id)).toList();
  }

  // Save a workout log
  Future<void> saveLog(String uid, WorkoutLog log) async {
    await _logsRef(uid).doc(log.id.isEmpty ? null : log.id).set(log.toMap());
  }

  // Get most recent log for an exercise
  Future<WorkoutLog?> getLastLog(String uid, String exerciseId) async {
    final snap = await _logsRef(uid)
        .where('exerciseId', isEqualTo: exerciseId)
        .get();
    if (snap.docs.isEmpty) return null;
    final logs = snap.docs.map((d) => WorkoutLog.fromMap(d.data(), d.id)).toList();
    logs.sort((a, b) => b.date.compareTo(a.date));
    return logs.first;
  }

  // Get the most recent [limit] merged sessions for an exercise. Multiple
  // logs on the same day are combined into a single session (sets
  // concatenated), so this returns one entry per distinct day.
  Future<List<WorkoutLog>> getRecentSessions(String uid, String exerciseId,
      {int limit = 3}) async {
    final snap = await _logsRef(uid)
        .where('exerciseId', isEqualTo: exerciseId)
        .get();
    if (snap.docs.isEmpty) return const [];
    final logs =
        snap.docs.map((d) => WorkoutLog.fromMap(d.data(), d.id)).toList();
    final merged = WorkoutLog.mergeSameDayLogs(logs)
      ..sort((a, b) => b.date.compareTo(a.date));
    return merged.take(limit).toList();
  }

  // Check if a new log is a PR (higher max weight than all previous)
  Future<bool> isPersonalRecord(String uid, String exerciseId, double maxWeight) async {
    final snap = await _logsRef(uid)
        .where('exerciseId', isEqualTo: exerciseId)
        .get();
    if (snap.docs.isEmpty) return true;
    final allLogs = snap.docs.map((d) => WorkoutLog.fromMap(d.data(), d.id)).toList();
    final previousBest = allLogs.map((l) => l.maxWeight).fold(0.0, (a, b) => a > b ? a : b);
    return maxWeight > previousBest;
  }

  // Stream all logs for history
  Stream<List<WorkoutLog>> streamAllLogs(String uid) {
    return _logsRef(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => WorkoutLog.fromMap(d.data(), d.id)).toList());
  }

  // Stream logs for a specific exercise (for chart)
  Stream<List<WorkoutLog>> streamExerciseLogs(String uid, String exerciseId) {
    return _logsRef(uid)
        .where('exerciseId', isEqualTo: exerciseId)
        .snapshots()
        .map((snap) {
          final logs = snap.docs.map((d) => WorkoutLog.fromMap(d.data(), d.id)).toList();
          logs.sort((a, b) => a.date.compareTo(b.date));
          return logs;
        });
  }

  // Get recent logged exercises (for Quick Log) - up to 7 unique
  Future<List<WorkoutLog>> getRecentLogs(String uid) async {
    final snap = await _logsRef(uid)
        .orderBy('date', descending: true)
        .limit(30)
        .get();
    final logs = snap.docs.map((d) => WorkoutLog.fromMap(d.data(), d.id)).toList();
    // Deduplicate by exerciseId, keeping only most recent per exercise
    final seen = <String>{};
    final result = <WorkoutLog>[];
    for (final log in logs) {
      if (!seen.contains(log.exerciseId)) {
        seen.add(log.exerciseId);
        result.add(log);
        if (result.length >= 7) break;
      }
    }
    return result;
  }

  // Count distinct workout days this week
  Future<int> getWeeklyStreak(String uid) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartMidnight = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final snap = await _logsRef(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStartMidnight))
        .get();
    final days = <String>{};
    for (final doc in snap.docs) {
      final log = WorkoutLog.fromMap(doc.data(), doc.id);
      days.add('${log.date.year}-${log.date.month}-${log.date.day}');
    }
    return days.length;
  }
}
