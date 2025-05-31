# ExerciseDB API Integration - Usage Examples

## Quick Start

### 1. Get Your API Key
1. Visit [RapidAPI ExerciseDB](https://rapidapi.com/justin-WFnsXH_t6/api/exercisedb)
2. Sign up for a free account
3. Subscribe to the ExerciseDB API (free tier includes 100 requests/day)
4. Copy your API key

### 2. Configure the App
Edit `lib/services/exercise_image_service.dart`:

```dart
// Replace this line:
static const String _apiKey = 'YOUR_RAPIDAPI_KEY';

// With your actual key:
static const String _apiKey = 'your-actual-api-key-here';
```

## Usage Examples

### Basic Exercise Image Loading

```dart
// Get exercise image with smart fallback
final imageService = ExerciseImageService();
final imageUrl = await imageService.getExerciseImageUrl('push ups');

// Display in your widget
Image.network(
  imageUrl,
  fit: BoxFit.cover,
  errorBuilder: (context, error, stackTrace) {
    return Icon(Icons.fitness_center); // Fallback icon
  },
)
```

### Get Comprehensive Exercise Data

```dart
final exerciseData = await imageService.getExerciseData('barbell squat');

if (exerciseData != null) {
  print('Exercise: ${exerciseData['name']}');
  print('Equipment: ${exerciseData['equipment']}');
  print('Target Muscle: ${exerciseData['target']}');
  print('Instructions: ${exerciseData['instructions']}');
  print('GIF URL: ${exerciseData['gifUrl']}');
  print('Difficulty: ${exerciseData['difficulty']}');
}
```

### Find Exercises by Muscle Group

```dart
// Get all chest exercises
final chestExercises = await imageService.getExercisesByMuscleGroup('pectorals');

for (final exercise in chestExercises) {
  print('${exercise['name']} - ${exercise['equipment']}');
}
```

### Find Exercises by Equipment

```dart
// Get all dumbbell exercises
final dumbbellExercises = await imageService.getExercisesByEquipment('dumbbell');

for (final exercise in dumbbellExercises) {
  print('${exercise['name']} targets ${exercise['target']}');
}
```

### AI-Enhanced Workout Generation

```dart
final aiService = FitnessAIService();
final profile = FitnessProfile(
  fitnessLevel: 'intermediate',
  availableEquipment: ['dumbbell', 'barbell', 'body weight'],
  workoutsPerWeek: 4,
);

// Generate AI workout with real exercise data
final workout = await aiService.generateEnhancedWorkoutPlan(
  profile: profile,
  macroData: {'goal_type': 'muscle_gain'},
  specificMuscleGroup: 'chest',
  customDuration: 45,
);

print('Generated ${workout.exercises.length} exercises');
```

## Widget Integration Examples

### Exercise Preview Card with Real Data

```dart
class ExerciseCard extends StatelessWidget {
  final String exerciseName;
  
  const ExerciseCard({required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ExerciseImageService().getExerciseData(exerciseName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        
        final exercise = snapshot.data;
        if (exercise == null) {
          return _buildFallbackCard();
        }
        
        return Card(
          child: Column(
            children: [
              // Exercise GIF
              Image.network(
                exercise['gifUrl'],
                height: 200,
                fit: BoxFit.cover,
              ),
              
              // Exercise Details
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise['name'],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Chip(label: Text(exercise['equipment'])),
                        SizedBox(width: 8),
                        Chip(label: Text(exercise['target'])),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Difficulty: ${exercise['difficulty']}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackCard() {
    return Card(
      child: Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center, size: 48),
              SizedBox(height: 8),
              Text(exerciseName),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Exercise Alternative Finder

```dart
class ExerciseAlternativeFinder extends StatefulWidget {
  final String currentExercise;
  final String targetMuscle;
  
  const ExerciseAlternativeFinder({
    required this.currentExercise,
    required this.targetMuscle,
  });

  @override
  _ExerciseAlternativeFinderState createState() => _ExerciseAlternativeFinderState();
}

class _ExerciseAlternativeFinderState extends State<ExerciseAlternativeFinder> {
  List<Map<String, dynamic>> alternatives = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlternatives();
  }

  Future<void> _loadAlternatives() async {
    final imageService = ExerciseImageService();
    final exercises = await imageService.getExercisesByMuscleGroup(widget.targetMuscle);
    
    // Filter out current exercise and limit results
    setState(() {
      alternatives = exercises
          .where((ex) => ex['name'] != widget.currentExercise)
          .take(5)
          .toList();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alternative Exercises',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 16),
        
        ...alternatives.map((exercise) => ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(exercise['gifUrl']),
          ),
          title: Text(exercise['name']),
          subtitle: Text('Equipment: ${exercise['equipment']}'),
          onTap: () {
            // Handle exercise selection
            Navigator.pop(context, exercise);
          },
        )).toList(),
      ],
    );
  }
}
```

## Error Handling

### Graceful Fallbacks

```dart
class RobustExerciseImage extends StatelessWidget {
  final String exerciseName;
  
  const RobustExerciseImage({required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: ExerciseImageService().getExerciseImageUrl(exerciseName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }
        
        if (snapshot.hasError) {
          return _buildErrorState();
        }
        
        final imageUrl = snapshot.data ?? '';
        
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildLoadingState();
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackImage();
          },
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 200,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 200,
      color: Colors.red.shade100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(height: 8),
            Text('Failed to load exercise'),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      height: 200,
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 48),
            SizedBox(height: 8),
            Text(exerciseName),
          ],
        ),
      ),
    );
  }
}
```

## Performance Optimization

### Caching Strategy

```dart
class CachedExerciseService {
  static final _instance = CachedExerciseService._internal();
  factory CachedExerciseService() => _instance;
  CachedExerciseService._internal();

  final Map<String, String> _imageCache = {};
  final Map<String, Map<String, dynamic>> _dataCache = {};

  Future<String> getCachedImageUrl(String exerciseName) async {
    // Check cache first
    if (_imageCache.containsKey(exerciseName)) {
      return _imageCache[exerciseName]!;
    }

    // Get from service and cache
    final imageUrl = await ExerciseImageService().getExerciseImageUrl(exerciseName);
    _imageCache[exerciseName] = imageUrl;
    
    return imageUrl;
  }

  Future<Map<String, dynamic>?> getCachedExerciseData(String exerciseName) async {
    // Check cache first
    if (_dataCache.containsKey(exerciseName)) {
      return _dataCache[exerciseName];
    }

    // Get from service and cache
    final data = await ExerciseImageService().getExerciseData(exerciseName);
    if (data != null) {
      _dataCache[exerciseName] = data;
    }
    
    return data;
  }

  void clearCache() {
    _imageCache.clear();
    _dataCache.clear();
  }
}
```

## Testing Without API Key

If you don't have an API key yet, the app will automatically fall back to:

1. **Local Exercise Database**: Built-in exercise mappings
2. **Category-based Images**: Placeholder images by muscle group  
3. **AI-generated Alternatives**: Smart exercise substitutions

This ensures your app works immediately while you set up the API integration.

## Rate Limiting

The service automatically handles rate limiting:

- **Free Tier**: 50 requests/minute
- **Automatic Throttling**: Prevents exceeding limits
- **Graceful Degradation**: Falls back to local data when limits reached
- **Cache Optimization**: Reduces redundant API calls

## Troubleshooting

### Common Issues

1. **Images not loading**: Check your API key configuration
2. **Empty exercise lists**: Verify your internet connection
3. **Rate limit exceeded**: Wait for rate limit reset or upgrade plan
4. **App crashes**: Ensure proper error handling in your widgets

### Debug Mode

Enable debug logging:

```dart
// In your main.dart
void main() {
  // Enable debug logging
  developer.log('ExerciseDB Integration enabled');
  
  runApp(MyApp());
}
```

## Next Steps

1. **Get API Key**: Sign up for ExerciseDB API
2. **Configure App**: Update the API key in the service
3. **Test Integration**: Try the example widgets
4. **Customize UI**: Adapt the examples to your app's design
5. **Monitor Usage**: Keep track of API calls and upgrade as needed

Happy coding! 🚀💪 