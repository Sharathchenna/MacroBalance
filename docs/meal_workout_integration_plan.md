# Integration Plan: Meal & Workout Planning

This plan outlines the key areas of development required to implement these new features.

## 1. Core Objectives:

*   **Meal Planning:**
    *   Automatic meal generation based on user's calorie targets and dietary preferences (e.g., keto, vegetarian).
    *   Ability for users to view and log generated meals.
*   **Workout Planning:**
    *   Access to pre-defined workout plans.
    *   Ability for users to create custom workout routines.
    *   Functionality to track workout progress (sets, reps, weight, duration).
    *   Workout suggestions based on user fitness goals and available equipment.

## 2. Key Development Areas:

Here's a breakdown of the components and considerations:

```mermaid
graph TD
    A[User Profile & Goals] --> B{Meal Planning Module};
    A --> C{Workout Planning Module};

    subgraph Meal Planning Module
        direction LR
        M1[Data Models: Meal, Recipe, MealPlan, DietaryPreference]
        M2[Meal Generation Engine]
        M3[UI: Plan Display, Meal Logging]
        M4[Backend: Store Meal Plans, User Preferences]
    end

    subgraph Workout Planning Module
        direction LR
        W1[Data Models: Exercise, Workout, WorkoutPlan, Equipment]
        W2[Workout Suggestion Engine]
        W3[UI: Plan Selection, Custom Routine Builder, Progress Tracking]
        W4[Backend: Store Workout Plans, User Progress, Custom Routines]
    end

    B --> D{Data Storage (Supabase/Firebase)};
    C --> D;
    M2 --> E{External APIs / AI (Optional for Recipes/Generation)};
    W2 --> E;

    F[Existing Services e.g., auth_service, supabase_service] --> B;
    F --> C;
    G[New Services: MealPlanningService, WorkoutPlanningService] --> B;
    G --> C;
```

## 3. Detailed Breakdown:

**I. Data Modeling & Backend (Supabase/Firebase):**

*   **Meal Planning:**
    *   `UserProfile`: Extend with dietary preferences (keto, vegetarian, allergies), calorie goals.
    *   `Recipe`: Name, ingredients, macronutrients, cooking instructions, image.
    *   `Meal`: Collection of recipes or food items for a specific eating occasion (breakfast, lunch, dinner).
    *   `DailyMealPlan`: Date, target calories, assigned meals, actual logged meals.
    *   `UserSavedMeals`: Meals created or customized by the user.
*   **Workout Planning:**
    *   `Exercise`: Name, description, target muscle groups, equipment needed, video/image URL.
    *   `WorkoutSet`: Exercise ID, reps, weight, duration (for timed exercises).
    *   `WorkoutRoutine`: Name, collection of exercises and their sets/reps.
    *   `WorkoutPlan`: A structured sequence of workout routines over a period (e.g., 4-week strength plan).
    *   `UserWorkoutLog`: Date, completed workout routine, actual sets/reps/weight.
    *   `UserCustomRoutines`: Routines created by the user.
    *   `UserEquipment`: List of equipment available to the user.

**II. Service Layer (`lib/services/`):**

*   **New Services:**
    *   `MealPlanningService.dart`:
        *   Generate daily/weekly meal plans based on user profile, goals, and preferences.
        *   Fetch/manage recipes (potentially from an external API or a curated internal database).
        *   Log meals against the plan.
        *   Save/retrieve user-customized meals.
    *   `WorkoutPlanningService.dart`:
        *   Fetch/manage pre-defined workout plans and exercises.
        *   Allow creation and management of custom workout routines.
        *   Suggest workouts based on goals and available equipment.
        *   Log workout completion and progress.
*   **Updates to Existing Services:**
    *   [`AuthService.dart`](lib/services/auth_service.dart:1): Ensure user profile data includes new preferences.
    *   [`SupabaseService.dart`](lib/services/supabase_service.dart:1) / Firebase Service: Add functions for CRUD operations on new data models.
    *   [`StatsService.dart`](lib/services/stats_service.dart:1): Incorporate meal and workout data into user statistics and progress tracking.
    *   [`MacroCalculatorService.dart`](lib/services/macro_calculator_service.dart:1): Potentially link with meal planning for calorie/macro targets.

**III. Meal Generation & Workout Suggestion Engines:**

*   **Meal Generation:**
    *   Could leverage your existing `google_generative_ai` package ([`firebase_vertexai`](firebase.json:1) or [`google_generative_ai`](pubspec.yaml:50)) to generate meal suggestions based on complex criteria.
    *   Alternatively, integrate with a dedicated recipe/nutrition API (e.g., Edamam, Spoonacular) for a wider variety of recipes and nutritional data. This might involve updates to [`api_service.dart`](lib/services/api_service.dart:1).
    *   Develop an algorithm that combines recipes to meet daily macro and calorie targets, considering dietary restrictions.
*   **Workout Suggestion:**
    *   Start with a rules-based system:
        *   Filter exercises by target muscle group and available equipment.
        *   Suggest plans based on user fitness level and goals (e.g., weight loss, muscle gain).
    *   Future enhancement: AI-powered suggestions based on past performance and preferences.

**IV. UI/UX (Flutter):**

*   **Meal Planning:**
    *   Dedicated section for meal plans (daily/weekly view).
    *   Interface to display generated meals with recipe details (ingredients, instructions, macros).
    *   Easy way to log meals (confirming generated meal or adding custom food items).
    *   Interface for setting dietary preferences and calorie goals.
*   **Workout Planning:**
    *   Browse pre-defined workout plans.
    *   Intuitive interface for creating/editing custom workout routines (drag-and-drop exercises, set/rep input).
    *   Clear display of current day's workout.
    *   Input fields for tracking sets, reps, weight during a workout.
    *   Progress charts and history for workouts.
    *   Interface for specifying fitness goals and available equipment.
*   **General:**
    *   Ensure seamless integration with existing navigation and user flow.
    *   Utilize existing UI components from `lib/widgets/` where possible, and create new reusable widgets for these features.

**V. State Management (Provider):**

*   Create new `ChangeNotifier` classes for managing the state of meal plans, workout plans, user selections, and progress.
*   Integrate these with your existing Provider setup.

**VI. Potential Phases (Recommended):**

*   **Phase 1: Core Meal Logging & Basic Workout Tracking**
    *   Allow users to define calorie/macro goals.
    *   Manual meal logging (building on existing functionality if present).
    *   Ability to create and log custom workout routines and track sets/reps/weight.
    *   Data models for basic meal and workout entities.
*   **Phase 2: Automated Meal Plan Generation & Pre-defined Workouts**
    *   Implement the meal generation engine (initial version).
    *   Introduce a library of pre-defined workout plans.
    *   UI for displaying meal plans and selecting workout plans.
*   **Phase 3: Advanced Features & Personalization**
    *   Workout suggestions based on goals/equipment.
    *   Recipe database integration / more sophisticated meal generation.
    *   Advanced progress tracking and analytics.
    *   User ability to save and share custom meal/workout plans.