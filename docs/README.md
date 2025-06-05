# MacroTracker - AI-Powered Fitness App

A comprehensive fitness tracking application with AI-powered workout recommendations, real exercise data from ExerciseDB, and personalized nutrition guidance.

## 🚀 Features

### 🤖 AI-Powered Workouts
- **ExerciseDB Integration**: Access to 1000+ real exercises with GIF demonstrations
- **Personalized Recommendations**: AI-curated workouts based on fitness level and available equipment
- **Smart Exercise Alternatives**: Intelligent substitutions for equipment limitations or injuries
- **Progressive Training**: AI adapts workouts based on your progress and performance

### 💪 Exercise Database
- Real exercise data with proper form instructions
- GIF animations for visual guidance
- Equipment-based filtering
- Muscle group targeting
- Difficulty progression

### 📊 Nutrition Tracking
- Macro counting with AI assistance
- Personalized nutrition goals
- Food database with barcode scanning
- Progress tracking and analytics

### 🎯 Smart Features
- Fitness profile assessment
- Weekly workout scheduling
- Progress analytics
- Equipment-based workout customization

## 🛠️ Setup Instructions

### Prerequisites
- Flutter SDK (^3.6.0)
- Firebase project setup
- ExerciseDB API key (optional but recommended)

### 1. Clone the Repository
```bash
git clone <repository-url>
cd macrotracker
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure ExerciseDB API (Recommended)

#### Get Your API Key
1. Visit [RapidAPI ExerciseDB](https://rapidapi.com/justin-WFnsXH_t6/api/exercisedb)
2. Sign up for a free account
3. Subscribe to the ExerciseDB API (free tier available)
4. Copy your API key

#### Configure the API Key
Edit `lib/config/api_config.dart`:

```dart
class ApiConfig {
  // Replace with your actual RapidAPI key
  static const String exerciseDbApiKey = 'YOUR_ACTUAL_API_KEY_HERE';
  
  // ... rest of the configuration
}
```

### 4. Firebase Setup

#### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Enable Authentication and Firestore
4. Download configuration files

#### Configure Firebase
- **Android**: Place `google-services.json` in `android/app/`
- **iOS**: Place `GoogleService-Info.plist` in `ios/Runner/`

#### Enable Vertex AI
1. In Firebase Console, go to Vertex AI
2. Enable the service
3. Configure Gemini 2.0 Flash model

### 5. Run the Application
```bash
flutter run
```

## 🔧 Configuration Options

### ExerciseDB Integration
The app provides a fallback system:
- **With API Key**: Full access to 1000+ exercises with GIFs
- **Without API Key**: Uses built-in exercise database with static images

### AI Features
- **Enhanced Mode**: Full AI integration with real exercise data
- **Basic Mode**: Standard AI recommendations with local exercise database

## 📱 Usage

### Setting Up Your Profile
1. Complete the onboarding flow
2. Set your fitness level and goals
3. Specify available equipment
4. Choose workout preferences

### Getting AI Workout Recommendations
1. Navigate to Workouts tab
2. Tap "Generate AI Workout"
3. Customize muscle groups and duration
4. Follow the generated workout plan

### Using Exercise Alternatives
1. During any workout, tap on an exercise
2. Select "Find Alternatives"
3. Choose based on equipment or difficulty
4. AI will suggest appropriate substitutions

## 🏗️ Architecture

### Services
- **ExerciseImageService**: Manages exercise data and images from ExerciseDB
- **FitnessAIService**: AI-powered workout generation and recommendations
- **FitnessDataService**: User profile and progress tracking

### AI Integration
```
User Profile + Preferences
        ↓
ExerciseDB API (Real Exercises)
        ↓
AI Processing (Gemini 2.0)
        ↓
Personalized Workout Plan
```

### Fallback System
```
ExerciseDB API → Local Database → Category Images → Placeholder
```

## 🔒 Privacy & Security

- User data is stored securely in Firebase
- API keys are managed through configuration files
- No exercise data is cached beyond session limits
- User preferences are encrypted locally

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📝 API Rate Limits

### ExerciseDB API
- **Free Tier**: 50 requests/minute
- **Pro Tier**: 500 requests/minute
- **Cached Results**: Reduces API calls automatically

### Optimization Features
- Intelligent caching system
- Request rate limiting
- Fallback to local data when needed

## 🐛 Troubleshooting

### Common Issues

#### ExerciseDB API Not Working
1. Verify your API key in `api_config.dart`
2. Check your RapidAPI subscription status
3. Ensure you haven't exceeded rate limits
4. App will fallback to local database automatically

#### Firebase Connection Issues
1. Check your Firebase configuration files
2. Verify project settings in Firebase Console
3. Ensure Vertex AI is enabled

#### App Performance
1. Clear app cache if experiencing slow loading
2. Check internet connection for API features
3. Restart app if AI features aren't responding

## 📞 Support

For technical support or feature requests:
- Create an issue in the repository
- Check existing documentation
- Review the troubleshooting section

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- **ExerciseDB**: Comprehensive exercise database with professional demonstrations
- **Firebase**: Backend infrastructure and AI services
- **Flutter**: Cross-platform mobile development framework
- **RapidAPI**: API marketplace and management platform

---

**Ready to transform your fitness journey with AI? Get started today!** 🚀💪
