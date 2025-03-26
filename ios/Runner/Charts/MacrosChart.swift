import Foundation
#if canImport(UIKit)
import UIKit
#endif
import SwiftUI
import DGCharts

// MARK: - Modern Chart Configuration
struct MacrosChartConfig {
    let showLegend: Bool
    let showValues: Bool
    let showAxisLabels: Bool
    let showGridLines: Bool
    let animate: Bool
    let interactive: Bool
    let gradientFill: Bool
    let showTooltips: Bool
    
    static let `default` = MacrosChartConfig(
        showLegend: true,
        showValues: true,
        showAxisLabels: true,
        showGridLines: true,
        animate: true,
        interactive: true,
        gradientFill: true,
        showTooltips: true
    )
    
    static let minimal = MacrosChartConfig(
        showLegend: false,
        showValues: false,
        showAxisLabels: false,
        showGridLines: false,
        animate: true,
        interactive: false,
        gradientFill: true,
        showTooltips: false
    )
}

// MARK: - Modern Chart Factory
class MacrosChartFactory {
    static func createPieChart(config: MacrosChartConfig = .default) -> DGCharts.PieChartView {
        let chart = DGCharts.PieChartView()
        
        // Base configuration
        chart.chartDescription.enabled = false
        
        // Set theme background
        chart.backgroundColor = ThemeManager.shared.cardBackground
        
        // Configure legend based on config
        chart.legend.enabled = config.showLegend
        if config.showLegend {
            chart.legend.horizontalAlignment = .center
            chart.legend.verticalAlignment = .bottom
            chart.legend.orientation = .horizontal
            chart.legend.drawInside = false
            chart.legend.font = ThemeManager.shared.fontCaption()
            chart.legend.xEntrySpace = 12
            chart.legend.yOffset = 6
            chart.legend.textColor = ThemeManager.shared.textPrimary
            chart.legend.form = .circle
            chart.legend.formSize = 12
        }
        
        // Configure pie chart appearance
        chart.holeColor = .clear
        chart.holeRadiusPercent = 0.58
        chart.transparentCircleRadiusPercent = 0.61
        chart.drawEntryLabelsEnabled = false
        chart.drawCenterTextEnabled = true
        chart.highlightPerTapEnabled = config.interactive
        chart.rotationEnabled = config.interactive
        chart.dragDecelerationEnabled = true
        chart.dragDecelerationFrictionCoef = 0.95
        
        // Configure values
        let attributes: [NSAttributedString.Key: Any] = [
            .font: ThemeManager.shared.fontBody1(),
            .foregroundColor: ThemeManager.shared.textPrimary
        ]
        chart.centerAttributedText = NSAttributedString(string: "Macros", attributes: attributes)
        
        return chart
    }
    
    static func createLineChart(config: MacrosChartConfig = .default) -> LineChartView {
        let chart = LineChartView()
        
        // Base configuration
        chart.chartDescription.enabled = false
        
        // Set theme background
        chart.backgroundColor = ThemeManager.shared.cardBackground
        
        // Configure legend based on config
        chart.legend.enabled = config.showLegend
        if config.showLegend {
            chart.legend.horizontalAlignment = .right
            chart.legend.verticalAlignment = .top
            chart.legend.orientation = .horizontal
            chart.legend.drawInside = true
            chart.legend.font = ThemeManager.shared.fontCaption()
            chart.legend.form = .circle
            chart.legend.formSize = 8
            chart.legend.textColor = ThemeManager.shared.textPrimary
            chart.legend.xOffset = -5
            chart.legend.yOffset = 5
        }
        
        // Configure axes
        chart.rightAxis.enabled = false
        
        let xAxis = chart.xAxis
        xAxis.labelPosition = .bottom
        xAxis.labelFont = ThemeManager.shared.fontCaption()
        xAxis.labelTextColor = ThemeManager.shared.textSecondary
        xAxis.drawGridLinesEnabled = config.showGridLines
        xAxis.drawAxisLineEnabled = true
        xAxis.granularity = 1
        
        let leftAxis = chart.leftAxis
        leftAxis.labelFont = ThemeManager.shared.fontCaption()
        leftAxis.labelTextColor = ThemeManager.shared.textSecondary
        leftAxis.axisMinimum = 0
        leftAxis.drawGridLinesEnabled = config.showGridLines
        if config.showGridLines {
            leftAxis.gridColor = ThemeManager.shared.textSecondary.withAlphaComponent(0.2)
            leftAxis.gridLineDashLengths = [4, 2]
        }
        
        // Configure interaction
        chart.scaleYEnabled = false
        chart.scaleXEnabled = config.interactive
        chart.pinchZoomEnabled = config.interactive
        chart.doubleTapToZoomEnabled = config.interactive
        
        return chart
    }
    
    static func createBarChart(config: MacrosChartConfig = .default) -> HorizontalBarChartView {
        let chart = HorizontalBarChartView()
        
        // Base configuration
        chart.chartDescription.enabled = false
        
        // Set theme background
        chart.backgroundColor = ThemeManager.shared.cardBackground
        
        // Configure legend based on config
        chart.legend.enabled = config.showLegend
        if config.showLegend {
            chart.legend.horizontalAlignment = .right
            chart.legend.verticalAlignment = .top
            chart.legend.orientation = .vertical
            chart.legend.drawInside = true
            chart.legend.font = ThemeManager.shared.fontCaption()
            chart.legend.form = .circle
            chart.legend.formSize = 8
            chart.legend.textColor = ThemeManager.shared.textPrimary
        }
        
        // Configure axes
        chart.rightAxis.enabled = false
        
        let xAxis = chart.xAxis
        xAxis.labelPosition = .bottom
        xAxis.labelFont = ThemeManager.shared.fontCaption()
        xAxis.labelTextColor = ThemeManager.shared.textSecondary
        xAxis.drawGridLinesEnabled = config.showGridLines
        xAxis.drawAxisLineEnabled = true
        xAxis.granularity = 1
        
        let leftAxis = chart.leftAxis
        leftAxis.labelFont = ThemeManager.shared.fontCaption()
        leftAxis.labelTextColor = ThemeManager.shared.textSecondary
        leftAxis.axisMinimum = 0
        leftAxis.drawGridLinesEnabled = config.showGridLines
        if config.showGridLines {
            leftAxis.gridColor = ThemeManager.shared.textSecondary.withAlphaComponent(0.2)
            leftAxis.gridLineDashLengths = [4, 2]
        }
        
        // Configure interaction
        chart.scaleYEnabled = false
        chart.scaleXEnabled = false
        chart.pinchZoomEnabled = false
        chart.doubleTapToZoomEnabled = false
        
        return chart
    }
}

// MARK: - SwiftUI Chart View - Main Visualization Component
struct MacrosChartView: View {
    let entries: [Models.MacrosEntry]
    @State private var selectedEntry: Models.MacrosEntry?
    @State private var selectedMacro: String?
    @State private var showingDetail = false
    @State private var animateChart = false
    @Environment(\.colorScheme) var colorScheme
    
    // UI Configuration
    private let cornerRadius: CGFloat = 16
    private let padding: CGFloat = 20
    private let spacing: CGFloat = 12
    private let smallSpacing: CGFloat = 6
    
    // Colors
    private var proteinColor: Color { Color(UIColor.proteinColor) }
    private var carbsColor: Color { Color(UIColor.carbColor) }
    private var fatsColor: Color { Color(UIColor.fatColor) }
    private var backgroundColor: Color { colorScheme == .dark ? Color(.systemGray6) : Color(.secondarySystemBackground) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            header
            pieChartSection
            macroBreakdown
            
            if let entry = selectedEntry {
                macroDetails(entry: entry)
            }
        }
        .padding(padding)
        .background(backgroundColor)
        .cornerRadius(cornerRadius)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                selectedEntry = entries.last
                animateChart = true
            }
        }
    }
    
    // MARK: - Header Section
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: smallSpacing) {
                Text("Macro Distribution")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("Today's breakdown")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                Button(action: { /* Export Data action */ }) {
                    Label("Export Data", systemImage: "square.and.arrow.up")
                }
                
                Button(action: { /* Show History action */ }) {
                    Label("Show History", systemImage: "clock")
                }
                
                Divider()
                
                Button(action: { /* Edit Goals action */ }) {
                    Label("Edit Goals", systemImage: "slider.horizontal.3")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Pie Chart Section
    private var pieChartSection: some View {
        VStack(spacing: spacing) {
            ZStack {
                // Modern Pie Chart
                ModernPieChart(
                    values: [
                        (value: Double(selectedEntry?.proteins ?? 0), color: proteinColor),
                        (value: Double(selectedEntry?.carbs ?? 0), color: carbsColor), 
                        (value: Double(selectedEntry?.fats ?? 0), color: fatsColor)
                    ],
                    animate: animateChart
                )
                .frame(height: 230)
                
                // Center content
                VStack(spacing: 4) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(calculateTotalCalories()))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    
                    Text("calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Legend
            HStack(spacing: 20) {
                ForEach([
                    (macro: "Protein", color: proteinColor, value: selectedEntry?.proteins ?? 0),
                    (macro: "Carbs", color: carbsColor, value: selectedEntry?.carbs ?? 0),
                    (macro: "Fat", color: fatsColor, value: selectedEntry?.fats ?? 0)
                ], id: \.macro) { item in
                    legendItem(for: item.macro, color: item.color, value: item.value)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedMacro = item.macro
                            }
                        }
                }
            }
            .padding(.horizontal, 10)
        }
    }
    
    // MARK: - Macro Breakdown
    private var macroBreakdown: some View {
        VStack(spacing: spacing) {
            HStack {
                Text("Macros vs Goals")
                    .font(.headline)
                
                Spacer()
                
                Text(String(format: "%.0f%% Complete", calculateTotalCompletion()))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(
                        calculateTotalCompletion() > 95 ? .green :
                        calculateTotalCompletion() > 75 ? .orange : .secondary
                    )
            }
            
            VStack(spacing: smallSpacing) {
                macroProgressBar(
                    name: "Protein",
                    current: Double(selectedEntry?.proteins ?? 0),
                    goal: Double(selectedEntry?.proteinGoal ?? 150),
                    color: proteinColor
                )
                
                macroProgressBar(
                    name: "Carbs",
                    current: Double(selectedEntry?.carbs ?? 0),
                    goal: Double(selectedEntry?.carbGoal ?? 250),
                    color: carbsColor
                )
                
                macroProgressBar(
                    name: "Fat",
                    current: Double(selectedEntry?.fats ?? 0),
                    goal: Double(selectedEntry?.fatGoal ?? 65),
                    color: fatsColor
                )
            }
        }
    }
    
    // MARK: - Macro Details
    @ViewBuilder
    private func macroDetails(entry: Models.MacrosEntry) -> some View {
        if let selectedMacro = selectedMacro {
            VStack(alignment: .leading, spacing: spacing) {
                Divider()
                
                HStack {
                    Text("\(selectedMacro) Details")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            self.selectedMacro = nil
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(alignment: .top, spacing: 20) {
                    macroDetailCard(
                        title: "Current",
                        value: String(format: "%.0fg", getMacroValue(name: selectedMacro, entry: entry)),
                        subtitle: getMacroCalories(name: selectedMacro, entry: entry),
                        color: getMacroColor(name: selectedMacro)
                    )
                    
                    macroDetailCard(
                        title: "Goal",
                        value: String(format: "%.0fg", getMacroGoal(name: selectedMacro, entry: entry)),
                        subtitle: "Daily Target",
                        color: getMacroColor(name: selectedMacro).opacity(0.7)
                    )
                    
                    macroDetailCard(
                        title: "Percentage",
                        value: String(format: "%.0f%%", getMacroPercentage(name: selectedMacro, entry: entry)),
                        subtitle: "of Total",
                        color: getMacroColor(name: selectedMacro).opacity(0.5)
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Components
    private func legendItem(for name: String, color: Color, value: Double) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.0fg", value))
                    .font(.callout.bold())
                    .foregroundColor(selectedMacro == name ? color : .primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedMacro == name ? color.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selectedMacro == name ? color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
    
    private func macroProgressBar(name: String, current: Double, goal: Double, color: Color) -> some View {
        let progress = min(current / max(1, goal), 1.0)
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(Int(current))g / \(Int(goal))g")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
    
    private func macroDetailCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
    
    // MARK: - Helpers
    private func calculateTotalCalories() -> Double {
        guard let entry = selectedEntry else { return 0 }
        return (entry.proteins * 4) + (entry.carbs * 4) + (entry.fats * 9)
    }
    
    private func calculateTotalCompletion() -> Double {
        guard let entry = selectedEntry else { return 0 }
        
        let proteinCompletion = entry.proteinGoal > 0 ? min((entry.proteins / entry.proteinGoal) * 100, 100) : 0
        let carbsCompletion = entry.carbGoal > 0 ? min((entry.carbs / entry.carbGoal) * 100, 100) : 0
        let fatCompletion = entry.fatGoal > 0 ? min((entry.fats / entry.fatGoal) * 100, 100) : 0
        
        return (proteinCompletion + carbsCompletion + fatCompletion) / 3.0
    }
    
    private func getMacroValue(name: String, entry: Models.MacrosEntry) -> Double {
        switch name {
        case "Protein": return entry.proteins
        case "Carbs": return entry.carbs
        case "Fat": return entry.fats
        default: return 0
        }
    }
    
    private func getMacroGoal(name: String, entry: Models.MacrosEntry) -> Double {
        switch name {
        case "Protein": return entry.proteinGoal
        case "Carbs": return entry.carbGoal
        case "Fat": return entry.fatGoal
        default: return 0
        }
    }
    
    private func getMacroCalories(name: String, entry: Models.MacrosEntry) -> String {
        switch name {
        case "Protein": return "\(Int(entry.proteins * 4)) calories"
        case "Carbs": return "\(Int(entry.carbs * 4)) calories"
        case "Fat": return "\(Int(entry.fats * 9)) calories"
        default: return ""
        }
    }
    
    private func getMacroPercentage(name: String, entry: Models.MacrosEntry) -> Double {
        let total = entry.proteins + entry.carbs + entry.fats
        guard total > 0 else { return 0 }
        
        switch name {
        case "Protein": return (entry.proteins / total) * 100
        case "Carbs": return (entry.carbs / total) * 100
        case "Fat": return (entry.fats / total) * 100
        default: return 0
        }
    }
    
    private func getMacroColor(name: String) -> Color {
        switch name {
        case "Protein": return proteinColor
        case "Carbs": return carbsColor
        case "Fat": return fatsColor
        default: return .gray
        }
    }
}

// MARK: - Modern Pie Chart Implementation
struct ModernPieChart: View {
    let values: [(value: Double, color: Color)]
    let animate: Bool
    
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Optional background ring
                Circle()
                    .stroke(Color.gray.opacity(0.1), style: StrokeStyle(lineWidth: 30, lineCap: .round))
                
                // Main chart
                ZStack {
                    ForEach(0..<values.count, id: \.self) { index in
                        let startAngle = self.startAngle(for: index)
                        let endAngle = self.endAngle(for: index)
                        let animatedEndAngle = self.animate ? 
                            self.startAngle(for: index) + (endAngle - startAngle) * animationProgress :
                            endAngle
                        
                        MacroArcShape(
                            startAngle: startAngle,
                            endAngle: animatedEndAngle
                        )
                        .stroke(values[index].color, style: StrokeStyle(lineWidth: 30, lineCap: .round))
                        .shadow(color: values[index].color.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                }
                .rotationEffect(.degrees(-90)) // Rotate to start from the top
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                if animate {
                    withAnimation(.easeInOut(duration: 1.2)) {
                        animationProgress = 1.0
                    }
                } else {
                    animationProgress = 1.0
                }
            }
            .onChange(of: animate) { newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 1.2)) {
                        animationProgress = 1.0
                    }
                }
            }
        }
    }
    
    private func startAngle(for index: Int) -> Angle {
        let total = values.map { $0.value }.reduce(0, +)
        guard total > 0, index > 0 else { return .degrees(0) }
        
        let sumUpToIndex = values[0..<index].map { $0.value }.reduce(0, +)
        return .degrees(sumUpToIndex / total * 360.0)
    }
    
    private func endAngle(for index: Int) -> Angle {
        let total = values.map { $0.value }.reduce(0, +)
        guard total > 0 else { return .degrees(0) }
        
        let sumUpToAndIncludingIndex = values[0...index].map { $0.value }.reduce(0, +)
        return .degrees(sumUpToAndIncludingIndex / total * 360.0)
    }
}

// MARK: - MacroArcShape
struct MacroArcShape: SwiftUI.Shape {
    var startAngle: Angle
    var endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 15
        
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
    
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle.degrees, endAngle.degrees) }
        set {
            startAngle = .degrees(newValue.first)
            endAngle = .degrees(newValue.second)
        }
    }
}

// MARK: - UIKit Implementation for legacy support
class PieChartView: UIView {
    private var chartView: DGCharts.PieChartView!
    private var layers: [CAShapeLayer] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupChartView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupChartView()
    }
    
    private func setupChartView() {
        chartView = MacrosChartFactory.createPieChart()
        chartView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(chartView)
        
        // Apply the theme to the chart
        ThemeManager.shared.applyChartTheme(to: chartView)
        
        NSLayoutConstraint.activate([
            chartView.topAnchor.constraint(equalTo: topAnchor),
            chartView.leadingAnchor.constraint(equalTo: leadingAnchor),
            chartView.trailingAnchor.constraint(equalTo: trailingAnchor),
            chartView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(with entry: Models.MacrosEntry?) {
        guard let entry = entry else {
            chartView.data = nil
            chartView.centerText = "No Data"
            return
        }
        
        let total = entry.proteins + entry.carbs + entry.fats
        
        if total > 0 {
            // Create data entries
            let entries: [PieChartDataEntry] = [
                PieChartDataEntry(value: Double(entry.proteins), label: "Protein"),
                PieChartDataEntry(value: Double(entry.carbs), label: "Carbs"),
                PieChartDataEntry(value: Double(entry.fats), label: "Fat")
            ]
            
            let dataSet = PieChartDataSet(entries: entries)
            dataSet.colors = [.proteinColor, .carbColor, .fatColor]
            dataSet.sliceSpace = 2
            dataSet.selectionShift = 8
            dataSet.valueFont = .systemFont(ofSize: 14, weight: .bold)
            dataSet.valueTextColor = .label
            dataSet.valueFormatter = PercentValueFormatter()
            dataSet.drawValuesEnabled = true
            
            // Set center text
            let calorieCount = (entry.proteins * 4) + (entry.carbs * 4) + (entry.fats * 9)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            
            let centerText = NSMutableAttributedString(string: "\(Int(calorieCount))\n", attributes: [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.label
            ])
            
            centerText.append(NSAttributedString(string: "calories", attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraphStyle
            ]))
            
            chartView.centerAttributedText = centerText
            chartView.data = PieChartData(dataSet: dataSet)
        } else {
            chartView.data = nil
            chartView.centerText = "No Data"
        }
        
        // Animate the chart
        chartView.animate(xAxisDuration: 1.2, yAxisDuration: 1.2, easingOption: .easeOutBack)
    }
}

// MARK: - Previews
struct MacrosChartView_Previews: PreviewProvider {
    static var previews: some View {
        MacrosChartView(entries: [
            Models.MacrosEntry(
                id: UUID(),
                date: Date(),
                proteins: 120,
                carbs: 180,
                fats: 60,
                proteinGoal: 140,
                carbGoal: 220,
                fatGoal: 70,
                micronutrients: [],
                water: 1500,
                waterGoal: 2500,
                meals: []
            )
        ])
        .frame(height: 500)
        .padding()
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.light)
        
        MacrosChartView(entries: [
            Models.MacrosEntry(
                id: UUID(),
                date: Date(),
                proteins: 120,
                carbs: 180,
                fats: 60,
                proteinGoal: 140,
                carbGoal: 220,
                fatGoal: 70,
                micronutrients: [],
                water: 1500,
                waterGoal: 2500,
                meals: []
            )
        ])
        .frame(height: 500)
        .padding()
        .previewLayout(.sizeThatFits)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Value Formatters
class PercentValueFormatter: NSObject, ValueFormatter {
    func stringForValue(_ value: Double,
                       entry: ChartDataEntry,
                       dataSetIndex: Int,
                       viewPortHandler: ViewPortHandler?) -> String {
        if let pieEntry = entry as? PieChartDataEntry {
            let total = pieEntry.value
            return String(format: "%.0f%%", (value / total) * 100)
        }
        return String(format: "%.0f%%", value)
    }
}