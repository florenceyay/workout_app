class Exercise {
  final String id;
  final String name;
  final String category;
  final String subcategory;
  final String note;
  final bool isCustom;
  final String? trackingType; // 'strength', 'cardio', or null

  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.subcategory,
    this.note = '',
    this.isCustom = false,
    this.trackingType,
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
      };
}

const List<Map<String, String>> kDefaultExercises = [
  // Arms - Biceps
  {'name': 'Bicep Curls', 'category': 'arms', 'subcategory': 'biceps'},
  {'name': 'Hammer Curls', 'category': 'arms', 'subcategory': 'biceps'},
  {'name': 'Preacher Curls', 'category': 'arms', 'subcategory': 'biceps'},
  {'name': 'Cable Curls', 'category': 'arms', 'subcategory': 'biceps'},
  {'name': 'Reverse Curls', 'category': 'arms', 'subcategory': 'biceps'},
  // Arms - Triceps
  {'name': 'Tricep Pushdown', 'category': 'arms', 'subcategory': 'triceps'},
  {'name': 'Skull Crushers', 'category': 'arms', 'subcategory': 'triceps'},
  {'name': 'Overhead Tricep Extension', 'category': 'arms', 'subcategory': 'triceps'},
  {'name': 'Tricep Kickbacks', 'category': 'arms', 'subcategory': 'triceps'},
  // Arms - Shoulders
  {'name': 'Lateral Raises', 'category': 'arms', 'subcategory': 'shoulders'},
  {'name': 'Overhead Press', 'category': 'arms', 'subcategory': 'shoulders'},
  {'name': 'DB Shoulder Press', 'category': 'arms', 'subcategory': 'shoulders'},
  {'name': 'Face Pulls', 'category': 'arms', 'subcategory': 'shoulders'},

  // Back - Lats
  {'name': 'Lat Pulldown', 'category': 'back', 'subcategory': 'lats'},
  {'name': 'Cable Pullover', 'category': 'back', 'subcategory': 'lats'},
  {'name': 'Straight Arm Pulldown', 'category': 'back', 'subcategory': 'lats'},
  // Back - Upper Back
  {'name': 'Barbell Row', 'category': 'back', 'subcategory': 'upper back'},
  {'name': 'Seated Cable Row', 'category': 'back', 'subcategory': 'upper back'},
  {'name': 'T-Bar Row', 'category': 'back', 'subcategory': 'upper back'},
  {'name': 'Single Arm Row', 'category': 'back', 'subcategory': 'upper back'},
  // Back - Lower Back
  {'name': 'Deadlift', 'category': 'back', 'subcategory': 'lower back'},
  {'name': 'Rack Pulls', 'category': 'back', 'subcategory': 'lower back'},

  // Chest - Upper
  {'name': 'Incline Bench Press', 'category': 'chest', 'subcategory': 'upper chest'},
  {'name': 'Incline DB Press', 'category': 'chest', 'subcategory': 'upper chest'},
  // Chest - Mid
  {'name': 'Bench Press', 'category': 'chest', 'subcategory': 'mid chest'},
  {'name': 'DB Press', 'category': 'chest', 'subcategory': 'mid chest'},
  {'name': 'Chest Flyes', 'category': 'chest', 'subcategory': 'mid chest'},
  {'name': 'Cable Fly', 'category': 'chest', 'subcategory': 'mid chest'},
  {'name': 'Pec Deck', 'category': 'chest', 'subcategory': 'mid chest'},
  // Chest - Lower
  {'name': 'Decline Bench Press', 'category': 'chest', 'subcategory': 'lower chest'},

  // Legs - Quads
  {'name': 'Squat', 'category': 'legs', 'subcategory': 'quads'},
  {'name': 'Leg Press', 'category': 'legs', 'subcategory': 'quads'},
  {'name': 'Leg Extension', 'category': 'legs', 'subcategory': 'quads'},
  {'name': 'Hack Squat', 'category': 'legs', 'subcategory': 'quads'},
  {'name': 'Lunges', 'category': 'legs', 'subcategory': 'quads'},
  {'name': 'Bulgarian Split Squat', 'category': 'legs', 'subcategory': 'quads'},
  // Legs - Hamstrings
  {'name': 'Romanian Deadlift', 'category': 'legs', 'subcategory': 'hamstrings'},
  {'name': 'Leg Curl', 'category': 'legs', 'subcategory': 'hamstrings'},
  // Legs - Glutes
  {'name': 'Hip Thrust', 'category': 'legs', 'subcategory': 'glutes'},
  {'name': 'Sumo Squat', 'category': 'legs', 'subcategory': 'glutes'},
  // Legs - Calves
  {'name': 'Calf Raises', 'category': 'legs', 'subcategory': 'calves'},

  // Abs - Upper
  {'name': 'Crunches', 'category': 'abs', 'subcategory': 'upper abs'},
  {'name': 'Cable Crunch', 'category': 'abs', 'subcategory': 'upper abs'},
  {'name': 'Bicycle Crunches', 'category': 'abs', 'subcategory': 'upper abs'},
  // Abs - Lower
  {'name': 'Leg Raises', 'category': 'abs', 'subcategory': 'lower abs'},
  {'name': 'Hanging Knee Raises', 'category': 'abs', 'subcategory': 'lower abs'},
  // Abs - Obliques
  {'name': 'Side Plank', 'category': 'abs', 'subcategory': 'obliques'},
  {'name': 'Russian Twists', 'category': 'abs', 'subcategory': 'obliques'},
  {'name': 'Woodchoppers', 'category': 'abs', 'subcategory': 'obliques'},
  {'name': 'Oblique Crunches', 'category': 'abs', 'subcategory': 'obliques'},
  {'name': 'Hanging Side Knee Raises', 'category': 'abs', 'subcategory': 'obliques'},
  // Abs - Core
  {'name': 'Plank', 'category': 'abs', 'subcategory': 'core'},
  {'name': 'Ab Wheel', 'category': 'abs', 'subcategory': 'core'},

  // Cardio - Machines
  {'name': 'Treadmill', 'category': 'cardio', 'subcategory': 'machines'},
  {'name': 'Rowing', 'category': 'cardio', 'subcategory': 'machines'},
  {'name': 'Stair Climber', 'category': 'cardio', 'subcategory': 'machines'},
  {'name': 'Elliptical', 'category': 'cardio', 'subcategory': 'machines'},
  // Cardio - Outdoor
  {'name': 'Running', 'category': 'cardio', 'subcategory': 'outdoor'},
  {'name': 'Cycling', 'category': 'cardio', 'subcategory': 'outdoor'},
  {'name': 'Swimming', 'category': 'cardio', 'subcategory': 'outdoor'},
  // Cardio - Other
  {'name': 'Jump Rope', 'category': 'cardio', 'subcategory': 'other'},

  // Calisthenics - Push
  {'name': 'Push-ups', 'category': 'calisthenics', 'subcategory': 'push'},
  {'name': 'Dips', 'category': 'calisthenics', 'subcategory': 'push'},
  {'name': 'Handstand Push-ups', 'category': 'calisthenics', 'subcategory': 'push'},
  // Calisthenics - Pull
  {'name': 'Pull-ups', 'category': 'calisthenics', 'subcategory': 'pull'},
  {'name': 'Muscle-ups', 'category': 'calisthenics', 'subcategory': 'pull'},
  // Calisthenics - Legs
  {'name': 'Bodyweight Squats', 'category': 'calisthenics', 'subcategory': 'legs'},
  {'name': 'Pistol Squats', 'category': 'calisthenics', 'subcategory': 'legs'},
  // Calisthenics - Core
  {'name': 'Sit-ups', 'category': 'calisthenics', 'subcategory': 'core'},
  {'name': 'Burpees', 'category': 'calisthenics', 'subcategory': 'core'},
  {'name': 'Mountain Climbers', 'category': 'calisthenics', 'subcategory': 'core'},

  // Custom (user-defined)
  {'name': 'Custom Exercise', 'category': 'custom', 'subcategory': 'custom'},
];

// Pre-built Exercise list with stable IDs (name-derived slug)
final List<Exercise> kExerciseList = kDefaultExercises.map((e) {
  final id = e['name']!.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
  return Exercise(
    id: id,
    name: e['name']!,
    category: e['category']!,
    subcategory: e['subcategory']!,
  );
}).toList()..sort((a, b) => a.name.compareTo(b.name));

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
