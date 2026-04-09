import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import '../services/auth_service.dart';
import '../services/workout_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final workoutServiceProvider = Provider<WorkoutService>((ref) => WorkoutService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Overridden in main() with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

const _kUnitPrefKey = 'pref_weight_unit';
const _kDistanceUnitKey = 'pref_distance_unit';
const _kThemeColorKey = 'pref_theme_color';

class _StringPrefNotifier extends StateNotifier<String> {
  final SharedPreferences prefs;
  final String key;
  _StringPrefNotifier(this.prefs, this.key, String fallback)
      : super(prefs.getString(key) ?? fallback);

  void set(String value) {
    state = value;
    prefs.setString(key, value);
  }
}

class _ColorPrefNotifier extends StateNotifier<Color> {
  final SharedPreferences prefs;
  _ColorPrefNotifier(this.prefs)
      : super(Color(prefs.getInt(_kThemeColorKey) ?? 0xFF40C4FF));

  void set(Color value) {
    state = value;
    prefs.setInt(_kThemeColorKey, value.toARGB32());
  }
}

final unitPreferenceProvider =
    StateNotifierProvider<_StringPrefNotifier, String>((ref) {
  return _StringPrefNotifier(
      ref.watch(sharedPreferencesProvider), _kUnitPrefKey, 'kg');
});

final distanceUnitProvider =
    StateNotifierProvider<_StringPrefNotifier, String>((ref) {
  return _StringPrefNotifier(
      ref.watch(sharedPreferencesProvider), _kDistanceUnitKey, 'km');
});

final themeColorProvider =
    StateNotifierProvider<_ColorPrefNotifier, Color>((ref) {
  return _ColorPrefNotifier(ref.watch(sharedPreferencesProvider));
});

// ──────────────────────────────────────────────
// User-defined custom exercises
// ──────────────────────────────────────────────

const _kCustomExercisesKey = 'custom_exercises';

class CustomExercisesNotifier extends StateNotifier<List<Exercise>> {
  final SharedPreferences prefs;
  CustomExercisesNotifier(this.prefs) : super(_load(prefs));

  static List<Exercise> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_kCustomExercisesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        return Exercise.fromMap(map, map['id'] as String);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save() async {
    final encoded = jsonEncode(state.map((e) => e.toMap()).toList());
    await prefs.setString(_kCustomExercisesKey, encoded);
  }

  Future<Exercise> add({
    required String name,
    required String category,
    required String subcategory,
    String note = '',
  }) async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final ex = Exercise(
      id: id,
      name: name,
      category: category,
      subcategory: subcategory,
      note: note,
      isCustom: true,
    );
    state = [...state, ex];
    await _save();
    return ex;
  }

  Future<void> remove(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _save();
  }
}

final customExercisesProvider =
    StateNotifierProvider<CustomExercisesNotifier, List<Exercise>>((ref) {
  return CustomExercisesNotifier(ref.watch(sharedPreferencesProvider));
});
