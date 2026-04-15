class Exercise {
  final String id;
  final String name;
  final String category;
  final String subcategory;
  final String note;
  final bool isCustom;
  // Tracking mode, one of:
  //   'strength'   — weight × reps (default for weighted lifts)
  //   'bodyweight' — reps only (push-ups, pull-ups, plank progressions with reps)
  //   'cardio'     — distance + duration (running, cycling, rowing, treadmill)
  //   'time'       — duration only (plank, wall sit, jump rope, stair climber)
  //   'laps_time'  — pool lengths + duration (swimming)
  final String? trackingType;
  // Whether the plate calculator is meaningful for this exercise. Only true for
  // barbell / plate-loaded compounds where the user needs to figure out which
  // plates to put on each side.
  final bool plateable;

  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.subcategory,
    this.note = '',
    this.isCustom = false,
    this.trackingType,
    this.plateable = false,
  });

  factory Exercise.fromMap(Map<String, dynamic> map, String id) {
    return Exercise(
      id: id,
      name: map['name'] as String,
      category: map['category'] as String,
      subcategory: map['subcategory'] as String? ?? '',
      note: map['note'] as String? ?? '',
      isCustom: map['isCustom'] as bool? ?? false,
      trackingType: map['trackingType'] as String?,
      plateable: map['plateable'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'subcategory': subcategory,
        if (note.isNotEmpty) 'note': note,
        if (isCustom) 'isCustom': true,
        if (trackingType != null) 'trackingType': trackingType,
        if (plateable) 'plateable': true,
      };
}

// Built-in exercise catalog. Each entry declares how the user tracks it and
// whether a plate-math calculator is useful for it.
const List<Map<String, dynamic>> kDefaultExercises = [
  // ── Arms ────────────────────────────────────────────────────────────────
  // Biceps
  {'name': 'Bicep Curls', 'category': 'arms', 'subcategory': 'biceps', 'tracking': 'strength'},
  {'name': 'Hammer Curls', 'category': 'arms', 'subcategory': 'biceps', 'tracking': 'strength'},
  {'name': 'Preacher Curls', 'category': 'arms', 'subcategory': 'biceps', 'tracking': 'strength'},
  {'name': 'Cable Curls', 'category': 'arms', 'subcategory': 'biceps', 'tracking': 'strength'},
  {'name': 'Reverse Curls', 'category': 'arms', 'subcategory': 'biceps', 'tracking': 'strength'},
  // Triceps
  {'name': 'Tricep Pushdown', 'category': 'arms', 'subcategory': 'triceps', 'tracking': 'strength'},
  {'name': 'Skull Crushers', 'category': 'arms', 'subcategory': 'triceps', 'tracking': 'strength', 'plateable': true},
  {'name': 'Overhead Tricep Extension', 'category': 'arms', 'subcategory': 'triceps', 'tracking': 'strength'},
  {'name': 'Tricep Kickbacks', 'category': 'arms', 'subcategory': 'triceps', 'tracking': 'strength'},
  // Shoulders
  {'name': 'Lateral Raises', 'category': 'arms', 'subcategory': 'shoulders', 'tracking': 'strength'},
  {'name': 'Overhead Press', 'category': 'arms', 'subcategory': 'shoulders', 'tracking': 'strength', 'plateable': true},
  {'name': 'DB Shoulder Press', 'category': 'arms', 'subcategory': 'shoulders', 'tracking': 'strength'},
  {'name': 'Face Pulls', 'category': 'arms', 'subcategory': 'shoulders', 'tracking': 'strength'},

  // ── Back ────────────────────────────────────────────────────────────────
  // Lats
  {'name': 'Lat Pulldown', 'category': 'back', 'subcategory': 'lats', 'tracking': 'strength'},
  {'name': 'Cable Pullover', 'category': 'back', 'subcategory': 'lats', 'tracking': 'strength'},
  {'name': 'Straight Arm Pulldown', 'category': 'back', 'subcategory': 'lats', 'tracking': 'strength'},
  // Upper Back
  {'name': 'Barbell Row', 'category': 'back', 'subcategory': 'upper back', 'tracking': 'strength', 'plateable': true},
  {'name': 'Seated Cable Row', 'category': 'back', 'subcategory': 'upper back', 'tracking': 'strength'},
  {'name': 'T-Bar Row', 'category': 'back', 'subcategory': 'upper back', 'tracking': 'strength', 'plateable': true},
  {'name': 'Single Arm Row', 'category': 'back', 'subcategory': 'upper back', 'tracking': 'strength'},
  // Lower Back
  {'name': 'Deadlift', 'category': 'back', 'subcategory': 'lower back', 'tracking': 'strength', 'plateable': true},
  {'name': 'Rack Pulls', 'category': 'back', 'subcategory': 'lower back', 'tracking': 'strength', 'plateable': true},

  // ── Chest ───────────────────────────────────────────────────────────────
  {'name': 'Incline Bench Press', 'category': 'chest', 'subcategory': 'upper chest', 'tracking': 'strength', 'plateable': true},
  {'name': 'Incline DB Press', 'category': 'chest', 'subcategory': 'upper chest', 'tracking': 'strength'},
  {'name': 'Bench Press', 'category': 'chest', 'subcategory': 'mid chest', 'tracking': 'strength', 'plateable': true},
  {'name': 'DB Press', 'category': 'chest', 'subcategory': 'mid chest', 'tracking': 'strength'},
  {'name': 'Chest Flyes', 'category': 'chest', 'subcategory': 'mid chest', 'tracking': 'strength'},
  {'name': 'Cable Fly', 'category': 'chest', 'subcategory': 'mid chest', 'tracking': 'strength'},
  {'name': 'Pec Deck', 'category': 'chest', 'subcategory': 'mid chest', 'tracking': 'strength'},
  {'name': 'Decline Bench Press', 'category': 'chest', 'subcategory': 'lower chest', 'tracking': 'strength', 'plateable': true},

  // ── Legs ────────────────────────────────────────────────────────────────
  // Quads
  {'name': 'Squat', 'category': 'legs', 'subcategory': 'quads', 'tracking': 'strength', 'plateable': true},
  {'name': 'Leg Press', 'category': 'legs', 'subcategory': 'quads', 'tracking': 'strength', 'plateable': true},
  {'name': 'Leg Extension', 'category': 'legs', 'subcategory': 'quads', 'tracking': 'strength'},
  {'name': 'Hack Squat', 'category': 'legs', 'subcategory': 'quads', 'tracking': 'strength', 'plateable': true},
  {'name': 'Lunges', 'category': 'legs', 'subcategory': 'quads', 'tracking': 'strength'},
  {'name': 'Bulgarian Split Squat', 'category': 'legs', 'subcategory': 'quads', 'tracking': 'strength'},
  // Hamstrings
  {'name': 'Romanian Deadlift', 'category': 'legs', 'subcategory': 'hamstrings', 'tracking': 'strength', 'plateable': true},
  {'name': 'Leg Curl', 'category': 'legs', 'subcategory': 'hamstrings', 'tracking': 'strength'},
  // Glutes
  {'name': 'Hip Thrust', 'category': 'legs', 'subcategory': 'glutes', 'tracking': 'strength', 'plateable': true},
  {'name': 'Sumo Squat', 'category': 'legs', 'subcategory': 'glutes', 'tracking': 'strength', 'plateable': true},
  // Calves
  {'name': 'Calf Raises', 'category': 'legs', 'subcategory': 'calves', 'tracking': 'strength'},

  // ── Abs ─────────────────────────────────────────────────────────────────
  // Upper abs
  {'name': 'Crunches', 'category': 'abs', 'subcategory': 'upper abs', 'tracking': 'bodyweight'},
  {'name': 'Cable Crunch', 'category': 'abs', 'subcategory': 'upper abs', 'tracking': 'strength'},
  {'name': 'Bicycle Crunches', 'category': 'abs', 'subcategory': 'upper abs', 'tracking': 'bodyweight'},
  // Lower abs
  {'name': 'Leg Raises', 'category': 'abs', 'subcategory': 'lower abs', 'tracking': 'bodyweight'},
  {'name': 'Hanging Knee Raises', 'category': 'abs', 'subcategory': 'lower abs', 'tracking': 'bodyweight'},
  // Obliques
  {'name': 'Side Plank', 'category': 'abs', 'subcategory': 'obliques', 'tracking': 'time'},
  {'name': 'Russian Twists', 'category': 'abs', 'subcategory': 'obliques', 'tracking': 'bodyweight'},
  {'name': 'Woodchoppers', 'category': 'abs', 'subcategory': 'obliques', 'tracking': 'strength'},
  {'name': 'Oblique Crunches', 'category': 'abs', 'subcategory': 'obliques', 'tracking': 'bodyweight'},
  {'name': 'Hanging Side Knee Raises', 'category': 'abs', 'subcategory': 'obliques', 'tracking': 'bodyweight'},
  // Core
  {'name': 'Plank', 'category': 'abs', 'subcategory': 'core', 'tracking': 'time'},
  {'name': 'Ab Wheel', 'category': 'abs', 'subcategory': 'core', 'tracking': 'bodyweight'},

  // ── Cardio ──────────────────────────────────────────────────────────────
  // Machines
  {'name': 'Treadmill', 'category': 'cardio', 'subcategory': 'machines', 'tracking': 'cardio'},
  {'name': 'Rowing', 'category': 'cardio', 'subcategory': 'machines', 'tracking': 'cardio'},
  {'name': 'Stair Climber', 'category': 'cardio', 'subcategory': 'machines', 'tracking': 'time'},
  {'name': 'Elliptical', 'category': 'cardio', 'subcategory': 'machines', 'tracking': 'cardio'},
  // Outdoor
  {'name': 'Running', 'category': 'cardio', 'subcategory': 'outdoor', 'tracking': 'cardio'},
  {'name': 'Cycling', 'category': 'cardio', 'subcategory': 'outdoor', 'tracking': 'cardio'},
  {'name': 'Swimming', 'category': 'cardio', 'subcategory': 'outdoor', 'tracking': 'laps_time'},
  // Other
  {'name': 'Jump Rope', 'category': 'cardio', 'subcategory': 'other', 'tracking': 'time'},

  // ── Calisthenics ────────────────────────────────────────────────────────
  // Push
  {'name': 'Push-ups', 'category': 'calisthenics', 'subcategory': 'push', 'tracking': 'bodyweight'},
  {'name': 'Dips', 'category': 'calisthenics', 'subcategory': 'push', 'tracking': 'bodyweight'},
  {'name': 'Handstand Push-ups', 'category': 'calisthenics', 'subcategory': 'push', 'tracking': 'bodyweight'},
  // Pull
  {'name': 'Pull-ups', 'category': 'calisthenics', 'subcategory': 'pull', 'tracking': 'bodyweight'},
  {'name': 'Muscle-ups', 'category': 'calisthenics', 'subcategory': 'pull', 'tracking': 'bodyweight'},
  // Legs
  {'name': 'Bodyweight Squats', 'category': 'calisthenics', 'subcategory': 'legs', 'tracking': 'bodyweight'},
  {'name': 'Pistol Squats', 'category': 'calisthenics', 'subcategory': 'legs', 'tracking': 'bodyweight'},
  // Core
  {'name': 'Sit-ups', 'category': 'calisthenics', 'subcategory': 'core', 'tracking': 'bodyweight'},
  {'name': 'Burpees', 'category': 'calisthenics', 'subcategory': 'core', 'tracking': 'bodyweight'},
  {'name': 'Mountain Climbers', 'category': 'calisthenics', 'subcategory': 'core', 'tracking': 'time'},

  // ── Custom (user-defined placeholder) ───────────────────────────────────
  {'name': 'Custom Exercise', 'category': 'custom', 'subcategory': 'custom', 'tracking': 'strength'},
];

// Pre-built Exercise list with stable IDs (name-derived slug).
final List<Exercise> kExerciseList = kDefaultExercises.map((e) {
  final name = e['name']! as String;
  final id = name.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  return Exercise(
    id: id,
    name: name,
    category: e['category']! as String,
    subcategory: e['subcategory']! as String,
    trackingType: e['tracking'] as String?,
    plateable: (e['plateable'] as bool?) ?? false,
  );
}).toList()
  ..sort((a, b) => a.name.compareTo(b.name));

// Subcategory labels and order per main category
const Map<String, List<String>> kSubcategoriesByCategory = {
  'arms': ['biceps', 'triceps', 'shoulders'],
  'back': ['lats', 'upper back', 'lower back'],
  'chest': ['upper chest', 'mid chest', 'lower chest'],
  'legs': ['quads', 'hamstrings', 'glutes', 'calves'],
  'abs': ['upper abs', 'lower abs', 'obliques', 'core'],
  'cardio': ['machines', 'outdoor', 'other'],
  'calisthenics': ['push', 'pull', 'legs', 'core'],
  'custom': ['custom'],
};

const Map<String, String> kSubcategoryLabels = {
  'biceps': 'Biceps',
  'triceps': 'Triceps',
  'shoulders': 'Shoulders',
  'lats': 'Lats',
  'upper back': 'Upper Back',
  'lower back': 'Lower Back',
  'upper chest': 'Upper Chest',
  'mid chest': 'Mid Chest',
  'lower chest': 'Lower Chest',
  'quads': 'Quads',
  'hamstrings': 'Hamstrings',
  'glutes': 'Glutes',
  'calves': 'Calves',
  'upper abs': 'Upper Abs',
  'lower abs': 'Lower Abs',
  'obliques': 'Obliques',
  'core': 'Core',
  'machines': 'Machines',
  'outdoor': 'Outdoor',
  'other': 'Other',
  'push': 'Push',
  'pull': 'Pull',
  'legs': 'Legs',
  'custom': 'Custom',
};

const Map<String, String> kCategoryLabels = {
  'arms': 'Arms',
  'back': 'Back',
  'chest': 'Chest',
  'legs': 'Legs',
  'abs': 'Abs',
  'cardio': 'Cardio',
  'calisthenics': 'Calisthenics',
  'custom': 'Custom',
};
