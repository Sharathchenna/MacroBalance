//
//  StepsChart.swift
//  Runner
//
//  Created by Sharath Chenna on 3/21/25.
//

import SwiftUI
import Charts

struct StepsChartView: View {
    let entries: [StepsEntry]
    @Environment(\.colorScheme) var colorScheme
    
    var chartColor: Color {
        colorScheme == .dark ? Color(red: 0.31, green: 0.78, blue: 0.39) : Color(red: 0.21, green: 0.76, blue: 0.36)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading) {
                Text("Steps - Last 7 Days")
                    .font(.headline)
                    .foregroundColor(chartColor)
                
                Chart {
                    ForEach(entries) { entry in
                        BarMark(
                            x: .value("Day", entry.date, unit: .day),
                            y: .value("Steps", entry.steps)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [chartColor, chartColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(8)
                        
                        RuleMark(
                            y: .value("Goal", entry.goal)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .annotation(position: .trailing) {
                            Text("Goal: \(entry.goal)")
                                .font(.caption2)
                                .foregroundColor(.red)
                                .fontWeight(.bold)
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
                            if let steps = value.as(Int.self) {
                                Text("\(steps)")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(height: geometry.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
        .frame(height: 300)
    }
    
    var yAxisDomain: ClosedRange<Int> {
        if entries.isEmpty {
            return 0...10000
        }
        
        let steps = entries.map { $0.steps }
        let goals = entries.map { $0.goal }
        
        let maxSteps = steps.max() ?? 0
        let maxGoal = goals.max() ?? 0
        let maxValue = max(maxSteps, maxGoal)
        
        // Add 20% buffer
        let upperBound = Int(Double(maxValue) * 1.2)
        
        return 0...upperBound
    }
}

