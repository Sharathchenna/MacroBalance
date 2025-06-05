# PRD: MacroTracker

## 1. Product overview
### 1.1 Document title and version
- PRD: MacroTracker
- Version: 1.0.0

### 1.2 Product summary
MacroTracker is a modern, feature-rich nutrition tracking application that helps users monitor their daily macronutrient intake, track fitness metrics, and achieve their health goals. 

The app combines intuitive tracking functionality with advanced features like AI-powered food recognition, health app integration, and customizable goal setting. With a subscription-based revenue model, MacroTracker offers a comprehensive solution for users who want to maintain balanced nutrition and track their fitness progress.

## 2. Goals
### 2.1 Business goals
- Create a sustainable subscription-based business model with RevenueCat integration
- Establish a competitive offering in the nutrition and fitness tracking market
- Achieve high user retention through valuable features and seamless experience
- Generate a steady revenue stream from paid subscriptions
- Build a scalable application that can support future feature expansions

### 2.2 User goals
- Track daily macronutrient intake (protein, carbs, fats) accurately and easily
- Set and monitor progress toward personalized nutrition and fitness goals
- Identify patterns and trends in nutrition habits over time
- Receive AI-powered assistance in food recognition and data entry
- Sync data with health apps for a complete fitness picture
- Access nutrition data across multiple devices

### 2.3 Non-goals
- Providing personalized nutrition or fitness advice that would require expert oversight
- Creating a social network for fitness or nutrition sharing
- Supporting offline-only functionality without cloud synchronization
- Developing a free tier with limited functionality (hard paywall approach)
- Serving as a general health or medical tracking application
- Supporting manual data export or import from competitive applications

## 3. User personas
### 3.1 Key user types
- Fitness enthusiasts tracking macros for performance goals
- Weight management users monitoring caloric and macronutrient intake
- Health-conscious individuals maintaining balanced nutrition
- Athletes requiring precise nutrition tracking for training
- Users with specific dietary requirements or restrictions

### 3.2 Basic persona details
- **Alex**: Fitness enthusiast who tracks macros to optimize muscle growth while maintaining a lean physique.
- **Jordan**: Working professional trying to lose weight by monitoring caloric intake and macronutrient balance.
- **Taylor**: Health-conscious parent maintaining balanced nutrition despite a busy schedule.
- **Morgan**: Athlete requiring precise nutrition tracking to support intensive training regimen.
- **Riley**: Individual with specific dietary requirements who needs to monitor particular nutritional values.

### 3.3 Role-based access
- **Subscribers**: Users who have purchased a subscription, with full access to all app features including AI-powered food recognition, health app integration, and cloud sync.
- **New Users**: First-time users who are presented with the onboarding experience and paywall before access to core functionality.
- **Returning Users**: Existing subscribers returning to the app with retained preferences and previously logged data.

## 4. Functional requirements
- **Macro Tracking** (Priority: High)
  - Allow users to log food intake with corresponding macronutrient values
  - Display daily totals for calories, protein, carbs, and fats
  - Show progress toward daily macro goals with visual indicators
  - Support for different meal types/times (breakfast, lunch, dinner, snacks)

- **AI-Powered Food Recognition** (Priority: High)
  - Enable users to take photos of food for automatic identification
  - Use Google's Gemini AI to accurately identify foods and portion sizes
  - Allow manual confirmation/adjustment of AI-identified foods
  - Maintain a history of frequently logged foods for quick access

- **Health App Integration** (Priority: Medium)
  - Sync nutrition data with Apple Health/Google Fit
  - Import weight, steps, and activity data from health platforms
  - Ensure seamless data flow between MacroTracker and health platforms
  - Support for HealthKit on iOS devices

- **Goal Setting and Progress Tracking** (Priority: High)
  - Allow users to set custom macronutrient goals (daily/weekly)
  - Provide visualizations of progress toward goals
  - Support weight tracking with trend analysis
  - Generate reports on nutrition habits and goal achievement

- **Data Synchronization** (Priority: High)
  - Enable cross-device synchronization via Supabase backend
  - Ensure real-time data updates across all user devices
  - Provide seamless user experience regardless of device used
  - Secure data storage and transfer

- **Subscription Management** (Priority: High)
  - Implement RevenueCat integration for subscription handling
  - Create clear and compelling paywall presentation
  - Process subscription purchases securely
  - Handle subscription validation and renewal

- **UI/UX Experience** (Priority: Medium)
  - Support light/dark theme switching
  - Provide intuitive navigation and data entry
  - Ensure accessibility compliance
  - Design responsive layouts for various device sizes

- **Widget and Notification Support** (Priority: Medium)
  - Create home screen widgets showing nutrition summaries
  - Send meaningful notifications about tracking reminders
  - Allow customization of notification preferences
  - Support for quick data entry from widgets

## 5. User experience
### 5.1. Entry points & first-time user flow
- User downloads app from App Store/Google Play
- Onboarding experience introduces key features and benefits
- User creates account via email, Google, or Apple authentication
- Subscription options presented via RevenueCat paywall
- After subscription, user sets up initial macronutrient goals
- Tutorial highlights quick-start features for immediate value

### 5.2. Core experience
- **Daily dashboard**: Users open the app to view current day's progress with macro breakdowns and visual charts for quick assessment.
  - Dashboard loads quickly and prominently displays current day's progress toward goals.
- **Food logging**: Users log meals by searching, scanning barcodes, or using AI image recognition.
  - The logging interface is streamlined to require minimal taps and offers multiple quick-entry methods.
- **Progress tracking**: Users view historical data through charts and visualizations to understand trends.
  - Charts load quickly and provide intuitive interactions for date range selection and detail viewing.
- **Goal adjustments**: Users can modify their nutrition goals as their needs change.
  - Goal-setting interfaces include helpful guidance on balanced nutrition while maintaining flexibility.

### 5.3. Advanced features & edge cases
- AI recognition handles complex mixed meals with multiple components
- Support for metric and imperial measurement units with seamless conversion
- Handling network connectivity issues with local caching and later synchronization
- Account recovery and data restoration procedures
- Performance optimization for users with extensive tracking history
- Support for different dietary patterns (keto, vegan, etc.) through custom goal setting

### 5.4. UI/UX highlights
- Clean, modern interface with intuitive navigation
- Visually appealing charts and progress indicators
- Thoughtful microinteractions that enhance usability
- Efficient data entry methods to minimize user friction
- Adaptive UI that responds to user preferences and habits
- Accessibility features for diverse user needs

## 6. Narrative
Jordan is a busy professional who wants to improve their health by tracking nutrition but finds most apps too complicated or time-consuming. They discover MacroTracker and appreciate its intuitive interface and AI-powered food recognition that makes logging meals quick and accurate. Jordan sets personalized macro goals based on their weight loss targets and enjoys seeing the clear visual progress toward daily goals. The app's integration with their health platform and the convenient widgets keep nutrition top-of-mind without becoming burdensome, making healthy eating feel achievable for the first time.

## 7. Success metrics
### 7.1. User-centric metrics
- Average daily active users (DAU) and monthly active users (MAU)
- Average session length and frequency
- User retention rates at 1 day, 7 days, 30 days, and 90 days
- Number of food entries logged per user per day
- Feature usage rates (AI recognition, health integration, etc.)
- User satisfaction scores from in-app feedback

### 7.2. Business metrics
- Subscription conversion rate from app download
- Monthly recurring revenue (MRR)
- Customer lifetime value (LTV)
- Subscription renewal rates
- Customer acquisition cost (CAC)
- Revenue growth month-over-month and year-over-year

### 7.3. Technical metrics
- App performance (load times, responsiveness)
- Crash rates and error frequency
- API response times and reliability
- Backend service uptime
- Data synchronization success rates
- AI recognition accuracy rates

## 8. Technical considerations
### 8.1. Integration points
- Supabase for backend services and data storage
- RevenueCat for subscription management
- Google's Gemini AI for food recognition
- Apple HealthKit and Google Fit for health data integration
- Firebase for messaging and notifications
- PostHog for analytics tracking

### 8.2. Data storage & privacy
- Secure user authentication through Supabase
- Encrypted data transmission for all user information
- GDPR and CCPA compliance for user data handling
- Clear privacy policy outlining data usage
- User control over data sharing with health platforms
- Secure storage of subscription and payment information

### 8.3. Scalability & performance
- Efficient database design to handle large tracking histories
- Optimized image processing for AI food recognition
- Caching strategies for frequent data access patterns
- Background synchronization to minimize perceived latency
- Resource-efficient widget implementations
- Performance monitoring and optimization pipeline

### 8.4. Potential challenges
- Maintaining AI recognition accuracy across diverse food types
- Ensuring reliable health platform integrations despite API changes
- Balancing feature richness with app performance
- Managing subscription-related user expectations
- Handling varied device capabilities for camera-based features
- Ensuring data consistency across synchronized devices

## 9. Milestones & sequencing
### 9.1. Project estimate
- Medium: 3-4 months for initial full-featured release

### 9.2. Team size & composition
- Medium Team: 5-7 total people
  - 1 Product manager
  - 2-3 Flutter developers
  - 1 Backend developer (Supabase)
  - 1 UI/UX designer
  - 1 QA specialist

### 9.3. Suggested phases
- **Phase 1**: Core functionality and authentication (4 weeks)
  - Key deliverables: User registration, login, basic food logging, simple macro tracking, daily summaries
- **Phase 2**: Advanced features and integrations (6 weeks)
  - Key deliverables: Health platform integration, AI food recognition, goal setting, progress visualization
- **Phase 3**: Subscription implementation and UI refinement (4 weeks)
  - Key deliverables: RevenueCat integration, paywall implementation, UI polish, widget support
- **Phase 4**: Testing, optimization, and launch preparation (2 weeks)
  - Key deliverables: Performance optimization, bug fixes, store listing preparation, initial marketing assets

## 10. User stories
### 10.1. User registration and authentication
- **ID**: US-001
- **Description**: As a new user, I want to create an account so that I can securely store my nutrition data.
- **Acceptance criteria**:
  - Users can register using email, Google, or Apple authentication
  - Registration fields include email, password, and basic profile information
  - Users receive confirmation of successful account creation
  - Error handling provides clear feedback for registration issues

### 10.2. Subscription purchase
- **ID**: US-002
- **Description**: As a new user, I want to purchase a subscription so that I can access all app features.
- **Acceptance criteria**:
  - Clear presentation of subscription options and benefits
  - Secure payment processing through RevenueCat
  - Confirmation of successful subscription purchase
  - Immediate access to premium features after purchase
  - Receipt of subscription confirmation via email

### 10.3. Setting macro goals
- **ID**: US-003
- **Description**: As a user, I want to set personalized macronutrient goals so that I can track my nutrition according to my specific needs.
- **Acceptance criteria**:
  - Interface for setting daily targets for calories, protein, carbs, and fat
  - Option to choose predefined goal templates (weight loss, muscle gain, etc.)
  - Ability to customize each macro individually
  - Visual confirmation of goal settings
  - Option to update goals at any time

### 10.4. Logging food manually
- **ID**: US-004
- **Description**: As a user, I want to manually log food items with their macronutrient values so that I can track my daily intake.
- **Acceptance criteria**:
  - Search functionality for common food items
  - Form for entering custom foods with macro values
  - Portion size adjustment options
  - Assignment to specific meal categories
  - Quick-add feature for frequently logged items

### 10.5. Using AI food recognition
- **ID**: US-005
- **Description**: As a user, I want to take photos of my food for automatic identification and logging so that I can save time on manual data entry.
- **Acceptance criteria**:
  - Camera interface for food photography
  - Visual indicators during AI processing
  - Display of recognized food items with confidence levels
  - Option to confirm or adjust AI suggestions
  - Addition of identified items to daily log after confirmation

### 10.6. Viewing daily progress
- **ID**: US-006
- **Description**: As a user, I want to see my progress toward daily macro goals so that I can make informed food choices.
- **Acceptance criteria**:
  - Dashboard showing current day's consumption vs. goals
  - Visual progress indicators for each macronutrient
  - Remaining macro allowances clearly displayed
  - Meal-by-meal breakdown available
  - Refresh mechanism to update with latest entries

### 10.7. Viewing historical data
- **ID**: US-007
- **Description**: As a user, I want to view my historical nutrition data so that I can identify patterns and track progress over time.
- **Acceptance criteria**:
  - Calendar interface for selecting dates to view
  - Charts showing trends over selected time periods
  - Weekly and monthly summary options
  - Ability to compare periods side by side
  - Export functionality for personal records

### 10.8. Syncing with health platforms
- **ID**: US-008
- **Description**: As a user, I want to connect with Apple Health/Google Fit so that my nutrition data integrates with my overall fitness tracking.
- **Acceptance criteria**:
  - Clear permission request for health platform access
  - Selection of data types to sync (nutrition, weight, etc.)
  - Bidirectional data flow where appropriate
  - Visual indicators of successful synchronization
  - Option to disconnect at any time

### 10.9. Using home screen widgets
- **ID**: US-009
- **Description**: As a user, I want to add widgets to my home screen so that I can quickly view my nutrition status without opening the app.
- **Acceptance criteria**:
  - Multiple widget size options
  - Display of current day's macro progress
  - Quick-add functionality from widgets
  - Regular background updates
  - Customization options for widget appearance

### 10.10. Tracking weight progress
- **ID**: US-010
- **Description**: As a user, I want to log and track my weight over time so that I can correlate it with my nutrition habits.
- **Acceptance criteria**:
  - Simple interface for entering weight data
  - Option for metric or imperial units
  - Graph visualization of weight trends
  - Integration with health platforms when connected
  - Statistical insights like moving averages

### 10.11. Managing subscription
- **ID**: US-011
- **Description**: As a subscriber, I want to manage my subscription settings so that I can update payment methods or change plans.
- **Acceptance criteria**:
  - View current subscription status and renewal date
  - Option to upgrade/downgrade plan if multiple tiers exist
  - Link to update payment information
  - Clear cancellation process
  - Information about what happens after cancellation

### 10.12. Receiving notifications
- **ID**: US-012
- **Description**: As a user, I want to receive relevant notifications so that I remember to log meals and stay on track with my nutrition goals.
- **Acceptance criteria**:
  - Customizable notification preferences
  - Meal reminder options at user-defined times
  - Progress updates for daily goal achievement
  - Non-intrusive delivery of notifications
  - Option to completely disable notifications

### 10.13. Switching theme modes
- **ID**: US-013
- **Description**: As a user, I want to switch between light and dark themes so that I can use the app comfortably in different lighting conditions.
- **Acceptance criteria**:
  - Accessible theme toggle in settings
  - Option to follow system theme
  - Immediate visual update when changed
  - Persistence of theme preference across sessions
  - Complete and consistent theme implementation across all screens

### 10.14. Account management
- **ID**: US-014
- **Description**: As a user, I want to manage my account settings so that I can update my profile information and preferences.
- **Acceptance criteria**:
  - Interface for updating name, email, and password
  - Option to link/unlink social authentication methods
  - Account deletion functionality with confirmation
  - Clear explanation of data handling after deletion
  - Success/error messaging for all account actions

### 10.15. Secure access and authentication
- **ID**: US-015
- **Description**: As a user, I want secure access to my nutrition data so that my personal information remains protected.
- **Acceptance criteria**:
  - Option to enable biometric authentication (fingerprint/face ID)
  - Automatic logout after extended inactivity
  - Secure token handling for API communications
  - Password reset functionality
  - Session management across multiple devices 