# Plan: Frequently Logged Food Suggestions

This document outlines the plan to implement a feature that suggests frequently logged food items to users, making the food logging process faster and more convenient.

## High-Level Plan

1.  **Data Retrieval Logic (in `FoodEntryProvider.dart`):**
    *   Add a method to `lib/providers/food_entry_provider.dart` that:
        *   Calculates the frequency of logged food items (e.g., based on `fdcId` or `name` + `brandName`).
        *   Considers a defined time window (e.g., last 30 days, or configurable).
        *   Returns a sorted list of the most frequent `FoodItem` objects.

2.  **UI Integration in `searchPage.dart`:**
    *   Modify the `_buildEmptyState()` method in `lib/screens/searchPage.dart`.
    *   **Show suggestions in the initial empty state:** When the search page loads and the search bar is empty, fetch and display the list of frequently logged items (e.g., top 3-5) using the `lib/widgets/food_suggestion_tile.dart` widget. These suggestions will appear as part of this initial view.
    *   **Action on tap:** When a user taps a `FoodSuggestionTile` on this page, the food item's name will pre-fill the search bar, and a search for that item will be automatically triggered.

3.  **UI Integration for "Add Food" - Compact Dialog (from `macro_tracking_screen.dart`):**
    *   Implement the `_showAddFoodDialog()` method in `lib/screens/macro_tracking_screen.dart` to display a **compact dialog**.
    *   **Suggestions First:** Upon opening, this dialog will immediately fetch and display the list of frequently logged items (e.g., top 3-5) using `lib/widgets/food_suggestion_tile.dart`.
    *   **Action on tap:** When a user taps a suggestion in this compact dialog, it should facilitate quick logging. This likely means pre-filling a small form within the dialog (e.g., for quantity, meal type if not already set) and then allowing the user to log it.
    *   The dialog should also provide an option to perform a manual search if the desired item isn't in the suggestions (e.g., a search icon/button that could either expand a search bar within the dialog or navigate to the full `searchPage.dart`).

## Visual Flow

```mermaid
graph TD
    A[User on Macro Tracking Screen] --> B{Food Logging Action?};
    B -- Clicks 'Add Food' FAB --> C[Show Compact 'Add Food' Dialog];
    B -- Navigates to Search Page --> D[User opens Search Page];

    C -- Dialog Opens --> E{Fetch Frequent Items};
    D -- Initial Empty State --> E;

    E -- Has Frequent Items --> F_Search[Display Frequent Items on SearchPage (in Empty State) using FoodSuggestionTile];
    E -- Has Frequent Items --> F_Dialog[Display Frequent Items in Compact Dialog (First View) using FoodSuggestionTile];

    subgraph SearchPage_Interactions
        direction TB
        F_Search --> G_Search{User Taps Suggestion on SearchPage};
        G_Search --> H_Search[Pre-fill Search Bar & Trigger Search];
        D -- User types in Search Bar --> K[Perform Regular Search];
        K --> L[Display Search Results];
        L -- User Taps Result --> I_NavToDetail[Navigate to FoodDetailPage];
        H_Search --> L;
    end

    subgraph AddFoodDialog_Interactions
        direction TB
        F_Dialog --> G_Dialog{User Taps Suggestion in Dialog};
        G_Dialog --> J_Dialog[Pre-fill Compact Logging Form / Quick Log Action];
        C --> AD_SearchOption[Option to Search Manually from Dialog];
        AD_SearchOption -- Leads to --> D;
    end

    subgraph FoodEntryProvider_Logic
        direction LR
        P1[All Food Entries (_entries)] --> P2{Calculate Frequency};
        P2 -- Based on FDC ID / Name+Brand & Time Window --> P3[Sort by Frequency];
        P3 --> P4[Return List<FoodItem> of Frequent Items];
    end

    E --> P4;