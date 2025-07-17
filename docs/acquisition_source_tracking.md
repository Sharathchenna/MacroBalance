# User Acquisition Source Tracking

This document outlines the implementation of user acquisition source tracking in the MacroTracker onboarding flow.

## Overview

The acquisition source tracking feature helps identify where users discover the app, enabling better marketing analysis and optimization. The data is captured during onboarding and sent to PostHog analytics.

## Implementation Details

### 1. New Onboarding Page
- **File**: `lib/screens/onboarding/pages/acquisition_source_page.dart`
- **Position**: Page 1 in onboarding flow (after Welcome page)
- **Sources Tracked**:
  - TikTok
  - YouTube
  - Instagram
  - App Store
  - Google Search
  - Website
  - Friend Referral
  - Reddit
  - Other
  - Skipped (when user chooses not to answer)

### 2. Data Collection
- **Storage**: Not stored in Supabase database (per requirement)
- **Analytics**: Sent directly to PostHog analytics
- **Events Tracked**:
  - `acquisition_source_selected`: When user selects a source
  - `acquisition_source_skipped`: When user skips the question
  - `onboarding_completed`: Completion event with acquisition source included

### 3. PostHog Events Structure

#### acquisition_source_selected
```json
{
  "event": "acquisition_source_selected",
  "properties": {
    "source": "tiktok|youtube|instagram|app_store|google_search|website|friend_referral|reddit|other",
    "timestamp": "2024-01-15T10:30:00.000Z"
  }
}
```

#### acquisition_source_skipped
```json
{
  "event": "acquisition_source_skipped",
  "properties": {
    "timestamp": "2024-01-15T10:30:00.000Z"
  }
}
```

#### onboarding_completed
```json
{
  "event": "onboarding_completed",
  "properties": {
    "acquisition_source": "tiktok|youtube|...|skipped|not_provided",
    "goal": "lose|maintain|gain",
    "gender": "male|female",
    "age": 25,
    "activity_level": 1-5,
    "target_calories": 2000,
    "timestamp": "2024-01-15T10:35:00.000Z"
  }
}
```

## Onboarding Flow Changes

### Updated Page Indices
With the addition of the acquisition source page, all subsequent page indices have been shifted by +1:

| Page | Index (Old) | Index (New) | Description |
|------|------------|-------------|-------------|
| Welcome | 0 | 0 | No change |
| **Acquisition Source** | - | **1** | **New page** |
| Gender | 1 | 2 | Shifted +1 |
| Weight | 2 | 3 | Shifted +1 |
| Height | 3 | 4 | Shifted +1 |
| Age | 4 | 5 | Shifted +1 |
| Activity Level | 5 | 6 | Shifted +1 |
| Goal | 6 | 7 | Shifted +1 |
| Set New Goal | 7 | 8 | Shifted +1 |
| Advanced Settings | 8 | 9 | Shifted +1 |
| Apple Health | 9 | 10 | Shifted +1 |
| Summary | 10 | 11 | Shifted +1 |

### Total Pages
- **Previous**: 11 pages
- **Current**: 12 pages

## Analytics Insights Available

### Key Metrics to Track in PostHog

1. **Acquisition Source Distribution**
   ```sql
   SELECT 
     properties.source as acquisition_source,
     COUNT(*) as user_count
   FROM events 
   WHERE event = 'acquisition_source_selected'
   GROUP BY properties.source
   ORDER BY user_count DESC
   ```

2. **Onboarding Completion Rate by Source**
   ```sql
   SELECT 
     acquisition_source,
     COUNT(DISTINCT user_id) as completed_users
   FROM events 
   WHERE event = 'onboarding_completed'
   GROUP BY acquisition_source
   ORDER BY completed_users DESC
   ```

3. **Skip Rate**
   ```sql
   SELECT 
     COUNT(CASE WHEN event = 'acquisition_source_skipped' THEN 1 END) as skipped,
     COUNT(CASE WHEN event = 'acquisition_source_selected' THEN 1 END) as selected,
     ROUND(100.0 * COUNT(CASE WHEN event = 'acquisition_source_skipped' THEN 1 END) / 
           (COUNT(CASE WHEN event = 'acquisition_source_skipped' THEN 1 END) + 
            COUNT(CASE WHEN event = 'acquisition_source_selected' THEN 1 END)), 2) as skip_rate_percent
   FROM events 
   WHERE event IN ('acquisition_source_skipped', 'acquisition_source_selected')
   ```

4. **Goal Types by Acquisition Source**
   ```sql
   SELECT 
     acquisition_source,
     goal,
     COUNT(*) as user_count
   FROM events 
   WHERE event = 'onboarding_completed'
   GROUP BY acquisition_source, goal
   ORDER BY acquisition_source, user_count DESC
   ```

## PostHog Dashboard Recommendations

### 1. Acquisition Overview Dashboard
- **Pie Chart**: Source distribution
- **Bar Chart**: Users by source over time
- **Funnel**: Source selection → Onboarding completion

### 2. Source Performance Dashboard
- **Table**: Completion rates by source
- **Line Chart**: Source trends over time
- **Conversion funnel**: By acquisition source

### 3. User Behavior by Source
- **Heatmap**: Goal types by source
- **Bar Chart**: Average target calories by source
- **Comparison**: Demographics (age, gender) by source

## Technical Implementation Notes

### Files Modified
1. `lib/screens/onboarding/pages/acquisition_source_page.dart` - New page
2. `lib/screens/onboarding/onboarding_screen.dart` - Updated flow and tracking
3. `lib/screens/onboarding/pages/summary_page.dart` - Updated page indices

### Dependencies
- Uses existing `PostHogService` for analytics
- Uses existing `OnboardingSelectionCard` widget for UI consistency
- No additional dependencies required

## Privacy Considerations

- No personally identifiable information is collected with acquisition source
- Data is only used for analytics and marketing optimization
- Users can skip the question if they prefer not to answer
- Data is not stored in the app's database, only sent to PostHog

## Future Enhancements

1. **UTM Parameter Detection**: Automatically detect source from app store UTM parameters
2. **Referral Codes**: Add support for specific referral/promo codes
3. **A/B Testing**: Test different source options or page positioning
4. **Deep Link Attribution**: Track sources from deep link campaigns

## Monitoring

Monitor these metrics regularly in PostHog:
- Daily acquisition source selections
- Weekly source distribution trends
- Monthly conversion rates by source
- Seasonal variations in traffic sources

This data will help optimize marketing spend and identify the most effective user acquisition channels. 