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
        colorScheme == .dark ? Color.blue : Color.blue.opacity(0.8)
    }
    
    var averageSteps: Int {
        guard !entries.isEmpty else { return 0 }
        return Int(Double(entries.reduce(0) { $0 + $1.steps }) / Double(entries.count))
    }
    
    var totalSteps: Int {
        entries.reduce(0) { $0 + $1.steps }
    }
    
    var goalCompletionRate: Double {
        guard !entries.isEmpty else { return 0 }
        let completedDays = entries.filter { $0.steps >= $0.goal }.count
        return Double(completedDays) / Double(entries.count) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stats Summary Cards
            HStack(spacing: 12) {
                StatCard(title: "Daily Average",
                        value: "\(averageSteps.formattedWithCommas)",
                        subtitle: "steps",
                        color: .blue)
                
                StatCard(title: "Goal Rate",
                        value: "\(Int(goalCompletionRate))%",
                        subtitle: "completion",
                        color: .green)
                
                StatCard(title: "Total Steps",
                        value: "\(totalSteps.formattedWithCommas)",
                        subtitle: "this week",
                        color: .purple)
            }
            .frame(height: 80)
            
            // Main Chart
            Chart {
                ForEach(entries) { entry in
                    // Steps bar
                    BarMark(
                        x: .value("Day", entry.date, unit: .day),
                        y: .value("Steps", entry.steps)
                    )
                    .foregroundStyle(
                        entry.steps >= entry.goal ?
                        Color.green.gradient : chartColor.gradient
                    )
                    .cornerRadius(8)
                    
                    // Goal line
                    RuleMark(
                        y: .value("Goal", entry.goal)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .foregroundStyle(Color.red.opacity(0.6))
                    .annotation(position: .trailing) {
                        Text("Goal: \(entry.goal)")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .fontWeight(.medium)
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
                            Text(steps.formattedWithCommas)
                                .font(.caption)
                        }
                    }
                }
            }
            .frame(height: 220)
            
            // Activity Status
            VStack(alignment: .leading, spacing: 8) {
                if let todayEntry = entries.last {
                    let progress = Double(todayEntry.steps) / Double(todayEntry.goal)
                    let remaining = max(0, todayEntry.goal - todayEntry.steps)
                    
                    HStack {
                        Text("Today's Progress")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.headline)
                            .foregroundColor(progress >= 1 ? .green : .primary)
                    }
                    
                    ProgressView(value: min(progress, 1.0))
                        .tint(progress >= 1 ? .green : .blue)
                        .background(Color.gray.opacity(0.2))
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    
                    Text(progress >= 1 ?
                         "Goal Achieved! 🎉" :
                         "\(remaining.formattedWithCommas) steps to goal")
                        .font(.subheadline)
                        .foregroundColor(progress >= 1 ? .green : .secondary)
                }
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    var yAxisDomain: ClosedRange<Int> {
        if entries.isEmpty {
            return 0...10000
        }
        
        let steps = entries.map { $0.steps }
        let goals = entries.map { $0.goal }
        let maxValue = max(steps.max() ?? 0, goals.max() ?? 0)
        
        return 0...Int(Double(maxValue) * 1.2)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

extension Int {
    var formattedWithCommas: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? String(self)
    }
}

