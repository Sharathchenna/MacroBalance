import WidgetKit
import SwiftUI
import Intents
import os.log

// Define the data structure for macro nutrition data
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
    
    // Add a computed property to check if the data is from today
    var isFromToday: Bool {
        let dataDate = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        return Calendar.current.isDateInToday(dataDate)
    }
}

// Structure for a single meal entry
struct MealEntry: Codable, Identifiable {
    let name: String
    let calories: Double
    let meal: String
    let timestamp: Int64
    
    var id: String { "\(name)_\(timestamp)" }
    
    // Check if the meal is from today
    var isFromToday: Bool {
        let mealDate = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        return Calendar.current.isDateInToday(mealDate)
    }
}

// Timeline entry for the widget
struct MacroWidgetEntry: TimelineEntry {
    let date: Date
    let macroData: MacroData?
    let recentMeals: [MealEntry]?
    let isPreview: Bool
}

// Provider that delivers timeline entries
struct Provider: TimelineProvider {
    // Use the correct app group identifier that matches the Flutter side
    private let userDefaults = UserDefaults(suiteName: "group.com.sharathchenna.shared")
    private let logger = Logger(subsystem: "com.sharathchenna88.nutrino", category: "Widget")
    
    func placeholder(in context: Context) -> MacroWidgetEntry {
        // Preview data
        let previewMacro = MacroData(
            calories: 1200,
            caloriesGoal: 2000,
            protein: 80,
            proteinGoal: 150,
            carbs: 120,
            carbsGoal: 225,
            fat: 40,
            fatGoal: 65,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )
        
        let previewMeals: [MealEntry] = [
            MealEntry(name: "Grilled Chicken Salad", calories: 350, meal: "Lunch", timestamp: Int64(Date().timeIntervalSince1970 * 1000)),
            MealEntry(name: "Protein Shake", calories: 180, meal: "Breakfast", timestamp: Int64(Date().timeIntervalSince1970 * 1000))
        ]
        
        return MacroWidgetEntry(date: Date(), macroData: previewMacro, recentMeals: previewMeals, isPreview: true)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (MacroWidgetEntry) -> Void) {
        let entry: MacroWidgetEntry
        
        if context.isPreview {
            entry = placeholder(in: context)
        } else {
            let macroData = loadMacroData()
            let meals = loadRecentMeals()
            
            entry = MacroWidgetEntry(date: Date(), macroData: macroData, recentMeals: meals, isPreview: false)
        }
        
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<MacroWidgetEntry>) -> Void) {
        let currentDate = Date()
        
        logger.log("🔄 MacroTracker Widget: Starting getTimeline")
        
        // Calculate next midnight for reset
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        guard let nextMidnight = calendar.nextDate(after: currentDate, matching: components, matchingPolicy: .nextTime) else {
            // If we can't determine next midnight, use default 15-minute refresh
            let defaultRefresh = calendar.date(byAdding: .minute, value: 15, to: currentDate)!
            logger.log("⚠️ Could not determine midnight, using 15-minute refresh")
            createTimelineWithRefreshDate(currentDate: currentDate, refreshDate: defaultRefresh, completion: completion)
            return
        }
        
        // Create multiple timeline entries
        var entries: [MacroWidgetEntry] = []
        
        // Current entry
        let macroData = loadMacroData()
        let meals = loadRecentMeals()
        let currentEntry = MacroWidgetEntry(date: currentDate, macroData: macroData, recentMeals: meals, isPreview: false)
        entries.append(currentEntry)
        
        // Also add an entry for a short refresh (for example, 15 minutes)
        if let shortRefresh = calendar.date(byAdding: .minute, value: 15, to: currentDate) {
            if shortRefresh < nextMidnight {
                let shortRefreshEntry = MacroWidgetEntry(date: shortRefresh, macroData: macroData, recentMeals: meals, isPreview: false)
                entries.append(shortRefreshEntry)
            }
        }
        
        // Add midnight entry with empty data to force reset
        let midnightEntry = MacroWidgetEntry(date: nextMidnight, macroData: nil, recentMeals: [], isPreview: false)
        entries.append(midnightEntry)
        
        // Enhanced logging
        logger.log("🔄 Widget timeline created with \(entries.count) entries")
        logger.log("⏰ Next refresh scheduled at: \(entries.last?.date.description ?? "unknown")")
        
        // Check if we have data to display
        if let macroData = entries.first?.macroData {
            logger.log("✅ Widget has macro data: calories=\(macroData.calories), goal=\(macroData.caloriesGoal)")
        } else {
            logger.log("⚠️ Widget has NO macro data")
        }
        
        if let meals = entries.first?.recentMeals, !meals.isEmpty {
            logger.log("✅ Widget has \(meals.count) meals")
        } else {
            logger.log("⚠️ Widget has NO meal data")
        }
        
        // Set up policy to reload after midnight
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func createTimelineWithRefreshDate(currentDate: Date, refreshDate: Date, completion: @escaping (Timeline<MacroWidgetEntry>) -> Void) {
        let macroData = loadMacroData()
        let meals = loadRecentMeals()
        
        let entry = MacroWidgetEntry(date: currentDate, macroData: macroData, recentMeals: meals, isPreview: false)
        
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func loadMacroData() -> MacroData? {
        logger.log("🔍 Loading macro data from UserDefaults")
        
        // Try to load macro data from app group UserDefaults
        if let data = userDefaults?.string(forKey: "macro_data") {
            logger.log("Found macro_data in App Group UserDefaults")
            if let macroData = decodeMacroData(from: data) {
                if macroData.isFromToday {
                    logger.log("✅ Successfully loaded today's macro data")
                    return macroData
                } else {
                    logger.log("⚠️ Found macro data but it's not from today")
                }
            } else {
                logger.log("❌ Failed to decode macro_data")
            }
        } else {
            logger.log("macro_data not found in App Group UserDefaults")
        }
        
        // If app group fails, try standard UserDefaults as fallback
        if let data = UserDefaults.standard.string(forKey: "macro_data") {
            logger.log("Found macro_data in standard UserDefaults")
            if let macroData = decodeMacroData(from: data), macroData.isFromToday {
                logger.log("✅ Successfully loaded macro data from standard UserDefaults")
                return macroData
            }
        }
        
        // If no direct key found, look for anything with "macro" in the name
        if let appGroupDefaults = userDefaults {
            for key in appGroupDefaults.dictionaryRepresentation().keys {
                if key.contains("macro") {
                    logger.log("Trying potential macro key: \(key)")
                    if let data = appGroupDefaults.string(forKey: key),
                       let macroData = decodeMacroData(from: data),
                       macroData.isFromToday {
                        logger.log("✅ Found usable macro data in alternate key: \(key)")
                        return macroData
                    }
                }
            }
        }
        
        logger.log("❌ No valid macro data found in any UserDefaults for today")
        return nil
    }
    
    private func decodeMacroData(from jsonString: String) -> MacroData? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            logger.log("Failed to convert macro string to data")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(MacroData.self, from: jsonData)
        } catch {
            logger.log("Error decoding macro data: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func loadRecentMeals() -> [MealEntry]? {
        logger.log("🔍 Loading meal data from UserDefaults")
        
        // Try to load meal data from app group UserDefaults
        if let data = userDefaults?.string(forKey: "daily_meals") {
            logger.log("Found daily_meals in App Group UserDefaults")
            if let meals = decodeMeals(from: data) {
                // Filter to only include today's meals
                let todayMeals = meals.filter { $0.isFromToday }
                logger.log("✅ Found \(todayMeals.count) meals for today")
                return todayMeals
            } else {
                logger.log("❌ Failed to decode daily_meals")
            }
        } else {
            logger.log("daily_meals not found in App Group UserDefaults")
        }
        
        // If app group fails, try standard UserDefaults as fallback
        if let data = UserDefaults.standard.string(forKey: "daily_meals") {
            logger.log("Found daily_meals in standard UserDefaults")
            if let meals = decodeMeals(from: data) {
                let todayMeals = meals.filter { $0.isFromToday }
                logger.log("✅ Found \(todayMeals.count) meals in standard UserDefaults")
                return todayMeals
            }
        }
        
        // If no direct key found, look for anything with "meal" in the name
        if let appGroupDefaults = userDefaults {
            for key in appGroupDefaults.dictionaryRepresentation().keys {
                if key.contains("meal") {
                    logger.log("Trying potential meal key: \(key)")
                    if let data = appGroupDefaults.string(forKey: key),
                       let meals = decodeMeals(from: data) {
                        let todayMeals = meals.filter { $0.isFromToday }
                        if !todayMeals.isEmpty {
                            logger.log("✅ Found \(todayMeals.count) meals in alternate key: \(key)")
                            return todayMeals
                        }
                    }
                }
            }
        }
        
        logger.log("❌ No meal data found for today")
        return nil
    }
    
    private func decodeMeals(from jsonString: String) -> [MealEntry]? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            logger.log("Failed to convert meals string to data")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([MealEntry].self, from: jsonData)
        } catch {
            logger.log("Error decoding meals data: \(error.localizedDescription)")
            return nil
        }
    }
}

struct MacroWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    // Design constants for consistency
    let appName = "Nutrino"
    let accentColor = Color.orange
    let progressHeight: CGFloat = 6
    let progressCornerRadius: CGFloat = 6
    let secondaryTextSize: CGFloat = 11
    let percentageBadgeSize: CGFloat = 18
    
    var body: some View {
        VStack {
            switch family {
            case .systemSmall:
                smallWidget
            case .systemMedium:
                mediumWidget
            case .systemLarge:
                largeWidget
            default:
                smallWidget
            }
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 0)
        .widgetBackground(backgroundGradient)
        .widgetURL(URL(string: "nutrino:///dashboard"))
    }
    
    // Modern gradient background
    var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white.opacity(0.95),
                colorScheme == .dark ? Color(hex: "111111") : Color.white.opacity(0.90)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            // Subtle pattern overlay
            Rectangle()
                .fill(
                    Color.primary.opacity(colorScheme == .dark ? 0.03 : 0.02)
                )
                .allowsHitTesting(false)
        )
    }
    
    // Shared percentage badge view for consistency
    func percentageBadge(for macroData: MacroData) -> some View {
        let percentage = Int(min(macroData.calories / macroData.caloriesGoal * 100, 100))
        return ZStack {
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: percentageBadgeSize, height: percentageBadgeSize)
            
            Text("\(percentage)%")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(accentColor)
        }
    }
    
    // Shared progress bar for consistency
    func progressBar(for macroData: MacroData, maxWidth: CGFloat) -> some View {
        let progress = min(CGFloat(macroData.calories / macroData.caloriesGoal), 1.0)
        
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: progressCornerRadius)
                .fill(accentColor.opacity(0.15))
                .frame(height: progressHeight)
            
            RoundedRectangle(cornerRadius: progressCornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [accentColor, accentColor.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(progress * maxWidth, 5), height: progressHeight)
        }
    }
    
    // Header view with app name and icon for consistency
    func headerView() -> some View {
        HStack {
            Text(appName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(accentColor)
            
            Spacer()
            
            Image(systemName: "flame.fill")
                .foregroundColor(accentColor)
                .font(.system(size: 12))
        }
    }
    
    var smallWidget: some View {
        ZStack {
            // Content container with subtle shadow
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.5))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 10) {
                headerView()
                
                if let macroData = entry.macroData {
                    Spacer()
                    
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(Int(macroData.calories))")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("/ \(Int(macroData.caloriesGoal))")
                            .font(.system(size: secondaryTextSize, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.leading, -2)
                    }
                    
                    Text("calories")
                        .font(.system(size: secondaryTextSize))
                        .foregroundColor(.secondary)
                        .padding(.top, -8)
                    
                    Spacer()
                    
                    // Progress bar
                    progressBar(for: macroData, maxWidth: 120)
                    
                    HStack {
                        Text("Daily Goal")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        percentageBadge(for: macroData)
                    }
                } else {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        VStack(spacing: 5) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 20))
                                .foregroundColor(accentColor.opacity(0.8))
                            
                            Text("No data today")
                                .font(.system(size: secondaryTextSize, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
            .padding(12)
        }
        .padding(4)
    }
    
    var mediumWidget: some View {
        ZStack {
            // Content container with subtle shadow
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.5))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    headerView()
                    
                    Spacer()
                    
                    if let macroData = entry.macroData {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(accentColor)
                                .font(.system(size: 12))
                            
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text("\(Int(macroData.calories))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("/\(Int(macroData.caloriesGoal))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                if let macroData = entry.macroData {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily calories")
                                .font(.system(size: secondaryTextSize, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            // Progress bar
                            progressBar(for: macroData, maxWidth: 150)
                        }
                        
                        Spacer()
                        
                        percentageBadge(for: macroData)
                    }
                    
                    HStack(spacing: 16) {
                        MacroCircleView(
                            value: macroData.protein,
                            goal: macroData.proteinGoal,
                            color: .green,
                            label: "Protein"
                        )
                        
                        Spacer()
                        
                        MacroCircleView(
                            value: macroData.carbs,
                            goal: macroData.carbsGoal,
                            color: .blue,
                            label: "Carbs"
                        )
                        
                        Spacer()
                        
                        MacroCircleView(
                            value: macroData.fat,
                            goal: macroData.fatGoal,
                            color: .yellow,
                            label: "Fat"
                        )
                    }
                } else {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        VStack(spacing: 5) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 24))
                                .foregroundColor(accentColor.opacity(0.8))
                            
                            Text("No data recorded today")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
            .padding(14)
        }
        .padding(4)
    }
    
    var largeWidget: some View {
        ZStack {
            // Content container with subtle shadow
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.5))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(appName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(accentColor)
                    
                    Spacer()
                    
                    Text(Date(), style: .date)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                if let macroData = entry.macroData {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(Int(macroData.calories))")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Text("/\(Int(macroData.caloriesGoal))")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("calories")
                                .font(.system(size: secondaryTextSize))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        percentageBadge(for: macroData)
                    }
                    
                    // Progress bar
                    progressBar(for: macroData, maxWidth: 280)
                        .padding(.vertical, 4)
                    
                    // Macro nutrients display
                    HStack(spacing: 20) {
                        MacroCircleView(
                            value: macroData.protein,
                            goal: macroData.proteinGoal,
                            color: .green,
                            label: "Protein"
                        )
                        
                        Spacer()
                        
                        MacroCircleView(
                            value: macroData.carbs,
                            goal: macroData.carbsGoal,
                            color: .blue,
                            label: "Carbs"
                        )
                        
                        Spacer()
                        
                        MacroCircleView(
                            value: macroData.fat,
                            goal: macroData.fatGoal,
                            color: .yellow,
                            label: "Fat"
                        )
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("Today's Meals")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let meals = entry.recentMeals, !meals.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(meals.prefix(3)) { meal in
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 6))
                                        .foregroundColor(accentColor)
                                    
                                    Text(meal.name)
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(meal.calories)) kcal")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(colorScheme == .dark ? Color.gray.opacity(0.15) : Color.gray.opacity(0.08))
                                )
                                .widgetURL(URL(string: "nutrino:///dashboard"))
                            }
                        }
                    } else {
                        HStack {
                            Spacer()
                            Text("No meals recorded today")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 10)
                            Spacer()
                        }
                    }
                } else {
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 30))
                            .foregroundColor(accentColor.opacity(0.8))
                        
                        Text("No data recorded today")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("Tap to open \(appName)")
                            .font(.system(size: 12))
                            .foregroundColor(accentColor)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Spacer()
                }
            }
            .padding(16)
        }
        .padding(4)
    }
}

// New and improved MacroCircleView
struct MacroCircleView: View {
    let value: Double
    let goal: Double
    let color: Color
    let label: String
    
    var progress: Double {
        min(value / max(goal, 1.0), 1.0)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background track
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 4)
                
                // Progress
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                // Value
                VStack(spacing: 0) {
                    Text("\(Int(value))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("g")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40, height: 40)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
        }
        .widgetURL(URL(string: "nutrino:///dashboard"))
    }
}

// Helper extension for hex colors
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

struct MacroTrackerWidgets: WidgetBundle {
    var body: some Widget {
        MacroTrackerWidget()
    }
}

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
        .description("Track your daily macros at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

extension View {
    @ViewBuilder
    func widgetBackground(_ background: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                background
            }
        } else {
            self.background(background)
        }
    }
}

struct MacroTrackerWidget_Previews: PreviewProvider {
    static var previews: some View {
        let previewMacro = MacroData(
            calories: 1200,
            caloriesGoal: 2000,
            protein: 80,
            proteinGoal: 150,
            carbs: 120,
            carbsGoal: 225,
            fat: 40,
            fatGoal: 65,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000)
        )
        
        let previewMeals: [MealEntry] = [
            MealEntry(name: "Grilled Chicken Salad", calories: 350, meal: "Lunch", timestamp: Int64(Date().timeIntervalSince1970 * 1000)),
            MealEntry(name: "Protein Shake", calories: 180, meal: "Breakfast", timestamp: Int64(Date().timeIntervalSince1970 * 1000))
        ]
        
        let entry = MacroWidgetEntry(date: Date(), macroData: previewMacro, recentMeals: previewMeals, isPreview: true)
        
        return Group {
            MacroWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            
            MacroWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
            
            MacroWidgetEntryView(entry: entry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
