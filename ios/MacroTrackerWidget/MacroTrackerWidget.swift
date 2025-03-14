import WidgetKit
import SwiftUI
import Intents

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
}

// Structure for a single meal entry
struct MealEntry: Codable, Identifiable {
    let name: String
    let calories: Double
    let meal: String
    let timestamp: Int64
    
    var id: String { "\(name)_\(timestamp)" }
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
    private let userDefaults = UserDefaults(suiteName: "group.com.sharathchenna88.nutrino")
    
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
            timestamp: Int64(Date().timeIntervalSince1970)
        )
        
        let previewMeals: [MealEntry] = [
            MealEntry(name: "Grilled Chicken Salad", calories: 350, meal: "Lunch", timestamp: Int64(Date().timeIntervalSince1970)),
            MealEntry(name: "Protein Shake", calories: 180, meal: "Breakfast", timestamp: Int64(Date().timeIntervalSince1970))
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
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        let macroData = loadMacroData()
        let meals = loadRecentMeals()
        
        let entry = MacroWidgetEntry(date: currentDate, macroData: macroData, recentMeals: meals, isPreview: false)
        
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func loadMacroData() -> MacroData? {
        // First try from userDefaults provided by home_widget
        if let data = userDefaults?.string(forKey: "macro_data") {
            return decodeMacroData(from: data)
        }
        
        // If that failed, try from standard UserDefaults as fallback
        if let data = UserDefaults.standard.string(forKey: "macro_data") {
            return decodeMacroData(from: data)
        }
        
        print("No macro data found in UserDefaults")
        return nil
    }
    
    private func decodeMacroData(from jsonString: String) -> MacroData? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Failed to convert macro string to data")
            return nil
        }
        
        do {
            return try JSONDecoder().decode(MacroData.self, from: jsonData)
        } catch {
            print("Error decoding macro data: \(error)")
            return nil
        }
    }
    
    private func loadRecentMeals() -> [MealEntry]? {
        // First try from userDefaults provided by home_widget
        if let data = userDefaults?.string(forKey: "daily_meals") {
            return decodeMeals(from: data)
        }
        
        // If that failed, try from standard UserDefaults as fallback
        if let data = UserDefaults.standard.string(forKey: "daily_meals") {
            return decodeMeals(from: data)
        }
        
        print("No meal data found in UserDefaults")
        return nil
    }
    
    private func decodeMeals(from jsonString: String) -> [MealEntry]? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("Failed to convert meals string to data")
            return nil
        }
        
        do {
            return try JSONDecoder().decode([MealEntry].self, from: jsonData)
        } catch {
            print("Error decoding meals data: \(error)")
            return nil
        }
    }
}

struct MacroWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
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
        .widgetBackground(Color(UIColor.systemBackground).opacity(0.9))
    }
    
    var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nutrino")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.orange)
            
            Spacer()
            
            if let macroData = entry.macroData {
                Text("\(Int(macroData.calories))/\(Int(macroData.caloriesGoal))")
                    .font(.system(size: 20, weight: .bold))
                + Text(" kcal")
                    .font(.system(size: 12))
                
                ProgressView(value: min(macroData.calories / macroData.caloriesGoal, 1.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
            } else {
                Text("No data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Tap to open")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(12)
    }
    
    var mediumWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Nutrino")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.orange)
                
                Spacer()
                
                if let macroData = entry.macroData {
                    Text("\(Int(macroData.calories))/\(Int(macroData.caloriesGoal)) kcal")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            
            if let macroData = entry.macroData {
                HStack(spacing: 12) {
                    MacroRingView(
                        value: macroData.protein,
                        goal: macroData.proteinGoal,
                        color: .green,
                        label: "Protein"
                    )
                    
                    MacroRingView(
                        value: macroData.carbs,
                        goal: macroData.carbsGoal,
                        color: .blue,
                        label: "Carbs"
                    )
                    
                    MacroRingView(
                        value: macroData.fat,
                        goal: macroData.fatGoal,
                        color: .yellow,
                        label: "Fat"
                    )
                }
            } else {
                Text("No data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
    }
    
    var largeWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrino")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.orange)
            
            if let macroData = entry.macroData {
                HStack {
                    Text("\(Int(macroData.calories))")
                        .font(.system(size: 24, weight: .bold))
                    + Text(" / \(Int(macroData.caloriesGoal)) kcal")
                        .font(.system(size: 16))
                    
                    Spacer()
                }
                
                ProgressView(value: min(macroData.calories / macroData.caloriesGoal, 1.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                
                HStack(spacing: 20) {
                    MacroRingView(
                        value: macroData.protein,
                        goal: macroData.proteinGoal,
                        color: .green,
                        label: "Protein"
                    )
                    
                    MacroRingView(
                        value: macroData.carbs,
                        goal: macroData.carbsGoal,
                        color: .blue,
                        label: "Carbs"
                    )
                    
                    MacroRingView(
                        value: macroData.fat,
                        goal: macroData.fatGoal,
                        color: .yellow,
                        label: "Fat"
                    )
                }
                
                Divider()
                
                Text("Today's Meals")
                    .font(.system(size: 14, weight: .semibold))
                
                if let meals = entry.recentMeals, !meals.isEmpty {
                    ForEach(meals.prefix(3)) { meal in
                        HStack {
                            Text(meal.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(Int(meal.calories)) kcal")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text("No meals recorded today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No data yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
    }
}

struct MacroRingView: View {
    let value: Double
    let goal: Double
    let color: Color
    let label: String
    
    var progress: Double {
        min(value / max(goal, 1.0), 1.0)
    }
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 5)
                
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(color, lineWidth: 5)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(Int(value))")
                        .font(.system(size: 12, weight: .bold))
                    
                    Text("g")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 45)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
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
            self.background(background) // Corrected line
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
            timestamp: Int64(Date().timeIntervalSince1970)
        )
        
        let previewMeals: [MealEntry] = [
            MealEntry(name: "Grilled Chicken Salad", calories: 350, meal: "Lunch", timestamp: Int64(Date().timeIntervalSince1970)),
            MealEntry(name: "Protein Shake", calories: 180, meal: "Breakfast", timestamp: Int64(Date().timeIntervalSince1970))
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