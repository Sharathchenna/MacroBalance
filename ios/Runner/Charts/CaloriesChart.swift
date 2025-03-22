//
//  CaloriesChart.swift
//  Runner
//
//  Created by Sharath Chenna on 3/21/25.
//

import SwiftUI
import Charts

struct CaloriesChartView: View {
    let entries: [CaloriesEntry]
    @Environment(\.colorScheme) var colorScheme
    
    var chartColor: Color {
        colorScheme == .dark ? Color.red : Color.red.opacity(0.8)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading) {
                Text("Calories - Last 7 Days")
                    .font(.headline)
                    .foregroundColor(chartColor)
                
                Chart {
                    ForEach(entries) { entry in
                        LineMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("Calories", entry.calories)
                        )
                        .foregroundStyle(chartColor.gradient)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("Calories", entry.calories)
                        )
                        .foregroundStyle(chartColor.opacity(0.2).gradient)
                        .interpolationMethod(.catmullRom)
                        
                        RuleMark(
                            y: .value("Goal", entry.goal)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                        .foregroundStyle(Color.blue.opacity(0.6))
                        .annotation(position: .trailing) {
                            Text("Goal: \(Int(entry.goal))")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
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
                .frame(height: geometry.size.height * 0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
        .frame(height: 300)
    }
    
    var yAxisDomain: ClosedRange<Double> {
        if entries.isEmpty {
            return 0...2500
        }
        
        let calories = entries.map { $0.calories }
        let goals = entries.map { $0.goal }
        
        let maxCalories = calories.max() ?? 0
        let maxGoal = goals.max() ?? 0
        let maxValue = max(maxCalories, maxGoal)
        
        // Add 20% buffer
        let upperBound = maxValue * 1.2
        
        return 0...upperBound
    }
}