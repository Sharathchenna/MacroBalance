//
//  CaloriesChart.swift
//  Runner
//
//  Created by Sharath Chenna on 3/21/25.
//

import SwiftUI
import Charts

struct CaloriesChartView: View {
    let calorieEntries: [Models.CaloriesEntry] // Renamed for clarity
    let macroEntries: [Models.MacrosEntry] // Add macro entries
    @State private var selectedCalorieEntry: Models.CaloriesEntry? // Renamed
    @State private var highlightedDate: Date?
    @State private var showingMacroBreakdown = false
    @Environment(\.colorScheme) var colorScheme
    
    var chartColor: Color {
        colorScheme == .dark ? Color.red : Color.red.opacity(0.8)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Calories - Last 7 Days")
                        .font(.headline)
                        .foregroundColor(chartColor)
                    
                    Spacer()
                    
                    Menu {
                        Button("Show Weekly Avg", action: { /* Action */ })
                        Button("Show Monthly Trend", action: { /* Action */ })
                        Button("Show Goal Line", action: { /* Action */ })
                        Divider()
                        Button("Customize Chart", action: { /* Action */ })
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.gray)
                    }
                }
                
                // Enhanced chart with tooltip and interactive elements
                Chart {
                    ForEach(calorieEntries) { entry in // Use calorieEntries
                        LineMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("Calories", entry.calories)
                        )
                        .foregroundStyle(chartColor.gradient)
                        .interpolationMethod(.catmullRom)
                        .symbolSize(highlightedDate == entry.date ? 100 : 0)
                        
                        AreaMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("Calories", entry.calories)
                        )
                        .foregroundStyle(chartColor.opacity(0.2).gradient)
                        .interpolationMethod(.catmullRom)
                        
                        // Add burned calories line if available
                        if entry.burned > 0 {
                            LineMark(
                                x: .value("Day", entry.date, unit: .day),
                                y: .value("Burned", entry.burned)
                            )
                            .foregroundStyle(Color.orange.opacity(0.7).gradient)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        }
                        
                        // Goal line with label
                        RuleMark(
                            y: .value("Goal", entry.goal)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                        .foregroundStyle(Color.blue.opacity(0.6))
                        .annotation(position: .trailing) {
                            Text("Goal: \(Int(entry.goal))")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    // Display selected point if any
                    if let selected = selectedCalorieEntry { // Use selectedCalorieEntry
                        PointMark(
                            x: .value("Day", selected.date, unit: .day),
                            y: .value("Calories", selected.calories)
                        )
                        .foregroundStyle(Color.white)
                        .symbolSize(80)
                    }
                }
                .chartYScale(domain: yAxisDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if let date = value.as(Date.self) {
                            AxisGridLine()
                            AxisValueLabel {
                                Text(date, format: .dateTime.weekday(.abbreviated))
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let calories = value.as(Double.self) {
                                Text("\(Int(calories))")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(height: geometry.size.height * 0.7)
                .chartOverlay { proxy in
                    GeometryReader { geoProxy in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let xPosition = value.location.x
                                        guard let date = proxy.value(atX: xPosition, as: Date.self) else { return }
                                        
                                        // Find closest date in data
                                        if let closestEntry = findClosestCalorieEntry(to: date) { // Renamed helper
                                            highlightedDate = closestEntry.date
                                            selectedCalorieEntry = closestEntry // Update selectedCalorieEntry
                                        }
                                    }
                                    .onEnded { _ in
                                        // Keep highlighted for better UX
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            // You could choose to clear selection after delay or keep it
                                            // highlightedDate = nil
                                            // selectedCalorieEntry = nil
                                        }
                                    }
                            )
                    }
                }
                
                // Display selected data details
                if let selected = selectedCalorieEntry { // Use selectedCalorieEntry
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading) {
                            Text(selected.date, format: .dateTime.month().day())
                                .font(.subheadline.bold())
                            
                            Text("\(Int(selected.calories)) calories")
                                .font(.headline)
                                .foregroundColor(chartColor)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            // Add goal difference
                            let diff = selected.goal - selected.calories
                            let isUnder = diff > 0
                            
                            HStack {
                                Image(systemName: isUnder ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                    .foregroundColor(isUnder ? .green : .red)
                                
                                Text("\(abs(Int(diff))) \(isUnder ? "under" : "over") goal")
                                    .font(.subheadline)
                                    .foregroundColor(isUnder ? .green : .red)
                            }
                            
                            if selected.burned > 0 {
                                Text("Burned: \(Int(selected.burned)) cal")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            showingMacroBreakdown = true
                        } label: {
                            Text("Details")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .transition(.opacity)
                } else {
                    // Summary view when nothing is selected
                    let avgCalories = calorieEntries.isEmpty ? 0 : calorieEntries.map { $0.calories }.reduce(0, +) / Double(calorieEntries.count) // Use calorieEntries
                    let maxCaloriesEntry = calorieEntries.max(by: { $0.calories < $1.calories }) // Use calorieEntries
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Average")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(avgCalories)) cal")
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        if let maxEntry = maxCaloriesEntry {
                            VStack(alignment: .leading) {
                                Text("Highest Day")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(maxEntry.calories)) cal")
                                    .font(.headline)
                            }
                        }
                        
                        Spacer()
                        
                        // Weekly total
                        let totalCalories = calorieEntries.map { $0.calories }.reduce(0, +) // Use calorieEntries
                        VStack(alignment: .leading) {
                            Text("Weekly Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(totalCalories)) cal")
                                .font(.headline)
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .sheet(isPresented: $showingMacroBreakdown) {
                // Find the corresponding MacrosEntry for the selected CaloriesEntry date
                if let selectedCalEntry = selectedCalorieEntry,
                   let macroEntry = macroEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedCalEntry.date) }) {
                    MacroBreakdownView(entry: macroEntry) // Pass MacrosEntry
                } else {
                    // Optional: Show an error or empty state if no macro data found
                    Text("Macro details not available for this date.")
                }
            }
        }
        .frame(height: 400) // Increased height to accommodate new elements
    }
    
    // Helper function to find the closest entry to a given date
    private func findClosestCalorieEntry(to date: Date) -> Models.CaloriesEntry? { // Renamed
        guard !calorieEntries.isEmpty else { return nil } // Use calorieEntries
        
        return calorieEntries.min(by: { // Use calorieEntries
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }
    
    var yAxisDomain: ClosedRange<Double> {
        if calorieEntries.isEmpty { // Use calorieEntries
            return 0...2500
        }
        
        let calories = calorieEntries.map { $0.calories } // Use calorieEntries
        let goals = calorieEntries.map { $0.goal } // Use calorieEntries
        let burned = calorieEntries.map { $0.burned } // Use calorieEntries
        
        let maxCalories = calories.max() ?? 0
        let maxGoal = goals.max() ?? 0
        let maxBurned = burned.max() ?? 0
        let maxValue = max(maxCalories, max(maxGoal, maxBurned))
        
        // Add 20% buffer
        let upperBound = maxValue * 1.2
        
        return 0...upperBound
    }
}

// Updated view for macro breakdown using MacrosEntry
struct MacroBreakdownView: View {
    let entry: Models.MacrosEntry // Changed to MacrosEntry
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Calories Breakdown") {
                    HStack {
                        Text("Total Calories")
                        Spacer()
                        Text("\(Int(entry.calories))") // Use calories from MacrosEntry
                    }
                    
                    // Removed consumed/burned as they might not be directly in MacrosEntry
                    // Add them back if your MacrosEntry model includes them
                    
                    HStack {
                        Text("Daily Goal")
                        Spacer()
                        Text("\(Int(entry.calorieGoal))") // Use calorieGoal from MacrosEntry
                    }
                    
                    let remaining = entry.calorieGoal - entry.calories
                    HStack {
                        Text(remaining >= 0 ? "Remaining" : "Exceeded")
                        Spacer()
                        Text("\(abs(Int(remaining)))")
                            .foregroundColor(remaining >= 0 ? .green : .red)
                    }
                }
                
                // Display actual meals if available
                if let meals = entry.meals, !meals.isEmpty {
                    Section("Meals") {
                        ForEach(meals.sorted(by: { $0.time < $1.time })) { meal in
                            HStack {
                                Text(meal.name)
                                Spacer()
                                Text("\(Int(meal.calories)) cal")
                            }
                        }
                    }
                } else {
                     Section("Time of Day") {
                         Text("No meal data available for this day.")
                             .foregroundColor(.secondary)
                     }
                }
                
                Section("Macronutrients") {
                    // Use actual macro data from MacrosEntry
                    HStack {
                        Text("Protein")
                        Spacer()
                        Text("\(Int(entry.proteins))g (\(Int(entry.proteinPercentage))%)")
                    }
                    
                    HStack {
                        Text("Carbs")
                        Spacer()
                        Text("\(Int(entry.carbs))g (\(Int(entry.carbsPercentage))%)")
                    }
                    
                    HStack {
                        Text("Fats")
                        Spacer()
                        Text("\(Int(entry.fats))g (\(Int(entry.fatsPercentage))%)")
                    }
                }
            }
            .navigationTitle(Text(entry.date, format: .dateTime.month().day().year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
