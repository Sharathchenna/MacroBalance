//
//  StepsChart.swift
//  Runner
//
//  Created by Sharath Chenna on 3/21/25.
//

import SwiftUI
import Charts

/// Modern and visually appealing chart view for daily step data
struct StepsChartView: View {
    // MARK: - Properties
    
    /// Collection of step entries to display
    let entries: [Models.StepsEntry]
    
    /// Current color scheme (light/dark mode)
    @Environment(\.colorScheme) var colorScheme
    
    /// Currently selected entry for detailed view
    @State private var selectedEntry: Models.StepsEntry?
    
    /// Animation states
    @State private var animateChart: Bool
    @State private var showDetails = false
    
    /// Show trendline in chart
    private let showTrendline = false
    
    /// Performance optimization for large datasets
    private let maxDisplayedPoints = 30 // Reduced from 60 for better performance
    
    // Initialize with animation control
    init(entries: [Models.StepsEntry], animateChart: Bool = true) {
        self.entries = entries
        self._animateChart = State(initialValue: animateChart)
    }
    
    // MARK: - Computed Properties

    // Removed movingAverages calculation

    /// Optimized entries for display
    private var displayEntries: [Models.StepsEntry] {
        guard entries.count > maxDisplayedPoints else { return entries }
        
        let strideSize = max(1, entries.count / maxDisplayedPoints)
        return Array(stride(from: 0, to: entries.count, by: strideSize)).map { entries[$0] }
    }
    
    /// Primary gradient for the chart bars
    private var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "3A86FF").opacity(0.8),
                Color(hex: "3A86FF")
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }
    
    /// Success gradient for the chart bars when goal is met
    private var successGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "38B000").opacity(0.7),
                Color(hex: "38B000")
            ],
            startPoint: .bottom,
            endPoint: .top
        )
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
        
        // Only consider past entries (including today)
        let today = Calendar.current.startOfDay(for: Date())
        let validEntries = entries.filter { 
            Calendar.current.startOfDay(for: $0.date) <= today
        }
        
        // Return 0 if no valid entries
        guard !validEntries.isEmpty else { return 0 }
        
        // Calculate percentage based on valid entries only
        let completedDays = validEntries.filter { $0.steps >= $0.goal }.count
        return Double(completedDays) / Double(validEntries.count) * 100
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
    
    /// Selects an entry for detailed view
    private func selectEntry(_ entry: Models.StepsEntry) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedEntry = entry
            showDetails = true
        }
    }
    
    /// Creates an optimized bar chart for the current dataset
    private func createStepsBarChart() -> some View {
        Chart {
            // Step bars - use displayEntries for optimization
            ForEach(displayEntries) { entry in
                BarMark(
                    x: .value("Day", entry.date, unit: .day),
                    y: .value("Steps", animateChart ? entry.steps : 0),
                    width: .fixed(25) // Fixed bar width
                )
                .foregroundStyle(
                    entry.steps >= entry.goal ? successGradient : primaryGradient
                )
                .cornerRadius(8)
                
                // Goal marker - only show for first and last points
                if entry.id == displayEntries.first?.id || entry.id == displayEntries.last?.id {
                    RuleMark(
                        y: .value("Goal", entry.goal)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .foregroundStyle(Color(hex: "FF006E").opacity(0.5))
                    .annotation(position: .trailing, alignment: .leading) {
                        if entry.id == displayEntries.last?.id {
                            Text("Goal: \(entry.goal.formattedWithCommas)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: "FF006E"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "FF006E").opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .chartYScale(domain: yAxisDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self),
                   displayEntries.contains(where: { Calendar.current.isDate($0.date, equalTo: date, toGranularity: .day) }) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let steps = value.as(Int.self) {
                        Text(steps.formattedWithCommas)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(height: 300)
        .drawingGroup() // Use Metal rendering for better performance
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) { // Changed to LazyVStack for better performance
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Steps")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Last 7 days")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .drawingGroup() // Optimize the header
                
                // Stats Cards
                statsCardsSection
                    .padding(.horizontal)
                
                // Main Chart - wrapped in a container for better performance
                HStack { // HStack forces a single-pass layout
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Weekly Progress")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        createStepsBarChart()
                            .padding(.horizontal, 8)
                            .drawingGroup() // Use Metal rendering for chart
                    }
                    .frame(height: 350) // Fixed height for chart section
                }
                .frame(maxWidth: .infinity) // Force full width
                
                // Selection Details
                if let selected = selectedEntry, showDetails {
                    selectionDetailsCard(for: selected)
                        .padding(.horizontal)
                        .transition(.opacity) // Simpler transition for better performance
                }
                
                // Today's Status
                todayStatusSection
                    .padding(.horizontal)
                    .frame(minHeight: 150) // Increased minimum height
            }
            .padding(.vertical, 24)
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Faster animation duration
            withAnimation(.easeInOut(duration: 0.5)) {
                animateChart = true
            }
        }
        // Improve scroll performance with these modifiers
        .scrollIndicators(.hidden)
        .scrollDisabled(false)
        // Use this modifier to improve scrolling performance
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - View Components
    
    /// Stats cards showing summary metrics
    private var statsCardsSection: some View {
        HStack(spacing: 12) { // Reduced spacing between cards
            // Daily average card with explicit frame
            StatCard(
                title: "Daily Avg",
                value: "\(averageSteps.formattedWithCommas)",
                subtitle: "steps",
                icon: "figure.walk",
                color: Color(hex: "3A86FF"),
                trend: calculateTrend()
            )
            .frame(minWidth: 0, maxWidth: .infinity)
            
            // Goal rate card with explicit frame
            StatCard(
                title: "Goal Rate",
                value: "\(Int(goalCompletionRate))%",
                subtitle: "completion",
                icon: "checkmark.circle",
                color: goalCompletionRate >= 80 ? Color(hex: "38B000") : Color(hex: "FB8500")
            )
            .frame(minWidth: 0, maxWidth: .infinity)
            
            // Total card with explicit frame
            StatCard(
                title: "Total",
                value: "\(totalSteps.formattedWithCommas)",
                subtitle: "steps",
                icon: "sum",
                color: Color(hex: "8338EC")
            )
            .frame(minWidth: 0, maxWidth: .infinity)
        }
        .frame(height: 110) // Increased height
    }
    
    /// Card showing details for selected day
    private func selectionDetailsCard(for entry: Models.StepsEntry) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Text("\(entry.steps.formattedWithCommas) steps")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Goal Progress")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                let percentage = Int((Double(entry.steps) / Double(entry.goal)) * 100)
                HStack(spacing: 4) {
                    Text("\(percentage)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    
                    Image(systemName: entry.steps >= entry.goal ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 16))
                }
                .foregroundColor(entry.steps >= entry.goal ? Color(hex: "38B000") : Color(hex: "3A86FF"))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    /// Section showing today's status
    private var todayStatusSection: some View {
        Group {
            if let todayEntry = entries.last, 
               Calendar.current.isDateInToday(todayEntry.date) {
                ActivityStatusView(entry: todayEntry)
                    .frame(minHeight: 150) // Increased minimum height
            }
        }
    }
}

// MARK: - Activity Status View

/// View that shows today's step progress and pace information
struct ActivityStatusView: View {
    // MARK: - Properties
    
    /// The step entry to display
    let entry: Models.StepsEntry
    
    /// Animation state
    @State private var animateProgress = false
    
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
        if progress >= 1 {
            return "Completed"
        }
        
        let currentHour = Calendar.current.component(.hour, from: Date())
        let hoursLeft = 24 - currentHour
        guard hoursLeft > 0 else { return "Day Complete" }
        
        let stepsPerHour = remaining / max(1, hoursLeft)
        
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
            return Color(hex: "38B000")
        case "Behind Pace":
            return Color(hex: "FF006E")
        case "On Track":
            return Color(hex: "FB8500")
        default:
            return Color(hex: "38B000")
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Progress header
            HStack {
                Text("Today's Progress")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(Int(animateProgress ? progress * 100 : 0))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(progress >= 1 ? Color(hex: "38B000") : Color(hex: "3A86FF"))
                    // Remove animation for smoother scrolling
            }
            
            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 12)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: progress >= 1 ? 
                                [Color(hex: "38B000").opacity(0.7), Color(hex: "38B000")] : 
                                [Color(hex: "3A86FF").opacity(0.7), Color(hex: "3A86FF")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: animateProgress ? min(progress, 1.0) * UIScreen.main.bounds.width * 0.85 : 0, height: 12)
                    // Use faster animation for better performance
                    .animation(.easeInOut(duration: 0.8), value: animateProgress)
            }
            
            // Status footer
            HStack(alignment: .top) {
                // Left side - completion status
                if progress >= 1 {
                    Label("Goal Achieved! 🎉", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "38B000"))
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(remaining.formattedWithCommas) steps to goal")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("Keep moving! You're doing great!")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Right side - pace indicator
                if !Calendar.current.isDate(entry.date, equalTo: Date(), toGranularity: .day) {
                    Text("Day Complete")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    Text(paceStatus)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(paceColor.opacity(0.1))
                        .foregroundColor(paceColor)
                        .cornerRadius(8)
                }
            }
        }
        .onAppear {
            // Faster animation
            withAnimation(.easeInOut(duration: 0.8)) {
                animateProgress = true
            }
        }
        .drawingGroup() // Use Metal rendering for better performance
    }
}

// MARK: - Stat Card Component

/// Card showing a statistic with optional trend
struct StatCard: View {
    // MARK: - Properties
    
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    var trend: Double? = nil
    
    @State private var appear = false
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { // Reduced spacing
            // Icon
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24) // Reduced icon size
                    .background(color)
                    .cornerRadius(6)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded)) // Reduced font size
                    .foregroundColor(.secondary)
            }
            
            // Value with trend
            HStack(alignment: .firstTextBaseline, spacing: 4) { // Reduced spacing
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded)) // Reduced font size
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8) // Allow text to scale down if needed
                
                // Optional trend indicator
                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(abs(Int(trend)))%")
                    }
                    .font(.system(size: 10, weight: .medium)) // Reduced font size
                    .foregroundColor(trend >= 0 ? Color(hex: "38B000") : Color(hex: "FF006E"))
                }
            }
            
            Text(subtitle)
                .font(.system(size: 11, weight: .regular, design: .rounded)) // Reduced font size
                .foregroundColor(.secondary)
        }
        .padding(10) // Reduced padding
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12) // Reduced corner radius
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appear = true
            }
        }
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

extension Color {
    /// Initialize a Color from a hex string
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
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
