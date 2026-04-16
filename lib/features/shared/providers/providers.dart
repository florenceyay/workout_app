import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import '../services/auth_service.dart';
import '../services/workout_service.dart';
import '../theme/app_theme.dart';

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
const _kLightThemeColorKey = 'pref_light_theme_color';
const _kThemeBrightnessKey = 'pref_theme_brightness'; // 'dark' | 'light'

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
  final String key;
  _ColorPrefNotifier(this.prefs, this.key, int fallback)
      : super(Color(prefs.getInt(key) ?? fallback));

  void set(Color value) {
    state = value;
    prefs.setInt(key, value.toARGB32());
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

/// Dark-mode accent colour preference.
final themeColorProvider =
    StateNotifierProvider<_ColorPrefNotifier, Color>((ref) {
  return _ColorPrefNotifier(
      ref.watch(sharedPreferencesProvider), _kThemeColorKey, 0xFF40C4FF);
});

/// Light-mode accent colour preference (defaults to Deep Navy).
final lightThemeColorProvider =
    StateNotifierProvider<_ColorPrefNotifier, Color>((ref) {
  return _ColorPrefNotifier(
      ref.watch(sharedPreferencesProvider), _kLightThemeColorKey, 0xFF1B2A4A);
});

// Light / dark mode. Defaults to dark.
class _BrightnessPrefNotifier extends StateNotifier<Brightness> {
  final SharedPreferences prefs;
  _BrightnessPrefNotifier(this.prefs)
      : super(prefs.getString(_kThemeBrightnessKey) == 'light'
            ? Brightness.light
            : Brightness.dark) {
    // Ensure the global palette reflects the initial brightness before
    // any widget reads AppColors.*
    AppColors.applyBrightness(state);
  }

  void set(Brightness b) {
    // Flip the global palette BEFORE emitting state, so that any widget
    // rebuilt by this notification reads the new AppColors values
    // synchronously — no 1-frame mismatch.
    AppColors.applyBrightness(b);
    state = b;
    prefs.setString(
        _kThemeBrightnessKey, b == Brightness.light ? 'light' : 'dark');
  }
}

final themeBrightnessProvider =
    StateNotifierProvider<_BrightnessPrefNotifier, Brightness>((ref) {
  return _BrightnessPrefNotifier(ref.watch(sharedPreferencesProvider));
});

/// The accent color to use when actually painting widgets. Returns the
/// dark-mode palette colour or the light-mode palette colour depending on
/// the current brightness. Each mode stores its own preference so
/// switching back preserves the user's earlier choice.
final displayAccentProvider = Provider<Color>((ref) {
  final brightness = ref.watch(themeBrightnessProvider);
  if (brightness == Brightness.light) {
    return ref.watch(lightThemeColorProvider);
  }
  return ref.watch(themeColorProvider);
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
    String? trackingType,
  }) async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final ex = Exercise(
      id: id,
      name: name,
      category: category,
      subcategory: subcategory,
      note: note,
      isCustom: true,
      trackingType: trackingType,
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

// ──────────────────────────────────────────────
// Pinned exercise ids for Quick Log / Quick Check bars
// ──────────────────────────────────────────────
//
// Stored as a JSON-encoded list of exercise ids so order is preserved
// (pin order = order they appear in the bar).

class _PinnedIdsNotifier extends StateNotifier<List<String>> {
  final SharedPreferences prefs;
  final String key;
  _PinnedIdsNotifier(this.prefs, this.key) : super(_load(prefs, key));

  static List<String> _load(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e as String).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save() async {
    await prefs.setString(key, jsonEncode(state));
  }

  bool isPinned(String id) => state.contains(id);

  Future<void> toggle(String id) async {
    if (state.contains(id)) {
      state = state.where((e) => e != id).toList();
    } else {
      state = [...state, id];
    }
    await _save();
  }

  Future<void> unpin(String id) async {
    if (!state.contains(id)) return;
    state = state.where((e) => e != id).toList();
    await _save();
  }
}

const _kPinnedQuickLogKey = 'pinned_quick_log';
const _kPinnedQuickCheckKey = 'pinned_quick_check';

final pinnedQuickLogProvider =
    StateNotifierProvider<_PinnedIdsNotifier, List<String>>((ref) {
  return _PinnedIdsNotifier(
      ref.watch(sharedPreferencesProvider), _kPinnedQuickLogKey);
});

final pinnedQuickCheckProvider =
    StateNotifierProvider<_PinnedIdsNotifier, List<String>>((ref) {
  return _PinnedIdsNotifier(
      ref.watch(sharedPreferencesProvider), _kPinnedQuickCheckKey);
});
