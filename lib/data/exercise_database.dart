import '../models/exercise.dart';

class ExerciseDatabase {
  static final List<Exercise> _exercises = [
    // CHEST EXERCISES
    Exercise(
      name: 'Push-ups',
      description: 'Classic bodyweight chest exercise',
      primaryMuscles: ['chest'],
      secondaryMuscles: ['triceps', 'shoulders'],
      equipment: ['bodyweight'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Start in plank position with hands slightly wider than shoulders',
        'Lower your body until chest nearly touches the floor',
        'Push back up to starting position',
        'Keep your body in a straight line throughout'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 12,
      estimatedCaloriesBurnedPerMinute: 7,
    ),
    Exercise(
      name: 'Incline Push-ups',
      description: 'Easier variation of push-ups using elevation',
      primaryMuscles: ['chest'],
      secondaryMuscles: ['triceps', 'shoulders'],
      equipment: ['bodyweight'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Place hands on an elevated surface like a bench or step',
        'Perform push-up motion with feet on ground',
        'Lower chest to the elevated surface',
        'Push back up to starting position'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 15,
      estimatedCaloriesBurnedPerMinute: 6,
    ),
    Exercise(
      name: 'Decline Push-ups',
      description: 'Advanced push-up variation with feet elevated',
      primaryMuscles: ['chest'],
      secondaryMuscles: ['triceps', 'shoulders'],
      equipment: ['bodyweight'],
      type: 'strength',
      difficulty: 'intermediate',
      instructions: [
        'Place feet on an elevated surface',
        'Hands on ground in push-up position',
        'Lower chest to ground',
        'Push back up maintaining straight body line'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 10,
      estimatedCaloriesBurnedPerMinute: 8,
    ),
    Exercise(
      name: 'Bench Press',
      description: 'Fundamental barbell chest exercise',
      primaryMuscles: ['chest'],
      secondaryMuscles: ['triceps', 'shoulders'],
      equipment: ['barbell', 'bench'],
      type: 'strength',
      difficulty: 'intermediate',
      instructions: [
        'Lie on bench with eyes under the bar',
        'Grip bar slightly wider than shoulder width',
        'Unrack and lower bar to chest',
        'Press bar back up to starting position'
      ],
      isCompound: true,
      defaultSets: 4,
      defaultReps: 8,
      estimatedCaloriesBurnedPerMinute: 9,
    ),
    Exercise(
      name: 'Dumbbell Chest Press',
      description: 'Chest press using dumbbells for greater range of motion',
      primaryMuscles: ['chest'],
      secondaryMuscles: ['triceps', 'shoulders'],
      equipment: ['dumbbells', 'bench'],
      type: 'strength',
      difficulty: 'intermediate',
      instructions: [
        'Lie on bench with dumbbells in each hand',
        'Start with arms extended above chest',
        'Lower dumbbells to chest level',
        'Press back up to starting position'
      ],
      isCompound: true,
      defaultSets: 4,
      defaultReps: 10,
      estimatedCaloriesBurnedPerMinute: 8,
    ),
    Exercise(
      name: 'Chest Fly',
      description: 'Isolation exercise for chest muscles',
      primaryMuscles: ['chest'],
      secondaryMuscles: [],
      equipment: ['dumbbells', 'bench'],
      type: 'strength',
      difficulty: 'intermediate',
      instructions: [
        'Lie on bench with dumbbells extended above chest',
        'Lower weights in wide arc until chest stretch is felt',
        'Bring dumbbells back together above chest',
        'Keep slight bend in elbows throughout'
      ],
      isCompound: false,
      defaultSets: 3,
      defaultReps: 12,
      estimatedCaloriesBurnedPerMinute: 5,
    ),

    // BACK EXERCISES
    Exercise(
      name: 'Pull-ups',
      description: 'Bodyweight back exercise using pull-up bar',
      primaryMuscles: ['back'],
      secondaryMuscles: ['biceps', 'shoulders'],
      equipment: ['pullUpBar'],
      type: 'strength',
      difficulty: 'intermediate',
      instructions: [
        'Hang from pull-up bar with overhand grip',
        'Pull body up until chin clears the bar',
        'Lower with control to starting position',
        'Keep core engaged throughout movement'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 8,
      estimatedCaloriesBurnedPerMinute: 9,
    ),
    Exercise(
      name: 'Chin-ups',
      description: 'Pull-up variation with underhand grip',
      primaryMuscles: ['back'],
      secondaryMuscles: ['biceps'],
      equipment: ['pullUpBar'],
      type: 'strength',
      difficulty: 'intermediate',
      instructions: [
        'Hang from bar with underhand grip',
        'Pull up until chin clears bar',
        'Lower with control',
        'Focus on squeezing back muscles'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 8,
      estimatedCaloriesBurnedPerMinute: 9,
    ),
    Exercise(
      name: 'Bent-over Rows',
      description: 'Fundamental back exercise with barbell',
      primaryMuscles: ['back'],
      secondaryMuscles: ['biceps', 'shoulders'],
      equipment: ['barbell'],
      type: 'strength',
      difficulty: 'intermediate',
      instructions: [
        'Bend at hips with knees slightly bent',
        'Hold barbell with overhand grip',
        'Pull bar to lower chest/upper abdomen',
        'Lower with control, maintaining bent position'
      ],
      isCompound: true,
      defaultSets: 4,
      defaultReps: 10,
      estimatedCaloriesBurnedPerMinute: 10,
    ),
    Exercise(
      name: 'Dumbbell Rows',
      description: 'Single-arm rowing exercise',
      primaryMuscles: ['back'],
      secondaryMuscles: ['biceps'],
      equipment: ['dumbbells', 'bench'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Place one knee and hand on bench',
        'Hold dumbbell in opposite hand',
        'Pull dumbbell to hip level',
        'Lower with control and repeat'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 12,
      estimatedCaloriesBurnedPerMinute: 7,
    ),
    Exercise(
      name: 'Lat Pulldowns',
      description: 'Cable machine exercise for lats',
      primaryMuscles: ['back'],
      secondaryMuscles: ['biceps'],
      equipment: ['cable', 'machine'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Sit at lat pulldown machine',
        'Grip bar wider than shoulder width',
        'Pull bar down to upper chest',
        'Control the weight back up'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 12,
      estimatedCaloriesBurnedPerMinute: 7,
    ),

    // SHOULDER EXERCISES
    Exercise(
      name: 'Overhead Press',
      description: 'Standing shoulder press with barbell',
      primaryMuscles: ['shoulders'],
      secondaryMuscles: ['triceps', 'chest'],
      equipment: ['barbell'],
      type: 'strength',
      difficulty: 'intermediate',
      instructions: [
        'Stand with feet hip-width apart',
        'Hold barbell at shoulder level',
        'Press bar straight overhead',
        'Lower with control to starting position'
      ],
      isCompound: true,
      defaultSets: 4,
      defaultReps: 8,
      estimatedCaloriesBurnedPerMinute: 9,
    ),
    Exercise(
      name: 'Dumbbell Shoulder Press',
      description: 'Seated or standing shoulder press with dumbbells',
      primaryMuscles: ['shoulders'],
      secondaryMuscles: ['triceps'],
      equipment: ['dumbbells'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Hold dumbbells at shoulder height',
        'Press weights straight overhead',
        'Lower with control to shoulder level',
        'Keep core engaged throughout'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 12,
      estimatedCaloriesBurnedPerMinute: 8,
    ),
    Exercise(
      name: 'Lateral Raises',
      description: 'Isolation exercise for side deltoids',
      primaryMuscles: ['shoulders'],
      secondaryMuscles: [],
      equipment: ['dumbbells'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Hold dumbbells at sides with slight bend in elbows',
        'Raise weights out to sides until parallel to ground',
        'Lower with control',
        'Focus on slow, controlled movement'
      ],
      isCompound: false,
      defaultSets: 3,
      defaultReps: 15,
      estimatedCaloriesBurnedPerMinute: 4,
    ),
    Exercise(
      name: 'Front Raises',
      description: 'Isolation exercise for front deltoids',
      primaryMuscles: ['shoulders'],
      secondaryMuscles: [],
      equipment: ['dumbbells'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Hold dumbbells in front of thighs',
        'Raise one or both arms forward to shoulder height',
        'Lower with control',
        'Keep core stable throughout'
      ],
      isCompound: false,
      defaultSets: 3,
      defaultReps: 12,
      estimatedCaloriesBurnedPerMinute: 4,
    ),

    // ARM EXERCISES
    Exercise(
      name: 'Bicep Curls',
      description: 'Classic bicep isolation exercise',
      primaryMuscles: ['biceps'],
      secondaryMuscles: [],
      equipment: ['dumbbells'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Hold dumbbells at sides with palms facing forward',
        'Curl weights up to shoulders',
        'Lower with control',
        'Keep elbows stationary'
      ],
      isCompound: false,
      defaultSets: 3,
      defaultReps: 12,
      estimatedCaloriesBurnedPerMinute: 5,
    ),
    Exercise(
      name: 'Hammer Curls',
      description: 'Bicep curl variation with neutral grip',
      primaryMuscles: ['biceps'],
      secondaryMuscles: ['forearms'],
      equipment: ['dumbbells'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Hold dumbbells with neutral grip (palms facing each other)',
        'Curl weights up to shoulders',
        'Lower with control',
        'Keep wrists straight'
      ],
      isCompound: false,
      defaultSets: 3,
      defaultReps: 12,
      estimatedCaloriesBurnedPerMinute: 5,
    ),
    Exercise(
      name: 'Tricep Dips',
      description: 'Bodyweight tricep exercise using bench or chair',
      primaryMuscles: ['triceps'],
      secondaryMuscles: ['shoulders'],
      equipment: ['bench'],
      type: 'strength',
      difficulty: 'intermediate',
      instructions: [
        'Sit on edge of bench with hands gripping edge',
        'Walk feet forward and lower body',
        'Dip until elbows are at 90 degrees',
        'Push back up to starting position'
      ],
      isCompound: false,
      defaultSets: 3,
      defaultReps: 10,
      estimatedCaloriesBurnedPerMinute: 7,
    ),
    Exercise(
      name: 'Tricep Extensions',
      description: 'Overhead tricep isolation exercise',
      primaryMuscles: ['triceps'],
      secondaryMuscles: [],
      equipment: ['dumbbells'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Hold dumbbell overhead with both hands',
        'Lower weight behind head by bending elbows',
        'Extend arms back to starting position',
        'Keep upper arms stationary'
      ],
      isCompound: false,
      defaultSets: 3,
      defaultReps: 12,
      estimatedCaloriesBurnedPerMinute: 5,
    ),

    // LEG EXERCISES
    Exercise(
      name: 'Squats',
      description: 'Fundamental lower body exercise',
      primaryMuscles: ['quadriceps'],
      secondaryMuscles: ['glutes', 'hamstrings'],
      equipment: ['bodyweight'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Stand with feet shoulder-width apart',
        'Lower body as if sitting back into a chair',
        'Go down until thighs are parallel to ground',
        'Push through heels to return to standing'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 15,
      estimatedCaloriesBurnedPerMinute: 10,
    ),
    Exercise(
      name: 'Goblet Squats',
      description: 'Squat variation holding weight at chest',
      primaryMuscles: ['quadriceps'],
      secondaryMuscles: ['glutes', 'hamstrings'],
      equipment: ['dumbbells'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Hold dumbbell at chest level',
        'Perform squat motion',
        'Keep chest up and core engaged',
        'Weight helps with balance and form'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 12,
      estimatedCaloriesBurnedPerMinute: 9,
    ),
    Exercise(
      name: 'Lunges',
      description: 'Single-leg strength and stability exercise',
      primaryMuscles: ['quadriceps'],
      secondaryMuscles: ['glutes', 'hamstrings'],
      equipment: ['bodyweight'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Step forward into lunge position',
        'Lower back knee toward ground',
        'Push off front foot to return to standing',
        'Alternate legs or complete one side first'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 12,
      estimatedCaloriesBurnedPerMinute: 7,
    ),
    Exercise(
      name: 'Bulgarian Split Squats',
      description: 'Single-leg squat with rear foot elevated',
      primaryMuscles: ['quadriceps'],
      secondaryMuscles: ['glutes'],
      equipment: ['bench'],
      type: 'strength',
      difficulty: 'intermediate',
      instructions: [
        'Place rear foot on bench behind you',
        'Lower into single-leg squat position',
        'Push through front heel to return up',
        'Complete all reps on one leg before switching'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 10,
      estimatedCaloriesBurnedPerMinute: 8,
    ),
    Exercise(
      name: 'Deadlifts',
      description: 'Hip hinge movement with barbell',
      primaryMuscles: ['hamstrings'],
      secondaryMuscles: ['glutes', 'back'],
      equipment: ['barbell'],
      type: 'strength',
      difficulty: 'intermediate',
      instructions: [
        'Stand with feet hip-width apart, bar over mid-foot',
        'Hinge at hips and grab bar',
        'Drive through heels and hips to stand up',
        'Lower bar with control by hinging at hips'
      ],
      isCompound: true,
      defaultSets: 4,
      defaultReps: 8,
      estimatedCaloriesBurnedPerMinute: 12,
    ),
    Exercise(
      name: 'Romanian Deadlifts',
      description: 'Deadlift variation focusing on hamstrings',
      primaryMuscles: ['hamstrings'],
      secondaryMuscles: ['glutes'],
      equipment: ['dumbbells'],
      type: 'strength',
      difficulty: 'intermediate',
      instructions: [
        'Hold dumbbells in front of thighs',
        'Hinge at hips, lowering weights',
        'Feel stretch in hamstrings',
        'Drive hips forward to return to standing'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 12,
      estimatedCaloriesBurnedPerMinute: 8,
    ),
    Exercise(
      name: 'Calf Raises',
      description: 'Isolation exercise for calf muscles',
      primaryMuscles: ['calves'],
      secondaryMuscles: [],
      equipment: ['bodyweight'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Stand with balls of feet on elevated surface',
        'Rise up onto toes as high as possible',
        'Lower heels below starting position',
        'Repeat with controlled movement'
      ],
      isCompound: false,
      defaultSets: 3,
      defaultReps: 20,
      estimatedCaloriesBurnedPerMinute: 3,
    ),

    // CORE EXERCISES
    Exercise(
      name: 'Plank',
      description: 'Isometric core strengthening exercise',
      primaryMuscles: ['abs'],
      secondaryMuscles: ['shoulders', 'back'],
      equipment: ['bodyweight'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Start in push-up position on forearms',
        'Keep body in straight line from head to heels',
        'Engage core and hold position',
        'Breathe normally throughout hold'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultDurationSeconds: 30,
      estimatedCaloriesBurnedPerMinute: 5,
    ),
    Exercise(
      name: 'Crunches',
      description: 'Classic abdominal exercise',
      primaryMuscles: ['abs'],
      secondaryMuscles: [],
      equipment: ['bodyweight'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Lie on back with knees bent',
        'Lift shoulders off ground toward knees',
        'Focus on contracting abs',
        'Lower with control'
      ],
      isCompound: false,
      defaultSets: 3,
      defaultReps: 20,
      estimatedCaloriesBurnedPerMinute: 4,
    ),
    Exercise(
      name: 'Russian Twists',
      description: 'Rotational core exercise',
      primaryMuscles: ['obliques'],
      secondaryMuscles: ['abs'],
      equipment: ['bodyweight'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Sit with knees bent, leaning back slightly',
        'Rotate torso side to side',
        'Touch ground beside hips with hands',
        'Keep feet off ground for added difficulty'
      ],
      isCompound: false,
      defaultSets: 3,
      defaultReps: 20,
      estimatedCaloriesBurnedPerMinute: 6,
    ),
    Exercise(
      name: 'Mountain Climbers',
      description: 'Dynamic core and cardio exercise',
      primaryMuscles: ['abs'],
      secondaryMuscles: ['shoulders', 'legs'],
      equipment: ['bodyweight'],
      type: 'cardio',
      difficulty: 'intermediate',
      instructions: [
        'Start in plank position',
        'Alternate bringing knees to chest rapidly',
        'Keep hips level and core engaged',
        'Maintain quick pace'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultDurationSeconds: 30,
      estimatedCaloriesBurnedPerMinute: 12,
    ),

    // CARDIO EXERCISES
    Exercise(
      name: 'Jumping Jacks',
      description: 'Full-body cardio exercise',
      primaryMuscles: ['fullBody'],
      secondaryMuscles: [],
      equipment: ['bodyweight'],
      type: 'cardio',
      difficulty: 'beginner',
      instructions: [
        'Start with feet together, arms at sides',
        'Jump feet apart while raising arms overhead',
        'Jump back to starting position',
        'Maintain steady rhythm'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultDurationSeconds: 30,
      estimatedCaloriesBurnedPerMinute: 10,
    ),
    Exercise(
      name: 'Burpees',
      description: 'High-intensity full-body exercise',
      primaryMuscles: ['fullBody'],
      secondaryMuscles: [],
      equipment: ['bodyweight'],
      type: 'cardio',
      difficulty: 'advanced',
      instructions: [
        'Start standing, squat down and place hands on ground',
        'Jump feet back into plank position',
        'Do a push-up (optional)',
        'Jump feet back to squat, then jump up with arms overhead'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 10,
      estimatedCaloriesBurnedPerMinute: 15,
    ),
    Exercise(
      name: 'High Knees',
      description: 'Running in place with high knee lift',
      primaryMuscles: ['legs'],
      secondaryMuscles: ['abs'],
      equipment: ['bodyweight'],
      type: 'cardio',
      difficulty: 'beginner',
      instructions: [
        'Run in place lifting knees to waist height',
        'Pump arms naturally',
        'Land on balls of feet',
        'Maintain quick pace'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultDurationSeconds: 30,
      estimatedCaloriesBurnedPerMinute: 11,
    ),
    Exercise(
      name: 'Running',
      description: 'Outdoor or treadmill cardiovascular exercise',
      primaryMuscles: ['legs'],
      secondaryMuscles: ['cardio'],
      equipment: ['bodyweight'],
      type: 'cardio',
      difficulty: 'beginner',
      instructions: [
        'Maintain steady pace appropriate for fitness level',
        'Land on mid-foot, not heel',
        'Keep posture upright',
        'Breathe rhythmically'
      ],
      isCompound: true,
      defaultSets: 1,
      defaultDurationSeconds: 1800, // 30 minutes
      estimatedCaloriesBurnedPerMinute: 10,
    ),

    // FLEXIBILITY EXERCISES
    Exercise(
      name: 'Downward Dog',
      description: 'Yoga pose stretching hamstrings and calves',
      primaryMuscles: ['hamstrings'],
      secondaryMuscles: ['calves', 'shoulders'],
      equipment: ['yogaMat'],
      type: 'flexibility',
      difficulty: 'beginner',
      instructions: [
        'Start on hands and knees',
        'Tuck toes and lift hips up and back',
        'Straighten legs and arms',
        'Hold and breathe deeply'
      ],
      isCompound: true,
      defaultSets: 1,
      defaultDurationSeconds: 30,
      estimatedCaloriesBurnedPerMinute: 2,
    ),
    Exercise(
      name: 'Child\'s Pose',
      description: 'Restorative yoga pose',
      primaryMuscles: ['back'],
      secondaryMuscles: [],
      equipment: ['yogaMat'],
      type: 'flexibility',
      difficulty: 'beginner',
      instructions: [
        'Kneel on floor with big toes touching',
        'Sit back on heels',
        'Fold forward with arms extended',
        'Rest forehead on ground and breathe'
      ],
      isCompound: false,
      defaultSets: 1,
      defaultDurationSeconds: 60,
      estimatedCaloriesBurnedPerMinute: 1,
    ),

    // KETTLEBELL EXERCISES
    Exercise(
      name: 'Kettlebell Swings',
      description: 'Dynamic hip hinge exercise with kettlebell',
      primaryMuscles: ['glutes'],
      secondaryMuscles: ['hamstrings', 'shoulders'],
      equipment: ['kettlebell'],
      type: 'strength',
      difficulty: 'intermediate',
      instructions: [
        'Stand with feet wider than shoulders',
        'Hold kettlebell with both hands',
        'Hinge at hips, swing kettlebell between legs',
        'Drive hips forward to swing kettlebell to chest height'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 15,
      estimatedCaloriesBurnedPerMinute: 12,
    ),
    Exercise(
      name: 'Turkish Get-ups',
      description: 'Complex full-body movement with kettlebell',
      primaryMuscles: ['fullBody'],
      secondaryMuscles: [],
      equipment: ['kettlebell'],
      type: 'strength',
      difficulty: 'advanced',
      instructions: [
        'Lie on back holding kettlebell overhead',
        'Follow specific sequence to stand up',
        'Reverse the movement to return to ground',
        'Keep kettlebell overhead throughout'
      ],
      isCompound: true,
      defaultSets: 2,
      defaultReps: 5,
      estimatedCaloriesBurnedPerMinute: 10,
    ),

    // RESISTANCE BAND EXERCISES
    Exercise(
      name: 'Resistance Band Rows',
      description: 'Back exercise using resistance bands',
      primaryMuscles: ['back'],
      secondaryMuscles: ['biceps'],
      equipment: ['resistanceBands'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Anchor band at chest height',
        'Hold handles and step back for tension',
        'Pull handles to chest squeezing shoulder blades',
        'Return with control'
      ],
      isCompound: true,
      defaultSets: 3,
      defaultReps: 15,
      estimatedCaloriesBurnedPerMinute: 5,
    ),
    Exercise(
      name: 'Band Pull-aparts',
      description: 'Shoulder and upper back exercise',
      primaryMuscles: ['shoulders'],
      secondaryMuscles: ['back'],
      equipment: ['resistanceBands'],
      type: 'strength',
      difficulty: 'beginner',
      instructions: [
        'Hold band with both hands, arms extended in front at shoulder height',
        'Pull band apart by moving arms to sides',
        'Squeeze shoulder blades together',
        'Return with control'
      ],
      isCompound: false,
      defaultSets: 3,
      defaultReps: 15,
      estimatedCaloriesBurnedPerMinute: 3,
    ),
  ];

  // Public methods to access exercises
  static List<Exercise> getAllExercises() => List.unmodifiable(_exercises);

  static List<Exercise> getExercisesByMuscleGroup(String muscleGroup) {
    final lowerCaseMuscleGroup = muscleGroup.toLowerCase();
    return _exercises
        .where((exercise) =>
            exercise.primaryMuscles
                .any((pm) => pm.toLowerCase() == lowerCaseMuscleGroup) ||
            exercise.secondaryMuscles
                .any((sm) => sm.toLowerCase() == lowerCaseMuscleGroup))
        .toList();
  }

  static List<Exercise> getExercisesByEquipment(String equipmentType) {
    final lowerCaseEquipment = equipmentType.toLowerCase();
    return _exercises
        .where((exercise) => exercise.equipment
            .any((eq) => eq.toLowerCase() == lowerCaseEquipment))
        .toList();
  }

  static List<Exercise> getExercisesByDifficulty(String difficultyLevel) {
    final lowerCaseDifficulty = difficultyLevel.toLowerCase();
    return _exercises
        .where((exercise) =>
            exercise.difficulty.toLowerCase() == lowerCaseDifficulty)
        .toList();
  }

  static List<Exercise> getExercisesByType(String exerciseType) {
    final lowerCaseType = exerciseType.toLowerCase();
    return _exercises
        .where((exercise) => exercise.type.toLowerCase() == lowerCaseType)
        .toList();
  }

  static Exercise? getExerciseById(String id) {
    try {
      return _exercises.firstWhere((exercise) => exercise.id == id);
    } catch (e) {
      return null;
    }
  }

  static List<Exercise> searchExercises(String query) {
    final lowercaseQuery = query.toLowerCase();
    if (lowercaseQuery.isEmpty) return getAllExercises();
    return _exercises
        .where((exercise) =>
            exercise.name.toLowerCase().contains(lowercaseQuery) ||
            exercise.description.toLowerCase().contains(lowercaseQuery) ||
            exercise.primaryMuscles.any(
                (muscle) => muscle.toLowerCase().contains(lowercaseQuery)) ||
            exercise.secondaryMuscles.any(
                (muscle) => muscle.toLowerCase().contains(lowercaseQuery)) ||
            exercise.equipment
                .any((eq) => eq.toLowerCase().contains(lowercaseQuery)))
        .toList();
  }

  // Get exercises suitable for beginners
  static List<Exercise> getBeginnerExercises() {
    return _exercises
        .where((exercise) =>
            exercise.difficulty.toLowerCase() == 'beginner' &&
            (exercise.equipment.any((eq) => eq.toLowerCase() == 'bodyweight') ||
                exercise.equipment
                    .any((eq) => eq.toLowerCase() == 'dumbbells') ||
                exercise.equipment
                    .any((eq) => eq.toLowerCase() == 'resistancebands')))
        .toList();
  }

  // Get bodyweight exercises only
  static List<Exercise> getBodyweightExercises() {
    return _exercises
        .where((exercise) =>
            exercise.equipment.any((eq) => eq.toLowerCase() == 'bodyweight') &&
            exercise.equipment.length == 1)
        .toList();
  }

  // Get compound exercises (work multiple muscle groups)
  static List<Exercise> getCompoundExercises() {
    return _exercises.where((exercise) => exercise.isCompound).toList();
  }

  // Get exercises by available equipment
  static List<Exercise> getExercisesForEquipment(
      List<String> availableEquipment) {
    if (availableEquipment.isEmpty) return getBodyweightExercises();
    final lowerCaseAvailableEquipment =
        availableEquipment.map((e) => e.toLowerCase()).toList();
    return _exercises
        .where((exercise) => exercise.equipment.every((reqEq) =>
            reqEq.toLowerCase() == 'bodyweight' ||
            lowerCaseAvailableEquipment.contains(reqEq.toLowerCase())))
        .toList();
  }

  // Get muscle group categories
  static List<String> getMuscleGroups() {
    final Set<String> muscleGroups = {};
    for (final exercise in _exercises) {
      muscleGroups.addAll(exercise.primaryMuscles
          .map((m) => m[0].toUpperCase() + m.substring(1).toLowerCase()));
    }
    final sortedList = muscleGroups.toList()..sort();
    // Prioritize common groups
    const priorityGroups = [
      'Chest',
      'Back',
      'Shoulders',
      'Legs',
      'Arms',
      'Core',
      'Full Body',
      'Cardio'
    ];
    final result =
        sortedList.where((g) => !priorityGroups.contains(g)).toList();
    result.insertAll(0, priorityGroups.where((pg) => sortedList.contains(pg)));
    return result.toSet().toList(); // Ensure uniqueness
  }

  // Get equipment categories
  static List<String> getEquipmentTypes() {
    final Set<String> equipmentTypes = {};
    for (final exercise in _exercises) {
      equipmentTypes.addAll(exercise.equipment
          .map((e) => e[0].toUpperCase() + e.substring(1).toLowerCase()));
    }
    final sortedList = equipmentTypes.toList()..sort();
    // Prioritize common equipment
    const priorityEquipment = [
      'Bodyweight',
      'Dumbbells',
      'Barbell',
      'Kettlebell',
      'Resistance Bands',
      'Machine',
      'Cable',
      'Bench',
      'PullUpBar'
    ];
    final result =
        sortedList.where((e) => !priorityEquipment.contains(e)).toList();
    result.insertAll(
        0, priorityEquipment.where((pe) => sortedList.contains(pe)));
    return result.toSet().toList(); // Ensure uniqueness
  }
}
