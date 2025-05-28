# Premium Design System - MacroTracker

## 🎨 Enhanced Color Palette

Our premium design system uses a sophisticated slate-based color scheme with carefully selected accent colors:

### Core Colors
```dart
// Primary Colors
static const Color primaryBlack = Color(0xFF000000);
static const Color white = Color(0xFFFFFFFF);

// Slate Scale (Main Color System)
static const Color slate900 = Color(0xFF0F172A);  // Ultra dark - Headers
static const Color slate800 = Color(0xFF1E293B);  // Dark backgrounds
static const Color slate700 = Color(0xFF334155);  // Medium dark accents
static const Color slate600 = Color(0xFF475569);  // Text on light backgrounds
static const Color slate500 = Color(0xFF64748B);  // Subtle text
static const Color slate400 = Color(0xFF94A3B8);  // Placeholder text
static const Color slate300 = Color(0xFFCBD5E1);  // Borders
static const Color slate200 = Color(0xFFE2E8F0);  // Light borders
static const Color slate100 = Color(0xFFF1F5F9);  // Background sections
static const Color slate50 = Color(0xFFF8FAFC);   // Card backgrounds
static const Color zinc50 = Color(0xFFFAFAFA);    // Main background
```

### Accent Colors (Use Sparingly)
```dart
// Success
static const Color emerald500 = Color(0xFF10B981);
static const Color emerald50 = Color(0xFFECFDF5);

// Error
static const Color red500 = Color(0xFFEF4444);
static const Color red50 = Color(0xFFFEF2F2);

// Info/Primary Actions
static const Color blue500 = Color(0xFF3B82F6);
static const Color blue50 = Color(0xFFEFF6FF);
```

## 🔤 Typography System

Using **Inter** font family for a clean, modern, and highly readable interface:

### Hierarchy
```dart
// Headlines
static TextStyle h1 = GoogleFonts.inter(
  fontSize: 36,
  fontWeight: FontWeight.w800,
  letterSpacing: -1.0,
  color: slate900,
);

static TextStyle h2 = GoogleFonts.inter(
  fontSize: 28,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.5,
  color: slate900,
);

static TextStyle h3 = GoogleFonts.inter(
  fontSize: 24,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.3,
  color: slate800,
);

static TextStyle h4 = GoogleFonts.inter(
  fontSize: 20,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.2,
  color: slate800,
);

// Body Text
static TextStyle bodyLarge = GoogleFonts.inter(
  fontSize: 16,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.1,
  color: slate700,
);

static TextStyle bodyMedium = GoogleFonts.inter(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  letterSpacing: 0.2,
  color: slate600,
);

// UI Elements
static TextStyle button = GoogleFonts.inter(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.5,
);

static TextStyle subtitle = GoogleFonts.inter(
  fontSize: 16,
  fontWeight: FontWeight.w400,
  letterSpacing: 0.3,
  color: slate500,
);

static TextStyle caption = GoogleFonts.inter(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.5,
  color: slate500,
);
```

## 🎯 Usage Guidelines

### Background Colors
- **Main Background**: `slate100` - Light, subtle background
- **Card Backgrounds**: `white` - Clean, elevated surfaces
- **Input Fields**: `slate100` - Subtle input backgrounds

### Text Colors
- **Primary Text**: `slate900` - High contrast for headings
- **Secondary Text**: `slate700` - Body text with good readability
- **Subtle Text**: `slate500` - Less important information
- **Placeholder Text**: `slate400` - Form placeholders

### Border Colors
- **Light Borders**: `slate200` - Subtle separations
- **Defined Borders**: `slate300` - More prominent borders

### Interactive Elements
- **Primary Actions**: `primaryBlack` - Bold, confident actions
- **Secondary Actions**: `white` with `slate300` border
- **Success States**: `emerald500`
- **Error States**: `red500`

## 🚀 Implementation Benefits

1. **Professional Appearance**: Clean, modern aesthetic that conveys quality
2. **Excellent Readability**: Carefully chosen contrast ratios
3. **Consistent Hierarchy**: Clear visual hierarchy guides user attention
4. **Accessibility**: High contrast ratios for better accessibility
5. **Scalability**: Comprehensive system supports future features
6. **Brand Consistency**: Cohesive visual language across the app

## 📱 Applied In
- Workout Planning Screen (`lib/screens/workout_planning_screen.dart`)
- Enhanced snackbars, dialogs, cards, and navigation elements
- Typography system for all text elements
- Color-coded difficulty indicators and status badges

## 🔄 Next Steps
1. Apply this system to other screens in the app
2. Create reusable component library with these styles
3. Consider dark mode variations using the same color scale
4. Test accessibility compliance with screen readers

---

*This design system creates a premium, professional user experience while maintaining excellent usability and accessibility.* 