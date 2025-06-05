# Database Schema Documentation

## Exercises Table

### Schema Requirements

#### Data Types
- `name`: text
- `description`: text
- `instructions`: text (newline-separated instructions)
- `primary_muscles`: text[] (PostgreSQL array)
- `secondary_muscles`: text[] (PostgreSQL array)
- `equipment`: text[] (PostgreSQL array)
- `type`: text
- `difficulty`: text (enum: 'beginner', 'intermediate', 'advanced')
- `is_compound`: boolean
- `default_sets`: integer
- `default_reps`: integer
- `default_duration_seconds`: integer
- `default_weight`: numeric
- `video_url`: text
- `image_url`: text
- `user_id`: uuid (references auth.users)

### Data Formatting Requirements

1. **Array Fields**
   ```sql
   -- Correct PostgreSQL array format
   primary_muscles = '{"Quadriceps","Glutes","Hamstrings"}'
   secondary_muscles = '{"Core","Abs"}'
   equipment = '{"Dumbbells","Bench"}'
   ```

2. **Instructions Field**
   - Should be a single text field
   - Multiple instructions joined with newline character ('\n')
   ```sql
   instructions = 'Step 1: Start position\nStep 2: Movement\nStep 3: End position'
   ```

3. **Difficulty Field**
   - Must be lowercase
   - Must match one of the enum values:
     - 'beginner'
     - 'intermediate'
     - 'advanced'

4. **Required Fields**
   - `name`
   - `description`
   - `primary_muscles`
   - `equipment`
   - `type`
   - `difficulty`
   - `instructions`
   - `is_compound`

### Example Valid Exercise Data
```json
{
  "name": "dumbbell goblet squat",
  "description": "A compound lower body exercise focusing on quadriceps and glutes",
  "instructions": "Stand with feet shoulder-width apart.\nHold dumbbell at chest.\nSquat down keeping back straight.\nReturn to standing.",
  "primary_muscles": "{\"Quadriceps\",\"Glutes\",\"Hamstrings\"}",
  "secondary_muscles": "{\"Core\"}",
  "equipment": "{\"Dumbbells\"}",
  "type": "strength",
  "difficulty": "intermediate",
  "is_compound": true,
  "default_sets": 3,
  "default_reps": 12,
  "user_id": "d5cf3086-ba31-4e8e-8467-4babbd3ce464"
}
```

## Implementation Details

### Exercise Model
The `Exercise` class in the application includes a `toDatabaseJson()` method that handles proper formatting for database insertion:

```dart
Map<String, dynamic> toDatabaseJson() {
  return {
    'name': name,
    'description': description,
    'primary_muscles': '{${primaryMuscles.map((m) => '"$m"').join(",")}}',
    'secondary_muscles': '{${secondaryMuscles.map((m) => '"$m"').join(",")}}',
    'equipment': '{${equipment.map((e) => '"$e"').join(",")}}',
    'type': type,
    'difficulty': difficulty.toLowerCase(),
    'instructions': instructions.join('\n'),
    'is_compound': isCompound,
    'default_sets': defaultSets,
    'default_reps': defaultReps,
    'default_duration_seconds': defaultDurationSeconds,
    'default_weight': defaultWeight,
    'user_id': null,  // Set when saving
  };
}
```

### Common Issues and Solutions

1. **Array Format Error**
   ```
   PostgrestException: Array value must start with "{" or dimension information
   ```
   Solution: Ensure arrays are formatted with curly braces and quoted values.

2. **Difficulty Enum Error**
   ```
   PostgrestException: Invalid difficulty value
   ```
   Solution: Convert difficulty to lowercase and ensure it matches enum values.

3. **Missing Required Fields**
   ```
   PostgrestException: null value in column violates not-null constraint
   ```
   Solution: Ensure all required fields are provided when creating exercises.

## Best Practices

1. Always use the `toDatabaseJson()` method when inserting exercises
2. Set the `user_id` before database insertion
3. Validate data formats before sending to the database
4. Use proper error handling for database operations
5. Keep array values consistent across the application 