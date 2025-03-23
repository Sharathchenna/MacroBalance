//
//  StepsChart.swift
//  Runner
//
//  Created by Sharath Chenna on 3/21/25.
//

import SwiftUI
import Charts

/// A SwiftUI view for displaying step data in a chart format
struct StepsChartView: View {
    // MARK: - Properties
    
    /// Collection of step entries to display
    let entries: [StepsEntry]
    
    /// Current color scheme (light/dark mode)
    @Environment(\.colorScheme) var colorScheme
    
    /// Currently selected entry for detailed view
    @State private var selectedEntry: StepsEntry?
    
    /// Currently highlighted date in the chart
    @State private var highlightedDate: Date?
    
    // MARK: - Computed Properties
    
    /// Chart's main color based on color scheme
    private var chartColor: Color {
        colorScheme == .dark ? .blue : .blue.opacity(0.8)
    }
    
    /// Average steps per day
    private var averageSteps: Int {
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0) { $0 + $1.steps } / entries.count
    }
    
    /// Total steps for the period
    private var totalSteps: Int {
        entries.reduce(0) { $0 + $1.steps }
    }
    
    /// Percentage of days where goal was met
    private var goalCompletionRate: Double {
        guard !entries.isEmpty else { return 0 }
        let completedDays = entries.filter { $0.steps >= $0.goal }.count
        return Double(completedDays) / Double(entries.count) * 100
    }
    
    /// Y-axis range for the chart
    private var yAxisDomain: ClosedRange<Int> {
        if entries.isEmpty {
            return 0...10000
        }
        
        let maxSteps = entries.map(\.steps).max() ?? 0
        let maxGoal = entries.map(\.goal).max() ?? 0
        let maxValue = max(maxSteps, maxGoal)
        
        // Add 20% padding to the top for better visualization
        return 0...Int(Double(maxValue) * 1.2)
    }
    
    /// Date formatter for chart labels
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    // MARK: - Methods
    
    /// Calculates the percentage trend from first to last entry
    private func calculateTrend() -> Double {
        guard entries.count > 1 else { return 0 }
        let firstSteps = Double(entries.first?.steps ?? 0)
        guard firstSteps > 0 else { return 0 }
        
        let lastSteps = Double(entries.last?.steps ?? 0)
        return ((lastSteps - firstSteps) / firstSteps) * 100
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stats Summary Cards
            statsCardsSection
            
            // Main Chart
            chartSection
            
            // Today's Status
            todayStatusSection
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - View Components
    
    /// Stats cards showing summary metrics
    private var statsCardsSection: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Daily Average",
                value: "\(averageSteps.formattedWithCommas)",
                subtitle: "steps",
                color: .blue,
                trend: calculateTrend()
            )
            
            StatCard(
                title: "Goal Rate",
                value: "\(Int(goalCompletionRate))%",
                subtitle: "completion",
                color: goalCompletionRate >= 80 ? .green : .orange
            )
            
            StatCard(
                title: "Total Steps",
                value: "\(totalSteps.formattedWithCommas)",
                subtitle: "this week",
                color: .purple
            )
        }
        .frame(height: 90)
    }
    
    /// Main chart showing daily steps
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Progress")
                .font(.headline)
                .foregroundColor(.primary)
            
            stepsChart
            
            // Selection details card
            if let selected = selectedEntry {
                selectionDetailsCard(for: selected)
            }
        }
    }
    
    /// The steps bar chart with goal lines
    private var stepsChart: some View {
        // Break the complex chart into smaller components
        createStepsBarChart()
    }
    
    // Break down the complex chart into smaller components
    private func createStepsBarChart() -> some View {
        Chart {
            // Step bars section
            ForEach(entries) { entry in
                BarMark(
                    x: .value("Day", entry.date, unit: .day),
                    y: .value("Steps", entry.steps)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: entry.steps >= entry.goal ?
                            [Color.green.opacity(0.6), Color.green] :
                            [chartColor.opacity(0.6), chartColor],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(8)
                .annotation(position: .top) {
                    if entry.steps >= entry.goal {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption2)
                    }
                }
                
                // Goal marker
                RuleMark(
                    y: .value("Goal", entry.goal)
                )
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                .foregroundStyle(Color.red.opacity(0.4))
                .annotation(position: .trailing, alignment: .leading) {
                    if entry.id == entries.last?.id {
                        Text("Goal: \(entry.goal.formattedWithCommas)")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            
            // Trend line if there are multiple entries
            if entries.count > 1 {
                LineMark(
                    x: .value("Day", entries.first!.date, unit: .day),
                    y: .value("Trend", Double(entries.first!.steps))
                )
                
                // Add remaining points to the line
                ForEach(entries.dropFirst()) { entry in
                    LineMark(
                        x: .value("Day", entry.date, unit: .day),
                        y: .value("Trend", Double(entry.steps))
                    )
                }
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(Color.blue.opacity(0.3))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartForegroundStyleScale([
            "Steps": chartColor,
            "Goal": Color.red.opacity(0.6)
        ])
        .chartYScale(domain: yAxisDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        VStack(spacing: 2) {
                            Text(date, format: .dateTime.weekday(.abbreviated))
                                .font(.caption2)
                            Text(dateFormatter.string(from: date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let steps = value.as(Int.self) {
                        Text(steps.formattedWithCommas)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(height: 220)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(createChartGesture(proxy: proxy, geometry: geometry))
            }
        }
    }
    
    // Creates a drag gesture for chart interaction
    private func createChartGesture(proxy: ChartProxy, geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let x = value.location.x - geometry.size.width/2
                guard let date = proxy.value(atX: x) as Date? else { return }
                highlightedDate = date
                if let entry = entries.first(where: {
                    Calendar.current.isDate($0.date, equalTo: date, toGranularity: .day)
                }) {
                    selectedEntry = entry
                }
            }
            .onEnded { _ in
                highlightedDate = nil
                selectedEntry = nil
            }
    }
    
    /// Card showing details for selected day
    private func selectionDetailsCard(for entry: StepsEntry) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text(dateFormatter.string(from: entry.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(entry.steps.formattedWithCommas) steps")
                    .font(.headline)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Goal Progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                let percentage = Int((Double(entry.steps) / Double(entry.goal)) * 100)
                Text("\(percentage)%")
                    .font(.headline)
                    .foregroundColor(entry.steps >= entry.goal ? .green : .primary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: selectedEntry)
    }
    
    /// Section showing today's status
    private var todayStatusSection: some View {
        Group {
            if let todayEntry = entries.last, 
               Calendar.current.isDateInToday(todayEntry.date) {
                ActivityStatusView(entry: todayEntry)
            }
        }
    }
}

// MARK: - Activity Status View

/// View that shows today's step progress and pace information
struct ActivityStatusView: View {
    // MARK: - Properties
    
    /// The step entry to display
    let entry: StepsEntry
    
    // MARK: - Computed Properties
    
    /// Progress toward goal (0.0 to 1.0)
    private var progress: Double {
        Double(entry.steps) / Double(entry.goal)
    }
    
    /// Remaining steps to reach goal
    private var remaining: Int {
        max(0, entry.goal - entry.steps)
    }
    
    /// Status text for current pace
    private var paceStatus: String {
        // If goal is already met, show completed status
        if progress >= 1 {
            return "Completed"
        }
        
        // Calculate steps needed per hour to reach goal
        let currentHour = Calendar.current.component(.hour, from: Date())
        let hoursLeft = 24 - currentHour
        guard hoursLeft > 0 else { return "Day Complete" }
        
        let stepsPerHour = remaining / max(1, hoursLeft)
        
        // Determine pace status based on steps per hour needed
        if stepsPerHour > 2000 {
            return "Behind Pace"
        } else if stepsPerHour > 1000 {
            return "On Track"
        } else {
            return "Ahead of Pace"
        }
    }
    
    /// Color for pace indicator
    private var paceColor: Color {
        switch paceStatus {
        case "Completed":
            return .green
        case "Behind Pace":
            return .red
        case "On Track":
            return .orange
        default:
            return .green
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Progress header
            HStack {
                Text("Today's Progress")
                    .font(.headline)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .foregroundColor(progress >= 1 ? .green : .primary)
            }
            
            // Progress bar
            ProgressView(value: min(progress, 1.0))
                .tint(progress >= 1 ? .green : .blue)
                .background(Color.gray.opacity(0.2))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            // Status footer
            HStack(alignment: .top) {
                // Left side - completion status
                if progress >= 1 {
                    Label("Goal Achieved! 🎉", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(remaining.formattedWithCommas) steps to goal")
                            .foregroundColor(.secondary)
                        Text("Keep moving! You're doing great!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Right side - pace indicator
                if !Calendar.current.isDate(entry.date, equalTo: Date(), toGranularity: .day) {
                    Text("Day Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(paceStatus)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(paceColor.opacity(0.1))
                        .foregroundColor(paceColor)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Stat Card Component

/// Card showing a statistic with optional trend
struct StatCard: View {
    // MARK: - Properties
    
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    var trend: Double? = nil
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                // Optional trend indicator
                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(abs(Int(trend)))%")
                    }
                    .font(.caption2)
                    .foregroundColor(trend >= 0 ? .green : .red)
                }
            }
            
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

// MARK: - Extensions

extension Int {
    /// Format integer with thousands separators
    var formattedWithCommas: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? String(self)
    }
}

