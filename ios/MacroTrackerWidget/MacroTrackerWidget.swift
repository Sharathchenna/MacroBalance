import WidgetKit
import SwiftUI
import Intents
import os.log

// MARK: - Data Models

struct MacroData: Codable {
    let calories: Double
    let caloriesGoal: Double
    let protein: Double
    let proteinGoal: Double
    let carbs: Double
    let carbsGoal: Double
    let fat: Double
    let fatGoal: Double
    let timestamp: Int64
    
    var isFromToday: Bool {
        let dataDate = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        return Calendar.current.isDateInToday(dataDate)
    }
    
    // Added computed properties for percentage calculations
    var caloriesPercentage: Double { min(calories / max(caloriesGoal, 1), 1.0) }
    var proteinPercentage: Double { min(protein / max(proteinGoal, 1), 1.0) }
    var carbsPercentage: Double { min(carbs / max(carbsGoal, 1), 1.0) }
    var fatPercentage: Double { min(fat / max(fatGoal, 1), 1.0) }
}

struct MealEntry: Codable, Identifiable {
    let name: String
    let calories: Double
    let meal: String
    let timestamp: Int64
    
    var id: String { "\(name)_\(timestamp)" }
    
    var isFromToday: Bool {
        let mealDate = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        return Calendar.current.isDateInToday(mealDate)
    }
    
    // Added computed property for meal time display
    var formattedTime: String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Timeline Entry

struct MacroWidgetEntry: TimelineEntry {
    let date: Date
    let macroData: MacroData?
    let recentMeals: [MealEntry]?
    let isPreview: Bool
}

// MARK: - Provider

struct Provider: TimelineProvider {
    private let userDefaults = UserDefaults(suiteName: "group.com.sharathchenna.shared")
    private let logger = Logger(subsystem: "com.sharathchenna88.nutrino", category: "Widget")
    
    func placeholder(in context: Context) -> MacroWidgetEntry {
        let previewMacro = MacroData(
            calories: 1200, caloriesGoal: 2000,
            protein: 80, proteinGoal: 150,
            carbs: 120, carbsGoal: 225,
            fat: 40, fatGoal: 65,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )
        
        let previewMeals: [MealEntry] = [
            MealEntry(name: "Grilled Chicken Salad", calories: 350, meal: "Lunch", timestamp: Int64(Date().timeIntervalSince1970 * 1000 - 3600000)),
            MealEntry(name: "Protein Shake", calories: 180, meal: "Breakfast", timestamp: Int64(Date().timeIntervalSince1970 * 1000 - 28800000))
        ]
        
        return MacroWidgetEntry(date: Date(), macroData: previewMacro, recentMeals: previewMeals, isPreview: true)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (MacroWidgetEntry) -> Void) {
        let entry = context.isPreview ? placeholder(in: context) : 
            MacroWidgetEntry(date: Date(), macroData: loadMacroData(), recentMeals: loadRecentMeals(), isPreview: false)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<MacroWidgetEntry>) -> Void) {
        let currentDate = Date()
        logger.log("🔄 Nutrino Widget: Starting timeline refresh")
        
        // Calculate next refresh times
        let calendar = Calendar.current
        var nextRefreshDate = calendar.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate
        
        // Find midnight for daily reset
        var components = DateComponents()
        components.day = 1
        components.hour = 0
        components.minute = 0
        
        if let nextMidnight = calendar.nextDate(after: currentDate, matching: components, matchingPolicy: .nextTime) {
            nextRefreshDate = nextMidnight
            logger.log("⏰ Next refresh scheduled at midnight: \(nextMidnight)")
        }
        
        // Create entries
        let macroData = loadMacroData()
        let meals = loadRecentMeals()
        
        if let macroData = macroData {
            logger.log("✅ Widget loaded data: \(Int(macroData.calories))/\(Int(macroData.caloriesGoal)) calories")
        }
        
        let entry = MacroWidgetEntry(date: currentDate, macroData: macroData, recentMeals: meals, isPreview: false)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefreshDate))
        
        completion(timeline)
    }
    
    private func loadMacroData() -> MacroData? {
        if let data = userDefaults?.string(forKey: "macro_data"),
           let macroData = decodeMacroData(from: data),
           macroData.isFromToday {
            return macroData
        }
        return nil
    }
    
    private func loadRecentMeals() -> [MealEntry]? {
        if let data = userDefaults?.string(forKey: "daily_meals"),
           let meals = decodeMeals(from: data) {
            return meals.filter { $0.isFromToday }
        }
        return nil
    }
    
    private func decodeMacroData(from jsonString: String) -> MacroData? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(MacroData.self, from: jsonData)
        } catch {
            logger.log("❌ Error decoding macro data: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func decodeMeals(from jsonString: String) -> [MealEntry]? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode([MealEntry].self, from: jsonData)
        } catch {
            logger.log("❌ Error decoding meals: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Widget Views

struct MacroWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                ModernSmallWidget(entry: entry)
            case .systemMedium:
                ModernMediumWidget(entry: entry)
            case .systemLarge:
                ModernLargeWidget(entry: entry)
            default:
                ModernSmallWidget(entry: entry)
            }
        }
        .widgetBackground(background)
    }
    
    @ViewBuilder
    var background: some View {
        if colorScheme == .dark {
            Color(UIColor.systemBackground)
        } else {
            Color.white
        }
    }
}

// MARK: - Design Constants
struct DesignSystem {
    static let colors = ThemeColors(
        primary: Color(hex: "FF6B6B"),
        secondary: Color(hex: "4ECDC4"),
        accent: Color(hex: "45B7D1"),
        background: Color(hex: "1A1B1E"),
        surface: Color(hex: "2A2B2E")
    )
    
    static let gradients = ThemeGradients(
        primary: LinearGradient(
            colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        accent: LinearGradient(
            colors: [Color(hex: "45B7D1"), Color(hex: "4ECDC4")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
    
    static let animation = Animation.spring(response: 0.4, dampingFraction: 0.8)
}

struct ThemeColors {
    let primary: Color
    let secondary: Color
    let accent: Color
    let background: Color
    let surface: Color
}

struct ThemeGradients {
    let primary: LinearGradient
    let accent: LinearGradient
}

// Small widget
struct ModernSmallWidget: View {
    let entry: Provider.Entry
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            // Modern header with icon
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DesignSystem.gradients.primary)
                
                Text("Nutrino")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DesignSystem.gradients.primary)
                
                Spacer()
            }
            
            if let macroData = entry.macroData {
                // Circular progress indicator
                ZStack {
                    Circle()
                        .stroke(DesignSystem.colors.accent.opacity(0.2), lineWidth: 8)
                        .frame(width: 90, height: 90)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(macroData.caloriesPercentage))
                        .stroke(
                            DesignSystem.gradients.primary,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Text("\(Int(macroData.calories))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("/ \(Int(macroData.caloriesGoal))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                // Goal completion badge
                HStack {
                    Text("Daily Progress")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(macroData.caloriesPercentage * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignSystem.gradients.primary)
                }
            } else {
                Spacer()
                
                VStack(spacing: 8) {
                    Image(systemName: "flame")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.colors.accent.opacity(0.8))
                    
                    Text("No data yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Tap to log your first meal")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
    }
}

// Medium widget
struct ModernMediumWidget: View {
    let entry: Provider.Entry
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 20) {
            // Left section with calories
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DesignSystem.gradients.primary)
                    
                    Text("Nutrino")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DesignSystem.gradients.primary)
                    
                    Spacer()
                }
                
                if let macroData = entry.macroData {
                    // Main calorie display
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Calories")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(macroData.calories))")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("/ \(Int(macroData.caloriesGoal))")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        
                        // Progress bar with modern design
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(DesignSystem.colors.accent.opacity(0.15))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(DesignSystem.gradients.primary)
                                .frame(width: max(CGFloat(macroData.caloriesPercentage) * 160, 6), height: 6)
                        }
                        
                        Text("\(Int(macroData.caloriesPercentage * 100))% Complete")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DesignSystem.gradients.primary)
                    }
                } else {
                    EmptyStateView(message: "Start tracking")
                }
            }
            .frame(maxWidth: .infinity)
            
            // Right section with macro circles
            if let macroData = entry.macroData {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        ModernMacroProgress(
                            value: macroData.protein,
                            goal: macroData.proteinGoal,
                            color: .green,
                            icon: "dumbbell.fill",
                            label: "Protein"
                        )
                        
                        ModernMacroProgress(
                            value: macroData.carbs,
                            goal: macroData.carbsGoal,
                            color: .blue,
                            icon: "leaf.fill",
                            label: "Carbs"
                        )
                        
                        ModernMacroProgress(
                            value: macroData.fat,
                            goal: macroData.fatGoal,
                            color: .yellow,
                            icon: "drop.fill",
                            label: "Fat"
                        )
                    }
                }
            }
        }
        .padding(16)
    }
}

// Optimized large widget with fixes for zooming issues
struct ModernLargeWidget: View {
    let entry: Provider.Entry
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 8) {
                    // App branding
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(DesignSystem.gradients.primary)
                        
                        Text("Nutrino")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(DesignSystem.gradients.primary)
                    }
                    
                    Spacer()
                    
                    // Date display
                    Text(Date(), style: .date)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 4)
                
                if let macroData = entry.macroData {
                    // Main content
                    VStack(spacing: 16) {
                        // Calories section
                        HStack(alignment: .center, spacing: 16) {
                            // Left side - Calorie info
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Daily Calories")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(Int(macroData.calories))")
                                        .font(.system(size: 32, weight: .bold))
                                    
                                    Text("/ \(Int(macroData.caloriesGoal))")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                // Progress bar
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(DesignSystem.colors.accent.opacity(0.15))
                                        .frame(height: 8)
                                    
                                    Capsule()
                                        .fill(DesignSystem.gradients.primary)
                                        .frame(width: max(CGFloat(macroData.caloriesPercentage) * (geometry.size.width * 0.5), 8), height: 8)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Right side - Progress circle
                            ZStack {
                                Circle()
                                    .stroke(DesignSystem.colors.accent.opacity(0.15), lineWidth: 6)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .trim(from: 0, to: CGFloat(macroData.caloriesPercentage))
                                    .stroke(
                                        DesignSystem.gradients.primary,
                                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                    )
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                
                                VStack(spacing: 2) {
                                    Text("\(Int(macroData.caloriesPercentage * 100))%")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(DesignSystem.gradients.primary)
                                    
                                    Text("of goal")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Macronutrients section
                        HStack(spacing: 12) {
                            ForEach([(macroData.protein, macroData.proteinGoal, "Protein", "dumbbell.fill", Color.green),
                                    (macroData.carbs, macroData.carbsGoal, "Carbs", "leaf.fill", Color.blue),
                                    (macroData.fat, macroData.fatGoal, "Fat", "drop.fill", Color.yellow)], id: \.2) { item in
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .stroke(item.4.opacity(0.15), lineWidth: 4)
                                            .frame(width: 46, height: 46)
                                        
                                        Circle()
                                            .trim(from: 0, to: CGFloat(min(item.0 / max(item.1, 1), 1.0)))
                                            .stroke(
                                                item.4,
                                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                            )
                                            .frame(width: 46, height: 46)
                                            .rotationEffect(.degrees(-90))
                                        
                                        Image(systemName: item.3)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(item.4)
                                    }
                                    
                                    VStack(spacing: 2) {
                                        Text("\(Int(item.0))g")
                                            .font(.system(size: 14, weight: .bold))
                                        
                                        Text(item.2)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        
                        // Distribution bar
                        VStack(spacing: 6) {
                            GeometryReader { barGeometry in
                                HStack(spacing: 0) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                        .frame(width: barGeometry.size.width * CGFloat(macroData.protein / (macroData.protein + macroData.carbs + macroData.fat)))
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue)
                                        .frame(width: barGeometry.size.width * CGFloat(macroData.carbs / (macroData.protein + macroData.carbs + macroData.fat)))
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.yellow)
                                        .frame(width: barGeometry.size.width * CGFloat(macroData.fat / (macroData.protein + macroData.carbs + macroData.fat)))
                                }
                            }
                            .frame(height: 8)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            
                            // Distribution legend
                            HStack(spacing: 12) {
                                ForEach([
                                    ("P", Color.green, macroData.protein),
                                    ("C", Color.blue, macroData.carbs),
                                    ("F", Color.yellow, macroData.fat)
                                ], id: \.0) { item in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(item.1)
                                            .frame(width: 6, height: 6)
                                        
                                        Text("\(item.0): \(Int(round(item.2 / (macroData.protein + macroData.carbs + macroData.fat) * 100)))%")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(item.1)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                } else {
                    Spacer()
                    SmallEmptyStateView(message: "Start tracking your nutrition")
                    Spacer()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}


    
    private func calculateMacroBalance(protein: Double, carbs: Double, fat: Double) -> (status: String, message: String, icon: String, color: Color) {
        let values = [protein, carbs, fat]
        let avg = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - avg, 2) }.reduce(0, +) / Double(values.count)
        
        if variance < 0.05 {
            return ("Balanced", "Good macro ratio", "checkmark.circle", .green)
        } else if variance < 0.1 {
            return ("Decent", "Adjust slightly", "arrow.triangle.2.circlepath", .blue) 
        } else {
            if protein < carbs && protein < fat {
                return ("Low Protein", "Increase protein", "dumbbell.fill", .orange)
            } else if carbs < protein && carbs < fat {
                return ("Low Carbs", "Increase carbs", "leaf.fill", .orange)
            } else {
                return ("Low Fat", "Increase healthy fats", "drop.fill", .orange)
            }
        }
    }


// Optimized compact distribution bar
struct CompactMacroDistributionBar: View {
    let protein: Double
    let carbs: Double
    let fat: Double
    
    private var total: Double {
        protein + carbs + fat
    }
    
    private var proteinPortion: CGFloat {
        total > 0 ? CGFloat(protein / total) : 0.33
    }
    
    private var carbsPortion: CGFloat {
        total > 0 ? CGFloat(carbs / total) : 0.33
    }
    
    private var fatPortion: CGFloat {
        total > 0 ? CGFloat(fat / total) : 0.33
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Compact distribution bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Protein section
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: geometry.size.width * proteinPortion)
                    
                    // Carbs section
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * carbsPortion)
                    
                    // Fat section
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.yellow)
                        .frame(width: geometry.size.width * fatPortion)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(height: 10)
            }
            .frame(height: 10)
            
            // Compact legend
            HStack(spacing: 16) {
                // Protein
                HStack(spacing: 2) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    
                    Text("P: \(Int(round(proteinPortion * 100)))%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.green)
                        .minimumScaleFactor(0.8)
                }
                
                // Carbs
                HStack(spacing: 2) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                    
                    Text("C: \(Int(round(carbsPortion * 100)))%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.blue)
                        .minimumScaleFactor(0.8)
                }
                
                // Fat
                HStack(spacing: 2) {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 6, height: 6)
                    
                    Text("F: \(Int(round(fatPortion * 100)))%")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.yellow)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// Optimized mini insight card
struct MiniInsightCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .minimumScaleFactor(0.8)
                
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                    .minimumScaleFactor(0.8)
                
                Text(subtitle)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer()
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

// Standard macro distribution bar (for reference)
struct MacroDistributionBar: View {
    let protein: Double
    let carbs: Double
    let fat: Double
    
    private var total: Double {
        protein + carbs + fat
    }
    
    private var proteinPortion: CGFloat {
        total > 0 ? CGFloat(protein / total) : 0.33
    }
    
    private var carbsPortion: CGFloat {
        total > 0 ? CGFloat(carbs / total) : 0.33
    }
    
    private var fatPortion: CGFloat {
        total > 0 ? CGFloat(fat / total) : 0.33
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Distribution bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 12)
                
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: proteinPortion >= 0.98 ? 6 : 0)
                            .fill(Color.green)
                            .frame(width: max(geometry.size.width * proteinPortion, 0))
                        
                        RoundedRectangle(cornerRadius: carbsPortion >= 0.98 ? 6 : 0)
                            .fill(Color.blue)
                            .frame(width: max(geometry.size.width * carbsPortion, 0))
                        
                        RoundedRectangle(cornerRadius: fatPortion >= 0.98 ? 6 : 0)
                            .fill(Color.yellow)
                            .frame(width: max(geometry.size.width * fatPortion, 0))
                    }
                    .frame(height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(height: 12)
            }
            
            // Legend
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("Protein \(Int(round(proteinPortion * 100)))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                    
                    Text("Carbs \(Int(round(carbsPortion * 100)))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 8, height: 8)
                    
                    Text("Fat \(Int(round(fatPortion * 100)))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }
}

// Compact macro item component
struct MiniMacroItem: View {
    let value: Double
    let goal: Double
    let color: Color
    let icon: String
    let label: String
    let percentage: Double
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: CGFloat(percentage))
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.8)
            
            Text("\(Int(value))g")
                .font(.system(size: 14, weight: .bold))
                .minimumScaleFactor(0.8)
            
            Text("\(Int(percentage * 100))%")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// Modern macro progress for medium widget
struct ModernMacroProgress: View {
    let value: Double
    let goal: Double
    let color: Color
    let icon: String
    let label: String
    
    private var percentage: Double {
        min(value / max(goal, 1), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: CGFloat(percentage))
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
            }
            .frame(width: 40, height: 40)
            
            VStack(spacing: 2) {
                Text("\(Int(value))g")
                    .font(.system(size: 12, weight: .bold))
                    .minimumScaleFactor(0.8)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

// Empty state views
struct EmptyStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 28))
                .foregroundColor(DesignSystem.colors.accent.opacity(0.8))
            
            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SmallEmptyStateView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 20))
                .foregroundColor(DesignSystem.colors.accent.opacity(0.8))
            
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Helper Extensions
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// View extension for widget background
extension View {
    @ViewBuilder
    func widgetBackground(_ background: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                ZStack {
                    background
                    
                    // Add subtle gradient overlay
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.05),
                            Color.cyan.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        } else {
            self.background(
                ZStack {
                    background
                    
                    // Add subtle gradient overlay
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.05),
                            Color.cyan.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
        }
    }
}

// MARK: - Widget Configuration
struct MacroTrackerWidget: Widget {
    private let kind = "MacroTrackerWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: Provider()
        ) { entry in
            MacroWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Nutrino")
        .description("Track your daily nutrition at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct MacroTrackerWidgets: WidgetBundle {
    var body: some Widget {
        MacroTrackerWidget()
    }
}
