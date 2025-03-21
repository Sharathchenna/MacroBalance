import SwiftUI
import Charts

struct MacrosEntry {
    let date: Date
    let proteins: Double
    let carbs: Double
    let fats: Double
    let proteinGoal: Double
    let carbGoal: Double
    let fatGoal: Double
}

// Color extension to match the image style
extension Color {
    static let proteinColor = Color(red: 0.98, green: 0.76, blue: 0.34) // Golden yellow
    static let carbColor = Color(red: 0.35, green: 0.78, blue: 0.71) // Teal green
    static let fatColor = Color(red: 0.56, green: 0.27, blue: 0.68) // Purple
}

struct MacrosChartView: View {
    let entries: [MacrosEntry]
    @State private var selectedDay: MacrosEntry?
    @Environment(\.colorScheme) var colorScheme
    
    private var weekDays: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE" // Single letter day
        return entries.map { formatter.string(from: $0.date) }
    }
    
    private var dateLabels: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return entries.map { formatter.string(from: $0.date) }
    }
    
    private var averages: (protein: Double, carbs: Double, fat: Double) {
        guard !entries.isEmpty else { return (0, 0, 0) }
        let totalProteins = entries.reduce(0) { $0 + $1.proteins }
        let totalCarbs = entries.reduce(0) { $0 + $1.carbs }
        let totalFats = entries.reduce(0) { $0 + $1.fats }
        return (
            protein: totalProteins / Double(entries.count),
            carbs: totalCarbs / Double(entries.count),
            fat: totalFats / Double(entries.count)
        )
    }
    
    private var goals: (protein: Double, carbs: Double, fat: Double) {
        guard let firstEntry = entries.first else { return (0, 0, 0) }
        return (
            protein: firstEntry.proteinGoal,
            carbs: firstEntry.carbGoal,
            fat: firstEntry.fatGoal
        )
    }
    
    private var averagePercentages: (protein: Double, carbs: Double, fat: Double) {
        let total = averages.protein + averages.carbs + averages.fat
        guard total > 0 else { return (0, 0, 0) }
        return (
            protein: (averages.protein / total) * 100,
            carbs: (averages.carbs / total) * 100,
            fat: (averages.fat / total) * 100
        )
    }
    
    private var goalPercentages: (protein: Double, carbs: Double, fat: Double) {
        let total = goals.protein + goals.carbs + goals.fat
        guard total > 0 else { return (0, 0, 0) }
        return (
            protein: (goals.protein / total) * 100,
            carbs: (goals.carbs / total) * 100,
            fat: (goals.fat / total) * 100
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if #available(iOS 16.0, *) {
                macrosChartView
                    .frame(height: 220)
                    .padding(.top, 20)
                Spacer(minLength: 16)
                macrosStatsView
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                // Fallback for iOS < 16
                Text("Charts require iOS 16 or later")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white)
    }
    
    @available(iOS 16.0, *)
    private var macrosChartView: some View {
        Chart(entries.indices, id: \.self) { index in
            let entry = entries[index]
            
            BarMark(
                x: .value("Day", index),
                y: .value("Proteins", entry.proteins),
                stacking: .standard
            )
            .foregroundStyle(Color.proteinColor)
            .annotation(position: .automatic) {
                if index == entries.count - 1 {
                    Text("Protein")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            BarMark(
                x: .value("Day", index),
                y: .value("Fats", entry.fats),
                stacking: .standard
            )
            .foregroundStyle(Color.fatColor)
            .annotation(position: .automatic) {
                if index == entries.count - 1 {
                    Text("Fat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            BarMark(
                x: .value("Day", index),
                y: .value("Carbs", entry.carbs),
                stacking: .standard
            )
            .foregroundStyle(Color.carbColor)
            .annotation(position: .automatic) {
                if index == entries.count - 1 {
                    Text("Carbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    private var macrosStatsView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Avg")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Goal")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Carbs stats
            HStack {
                HStack {
                    ColorSquare(color: .carbColor)
                    Text("Net Carbs (\(Int(averages.carbs))g)")
                        .font(.subheadline)
                }
                Spacer()
                Text("\(Int(averagePercentages.carbs))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(goalPercentages.carbs))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            // Fats stats
            HStack {
                HStack {
                    ColorSquare(color: .fatColor)
                    Text("Fat (\(Int(averages.fat))g)")
                        .font(.subheadline)
                }
                Spacer()
                Text("\(Int(averagePercentages.fat))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(goalPercentages.fat))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            // Protein stats
            HStack {
                HStack {
                    ColorSquare(color: .proteinColor)
                    Text("Protein (\(Int(averages.protein))g)")
                        .font(.subheadline)
                }
                Spacer()
                Text("\(Int(averagePercentages.protein))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(goalPercentages.protein))%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
        }
    }
}

struct ColorSquare: View {
    let color: Color
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 14, height: 14)
    }
} 