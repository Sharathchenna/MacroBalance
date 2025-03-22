//
//  WeightChart.swift
//  Runner
//
//  Created by Sharath Chenna on 3/21/25.
//

import SwiftUI
import Charts

struct WeightChartView: View {
    let entries: [WeightEntry]
    let goalWeight: Double
    @State private var selectedEntry: WeightEntry?
    @State private var chartHeight: CGFloat = 300
    @State private var showPrediction: Bool = true
    
    @Environment(\.colorScheme) var colorScheme
    
    var chartColor: Color {
        colorScheme == .dark ? Color.blue : Color.blue.opacity(0.8)
    }
    
    var goalColor: Color {
        colorScheme == .dark ? Color.orange : Color.orange.opacity(0.8)
    }
    
    var trendColor: Color {
        colorScheme == .dark ? Color.green : Color.green.opacity(0.8)
    }
    
    var predictedEntries: [PredictedWeightEntry] {
        guard entries.count >= 3 else { return [] }
        
        // Calculate trend line using linear regression
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let xValues = sortedEntries.map { $0.date.timeIntervalSince1970 }
        let yValues = sortedEntries.map { $0.weight }
        
        // Calculate regression line
        let n = Double(sortedEntries.count)
        let sumX = xValues.reduce(0, +)
        let sumY = yValues.reduce(0, +)
        let sumXY = zip(xValues, yValues).map { $0 * $1 }.reduce(0, +)
        let sumX2 = xValues.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        
        // Create predicted entries for future dates
        let lastDate = sortedEntries.last!.date
        let lastWeight = sortedEntries.last!.weight
        
        // Generate 8 weeks of predictions
        return (1...8).map { weekIndex in
            let futureDate = Calendar.current.date(byAdding: .day, value: weekIndex * 7, to: lastDate)!
            let timestamp = futureDate.timeIntervalSince1970
            let predictedWeight = slope * timestamp + intercept
            return PredictedWeightEntry(date: futureDate, weight: predictedWeight)
        }
    }
    
    var trendEntries: [TrendWeightEntry] {
        guard entries.count >= 3 else { return [] }
        
        // Use the same regression calculation as in predictedEntries
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let xValues = sortedEntries.map { $0.date.timeIntervalSince1970 }
        let yValues = sortedEntries.map { $0.weight }
        
        let n = Double(sortedEntries.count)
        let sumX = xValues.reduce(0, +)
        let sumY = yValues.reduce(0, +)
        let sumXY = zip(xValues, yValues).map { $0 * $1 }.reduce(0, +)
        let sumX2 = xValues.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        
        // Create trend entries for existing dates
        return sortedEntries.map { entry in
            let timestamp = entry.date.timeIntervalSince1970
            let trendWeight = slope * timestamp + intercept
            return TrendWeightEntry(date: entry.date, weight: trendWeight)
        }
    }
    
    var weeklyChangeDescription: String {
        guard entries.count >= 2 else { return "Add more entries" }
        
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let firstWeight = sortedEntries.first!.weight
        let currentWeight = sortedEntries.last!.weight
        let totalChange = currentWeight - firstWeight
        
        let firstDate = sortedEntries.first!.date
        let lastDate = sortedEntries.last!.date
        let totalDays = max(1.0, lastDate.timeIntervalSince(firstDate) / (60 * 60 * 24))
        let weeklyChange = (totalChange / totalDays) * 7
        
        let isLosing = weeklyChange < 0
        let directionText = isLosing ? "losing" : "gaining"
        
        return String(format: "You're %@ %.1f per week", directionText, abs(weeklyChange))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Period selector
            HStack {
                Text("Weight Tracking")
                    .font(.headline)
                
                Spacer()
                
                Picker("Time Period", selection: .constant(0)) {
                    Text("1W").tag(0)
                    Text("1M").tag(1)
                    Text("3M").tag(2)
                    Text("1Y").tag(3)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            // Stats row
            if entries.count >= 2 {
                HStack(spacing: 16) {
                    statCard(
                        title: "Current",
                        value: String(format: "%.1f", entries.sorted { $0.date > $1.date }.first?.weight ?? 0)
                    )
                    
                    statCard(
                        title: "Change", 
                        value: calculateChangeString(),
                        changeColor: calculateChange() < 0 ? .green : .red
                    )
                    
                    if goalWeight > 0 {
                        statCard(
                            title: "Goal", 
                            value: String(format: "%.1f", goalWeight)
                        )
                    }
                }
            }
            
            ZStack(alignment: .topLeading) {
                // Main chart
                Chart {
                    // Actual weight data
                    ForEach(entries) { entry in
                        // Line for weight
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(chartColor.gradient)
                        .interpolationMethod(.catmullRom)
                        
                        // Area under the line
                        AreaMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [chartColor.opacity(0.3), chartColor.opacity(0.01)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        
                        // Point markers
                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(chartColor)
                        .symbolSize(selectedEntry?.id == entry.id ? 100 : 50)
                    }
                    
                    // Goal line
                    if goalWeight > 0 {
                        RuleMark(y: .value("Goal", goalWeight))
                            .foregroundStyle(goalColor)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                            .annotation(position: .trailing) {
                                Text("Goal")
                                    .font(.caption)
                                    .foregroundStyle(goalColor)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.clear)
                            }
                    }
                    
                    // Trend line
                    ForEach(trendEntries) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Trend", entry.weight)
                        )
                        .foregroundStyle(trendColor)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    }
                    
                    // Prediction line
                    if showPrediction && !predictedEntries.isEmpty {
                        ForEach(predictedEntries) { entry in
                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("Prediction", entry.weight)
                            )
                            .foregroundStyle(trendColor.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        }
                        
                        // Fill area between prediction and goal if goal exists
                        if goalWeight > 0 {
                            let sortedPredictions = predictedEntries.sorted { $0.date < $1.date }
                            
                            ForEach(Array(sortedPredictions.enumerated()), id: \.element.id) { index, entry in
                                if entry.weight > goalWeight && index > 0 {
                                    let prevEntry = sortedPredictions[index - 1]
                                    
                                    // Only draw when crossing the goal line
                                    if prevEntry.weight > goalWeight {
                                        AreaMark(
                                            x: .value("Date", entry.date),
                                            yStart: .value("Goal", goalWeight),
                                            yEnd: .value("Prediction", entry.weight)
                                        )
                                        .foregroundStyle(Color.orange.opacity(0.15))
                                    }
                                }
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        if let date = value.as(Date.self) {
                            AxisGridLine()
                            AxisValueLabel {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let weight = value.as(Double.self) {
                                Text(String(format: "%.1f", weight))
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartYScale(domain: yAxisDomain)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        // Find closest data point
                                        let xPosition = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                        guard let date = proxy.value(atX: xPosition, as: Date.self) else { return }
                                        
                                        // Find closest entry
                                        selectedEntry = entries
                                            .sorted { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
                                            .first
                                    }
                                    .onEnded { _ in
                                        selectedEntry = nil
                                    }
                            )
                    }
                }
                .chartBackground { proxy in
                    ZStack(alignment: .topTrailing) {
                        // Background is clear to let container handle the background
                        Rectangle().fill(Color.clear)
                        
                        // Add chart legend
                        HStack(spacing: 16) {
                            legendItem(color: chartColor, label: "Weight")
                            legendItem(color: trendColor, label: "Trend")
                            
                            if goalWeight > 0 {
                                legendItem(color: goalColor, label: "Goal")
                            }
                            
                            Toggle("Prediction", isOn: $showPrediction)
                                .toggleStyle(SwitchToggleStyle(tint: trendColor))
                                .font(.caption)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.secondarySystemBackground).opacity(0.8))
                        )
                        .padding(8)
                    }
                }
                .frame(height: chartHeight)
                
                // Data tooltip
                if let selectedEntry = selectedEntry {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedEntry.date, format: .dateTime.month().day().year())
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(String(format: "%.1f", selectedEntry.weight)) \(selectedEntry.unit)")
                            .font(.headline)
                        
                        if let index = entries.firstIndex(where: { $0.id == selectedEntry.id }) {
                            if index > 0 {
                                let prevEntry = entries[index - 1]
                                let change = selectedEntry.weight - prevEntry.weight
                                let changeText = change > 0 ? "+\(String(format: "%.1f", change))" : "\(String(format: "%.1f", change))"
                                Text("Change: \(changeText)")
                                    .font(.caption)
                                    .foregroundColor(change > 0 ? .red : .green)
                            }
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .shadow(radius: 3)
                    )
                    .padding(8)
                    .transition(.opacity)
                }
            }
            
            // Insights section
            VStack(alignment: .leading, spacing: 12) {
                Text("Insights")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                    Text(weeklyChangeDescription)
                }
                .font(.subheadline)
                
                if goalWeight > 0 && entries.count >= 3 {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                        Text(goalProjection())
                            .font(.subheadline)
                    }
                }
                
                // Comparative stats
                if entries.count >= 14 { // At least 2 weeks of data
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundColor(.blue)
                        Text(comparativePeriodText())
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
    
    // Helper to generate comparative stats between two time periods
    private func comparativePeriodText() -> String {
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let midPoint = sortedEntries.count / 2
        
        let firstHalf = Array(sortedEntries[..<midPoint])
        let secondHalf = Array(sortedEntries[midPoint...])
        
        let firstAvg = firstHalf.map { $0.weight }.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map { $0.weight }.reduce(0, +) / Double(secondHalf.count)
        
        let change = secondAvg - firstAvg
        let percentChange = (change / firstAvg) * 100
        
        let isImproving = (change < 0) // Assuming weight loss is the goal
        
        return String(format: "%@ %.1f%% compared to previous period",
                     isImproving ? "Improved by" : "Changed by",
                     abs(percentChange))
    }
    
    // Helper to generate goal projection text
    private func goalProjection() -> String {
        guard goalWeight > 0 && !predictedEntries.isEmpty else { return "Set a goal weight" }
        
        let sortedPredictions = predictedEntries.sorted { $0.date < $1.date }
        let currentWeight = entries.sorted { $0.date > $1.date }.first!.weight
        
        // Check if goal is above or below current weight
        let isGainingToGoal = goalWeight > currentWeight
        
        // Find the point where predictions cross the goal
        for (index, entry) in sortedPredictions.enumerated() {
            if isGainingToGoal {
                if entry.weight >= goalWeight {
                    return "Goal weight projected by \(entry.date.formatted(date: .abbreviated, time: .omitted))"
                }
            } else {
                if entry.weight <= goalWeight {
                    return "Goal weight projected by \(entry.date.formatted(date: .abbreviated, time: .omitted))"
                }
            }
        }
        
        return "Goal outside of prediction window"
    }
    
    // Helper to calculate change from first to current weight entry
    private func calculateChange() -> Double {
        guard entries.count >= 2 else { return 0 }
        
        let sortedEntries = entries.sorted { $0.date < $1.date }
        let firstWeight = sortedEntries.first!.weight
        let currentWeight = sortedEntries.last!.weight
        
        return currentWeight - firstWeight
    }
    
    // Format the change string with proper sign and color
    private func calculateChangeString() -> String {
        let change = calculateChange()
        let sign = change < 0 ? "" : "+"
        return "\(sign)\(String(format: "%.1f", change))"
    }
    
    // Helper to create a stat card
    private func statCard(title: String, value: String, changeColor: Color? = nil) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .foregroundColor(changeColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }
    
    // Helper to create a legend item
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    var yAxisDomain: ClosedRange<Double> {
        if entries.isEmpty {
            return 50.0...100.0
        }
        
        // Include both entries and predictions for the y-axis range
        var weights = entries.map { $0.weight }
        
        // Add goal weight to be considered in the range
        if goalWeight > 0 {
            weights.append(goalWeight)
        }
        
        // Add prediction weights if showing predictions
        if showPrediction {
            weights.append(contentsOf: predictedEntries.map { $0.weight })
        }
        
        let minWeight = weights.min() ?? 50.0
        let maxWeight = weights.max() ?? 100.0
        let buffer = max(1.0, (maxWeight - minWeight) * 0.15)
        
        return (minWeight - buffer)...(maxWeight + buffer)
    }
}

// Data models for different chart series types
struct TrendWeightEntry: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
}

struct PredictedWeightEntry: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
}

// Preview
struct WeightChartView_Previews: PreviewProvider {
    static var previews: some View {
        WeightChartView(
            entries: [
                WeightEntry(date: Date().addingTimeInterval(-6 * 86400), weight: 70.5),
                WeightEntry(date: Date().addingTimeInterval(-5 * 86400), weight: 70.3),
                WeightEntry(date: Date().addingTimeInterval(-4 * 86400), weight: 70.0),
                WeightEntry(date: Date().addingTimeInterval(-3 * 86400), weight: 70.2),
                WeightEntry(date: Date().addingTimeInterval(-2 * 86400), weight: 69.8),
                WeightEntry(date: Date().addingTimeInterval(-1 * 86400), weight: 69.7),
                WeightEntry(date: Date(), weight: 69.5)
            ],
            goalWeight: 68.0
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

