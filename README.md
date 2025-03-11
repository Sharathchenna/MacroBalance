# Nutrino - Macro Tracking App

A modern, feature-rich macro and nutrition tracking application built with Flutter.

## Features

- 📊 Track daily macronutrients (proteins, carbs, fats)
- 📱 Cross-platform support (iOS, Android, macOS)
- 📸 AI-powered food recognition
- 🔄 Health app integration
- 🎯 Custom goal setting
- 📈 Progress tracking
- 🌙 Light/Dark theme support
- 🔐 Secure authentication
- ☁️ Cloud data sync

## Getting Started

### Prerequisites

- Flutter (latest version)
- Dart SDK
- Xcode (for iOS/macOS development)
- Android Studio (for Android development)
- An Apple Developer account (for iOS/macOS deployment)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/macrotracker.git
cd macrotracker
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Configuration

To use all features of the app, you'll need to set up:
- Supabase for backend services
- Google Sign-In credentials
- Apple Sign-In configuration
- PostHog for analytics

## Project Structure

```
lib/
├── AI/          # AI-related functionality
├── auth/        # Authentication logic
├── camera/      # Camera and image processing
├── Health/      # Health app integration
├── models/      # Data models
├── providers/   # State management
├── screens/     # UI screens
├── services/    # Backend services
├── theme/       # App theming
├── utils/       # Utility functions
└── widgets/     # Reusable widgets
```

## Development

This project follows Flutter best practices and uses:
- Provider for state management
- Supabase for backend services
- PostHog for analytics
- Google's Gemini AI for food recognition
- Custom UI components for a consistent experience

## Building for Production

### iOS
```bash
flutter build ios --release
```

### Android
```bash
flutter build apk --release
```

### macOS
```bash
flutter build macos --release
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the amazing framework
- Supabase for backend services
- PostHog for analytics
- All contributors and users of the app
