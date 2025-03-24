# MacroTracker Nutrition UI

The MacroTracker iOS app includes a modern, user-friendly nutrition tracking interface designed to make tracking macros intuitive and insightful. The UI offers a visually appealing presentation of macro data with dynamic animations and easy-to-understand visualizations.

## Redesigned Macros Page

The completely redesigned Macros page features:

- **Modern Visual Design**: Clean cards with subtle shadows, cohesive color scheme, and consistent visual hierarchy
- **Interactive Charts**: Animated donut chart and trend analysis charts
- **Actionable Insights**: Nutrient recommendations and deficiency alerts
- **Customizable Goals**: Easy goal setting for each macro

## Key Components

### 1. Summary Card
Displays calorie summary with:
- Current calorie intake
- Remaining calories
- Visual progress indicator
- Calories consumed vs. burned

### 2. Macro Balance Chart
Interactive donut chart showing:
- Protein/carbs/fat distribution
- Percentage breakdown
- Total calories at the center
- Time range selection (day/week/month)

### 3. Macro Tracking Card
Detailed progress tracking for each macro:
- Current vs. goal values
- Visual progress bars
- Custom icons for each macro
- Color-coded indicators

### 4. Trend Analysis
Line chart visualization showing:
- Macro consumption over time
- Multiple view options (percentages, grams, goal progress)
- Time period selection

### 5. Nutrient Insights
Personalized recommendations with:
- Deficiency alerts
- Achievement recognition
- Micronutrient progress indicators
- Tap for detailed breakdown

## Design Decisions

The redesign focuses on several key principles:

1. **Clarity**: Presenting complex nutritional data in an easy-to-understand format
2. **Context**: Showing data in relation to goals and historical patterns
3. **Actionability**: Providing insights that help users make better nutritional choices
4. **Visual Appeal**: Using modern design elements that make tracking nutrition enjoyable
5. **Performance**: Smooth animations and responsive UI that performs well on all devices

## Integration Notes

The MacrosViewController integrates with:
- `StatsDataManager` for data retrieval
- `MacroRingView` for the donut chart
- `MacroTrendChartView` for trend visualization
- `GoalsViewController` for customizing nutrition targets
- `NutrientDetailViewController` for detailed nutrient breakdown

## Usage

The UI updates automatically when:
- The view first loads
- The user pulls to refresh
- Nutrition goals are changed
- New nutrition data is recorded

Time periods can be adjusted using the segmented controls on the appropriate cards.

## Future Enhancements

Planned enhancements include:
- Macro meal planning suggestions
- AI-powered nutrition insights
- Integration with popular food databases
- Weekly and monthly nutrition reports
- Custom macro ratio suggestions based on fitness goals

## Screenshots

[Screenshots would be added here in a real README]

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