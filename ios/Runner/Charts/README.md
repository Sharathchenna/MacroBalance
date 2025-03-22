# Native Stats Implementation

This folder contains the native iOS implementation of the statistics and charts functionality for MacroTracker.

## Features

- Weight tracking with trend visualization
- Step counting with HealthKit integration
- Calorie tracking with meal breakdown
- Macronutrient visualization with daily goals

## Integration with Flutter

### Usage in Flutter Code

```dart
// Show the native stats screen
final statsService = StatsService();
await statsService.showStats(initialSection: 'weight');

// Get specific data
final weightData = await statsService.getWeightData();
final stepData = await statsService.getStepData();
final calorieData = await statsService.getCalorieData();
final macroData = await statsService.getMacroData();
```

### Available Sections

The native stats view supports the following sections:
- `weight`: Weight tracking and charts
- `steps`: Daily step count with HealthKit integration
- `calories`: Calorie tracking with meal breakdown
- `macros`: Macronutrient distribution visualization

## Requirements

- iOS 13.0 or later
- DGCharts library (installed via CocoaPods)
- HealthKit capabilities enabled in your project

## Setup

1. Ensure your Podfile includes:
   ```ruby
   platform :ios, '13.0'
   pod 'DGCharts'
   ```

2. Install dependencies:
   ```bash
   cd ios && pod install
   ```

3. Enable HealthKit capabilities in Xcode:
   - Open Xcode workspace
   - Select Runner target
   - Go to Signing & Capabilities
   - Add HealthKit capability

## Architecture

- `StatsViewController`: Main container with tab navigation
- Individual view controllers for each section (Weight, Steps, Calories, Macros)
- `StatsDataManager`: Centralized data management
- `StatsMethodHandler`: Handles Flutter-native communication
- `StatsViewFactory`: Creates native views for Flutter