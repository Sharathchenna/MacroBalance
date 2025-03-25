import UIKit
import DGCharts

class WeeklyOverviewChartView: UIView {
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Weekly Overview"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Last 7 days at a glance"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let toggleControl: UISegmentedControl = {
        let items = ["Calories", "Macros"]
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let barChartView: BarChartView = {
        let chart = BarChartView()
        chart.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure chart appearance
        chart.drawBarShadowEnabled = false
        chart.drawValueAboveBarEnabled = true
        chart.highlightFullBarEnabled = false
        chart.doubleTapToZoomEnabled = false
        chart.pinchZoomEnabled = false
        
        // Configure legend
        chart.legend.enabled = true
        chart.legend.horizontalAlignment = .right
        chart.legend.verticalAlignment = .top
        chart.legend.orientation = .horizontal
        chart.legend.drawInside = true
        chart.legend.yOffset = 10
        chart.legend.font = .systemFont(ofSize: 11)
        chart.legend.form = .circle
        chart.legend.formSize = 8
        
        // Configure right-side axis
        chart.rightAxis.enabled = false
        
        // Configure left-side axis
        chart.leftAxis.labelFont = .systemFont(ofSize: 10)
        chart.leftAxis.labelTextColor = .secondaryLabel
        chart.leftAxis.axisMinimum = 0
        chart.leftAxis.drawGridLinesEnabled = true
        chart.leftAxis.gridColor = .tertiarySystemFill
        chart.leftAxis.gridLineDashLengths = [4, 2]
        
        // Configure x-axis
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.labelFont = .systemFont(ofSize: 10)
        chart.xAxis.labelTextColor = .secondaryLabel
        chart.xAxis.drawGridLinesEnabled = false
        chart.xAxis.granularity = 1
        chart.xAxis.centerAxisLabelsEnabled = true
        
        // Configure description
        chart.chartDescription.enabled = false
        
        return chart
    }()
    
    private let calorieAverageView: AverageSummaryView = {
        let view = AverageSummaryView(title: "Avg. Calories", color: .systemIndigo)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let calorieStreakView: AverageSummaryView = {
        let view = AverageSummaryView(title: "Streak", color: .systemOrange)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let summaryStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Properties
    private var entries: [Models.MacrosEntry] = []
    private var showingCalories = true
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupActions()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 20
        layer.masksToBounds = true
        
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(toggleControl)
        addSubview(barChartView)
        addSubview(summaryStack)
        
        summaryStack.addArrangedSubview(calorieAverageView)
        summaryStack.addArrangedSubview(calorieStreakView)
        
        NSLayoutConstraint.activate([
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            // Subtitle constraints
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            // Toggle control constraints
            toggleControl.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            toggleControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            toggleControl.widthAnchor.constraint(equalToConstant: 140),
            
            // Bar chart constraints
            barChartView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            barChartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            barChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            barChartView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5),
            
            // Summary stack constraints
            summaryStack.topAnchor.constraint(equalTo: barChartView.bottomAnchor, constant: 8),
            summaryStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            summaryStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            summaryStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    private func setupActions() {
        toggleControl.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
    }
    
    @objc private func toggleChanged() {
        showingCalories = toggleControl.selectedSegmentIndex == 0
        updateChart()
        
        // Provide haptic feedback on toggle
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    // MARK: - Configuration
    func configure(with entries: [Models.MacrosEntry]) {
        self.entries = entries
        updateChart()
        updateSummaryViews()
    }
    
    private func updateChart() {
        guard !entries.isEmpty else {
            barChartView.data = nil
            return
        }
        
        if showingCalories {
            updateCaloriesChart()
        } else {
            updateMacrosChart()
        }
    }
    
    private func updateCaloriesChart() {
        // Create entries for calories and goal
        var caloriesEntries: [BarChartDataEntry] = []
        var goalEntries: [BarChartDataEntry] = []
        
        // Format date for labels
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE"
        var days: [String] = []
        
        // Create data for each day
        for (i, entry) in entries.enumerated() {
            let xValue = Double(i)
            
            // Calories entry for actual intake
            caloriesEntries.append(BarChartDataEntry(x: xValue, y: Double(entry.calories)))
            
            // Goal entry for the target
            goalEntries.append(BarChartDataEntry(x: xValue, y: Double(entry.calorieGoal)))
            
            // Add date label
            days.append(dateFormatter.string(from: entry.date))
        }
        
        // Create dataset for calories
        let caloriesDataSet = BarChartDataSet(entries: caloriesEntries, label: "Intake")
        caloriesDataSet.colors = [UIColor.systemIndigo]
        caloriesDataSet.valueFont = .systemFont(ofSize: 10)
        caloriesDataSet.valueFormatter = IntegerValueFormatter()
        
        // Create dataset for goals
        let goalDataSet = BarChartDataSet(entries: goalEntries, label: "Goal")
        goalDataSet.colors = [UIColor.systemGray.withAlphaComponent(0.5)]
        goalDataSet.valueFont = .systemFont(ofSize: 10)
        goalDataSet.valueFormatter = IntegerValueFormatter()
        
        // Group and set data
        let groupSpace = 0.3
        let barSpace = 0.05
        let barWidth = 0.3
        
        let data = BarChartData(dataSets: [caloriesDataSet, goalDataSet])
        data.barWidth = barWidth
        
        // Set x position of grouped bars
        data.groupBars(fromX: 0, groupSpace: groupSpace, barSpace: barSpace)
        
        // Update x-axis range and labels
        barChartView.xAxis.axisMinimum = 0
        barChartView.xAxis.axisMaximum = 0 + data.groupWidth(groupSpace: groupSpace, barSpace: barSpace) * Double(caloriesEntries.count)
        barChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: days)
        barChartView.xAxis.labelCount = days.count
        
        // Set data and animate
        barChartView.data = data
        barChartView.animate(yAxisDuration: 1.0)
    }
    
    private func updateMacrosChart() {
        // Create entries for stacked bar chart
        var chartEntries: [BarChartDataEntry] = []
        
        // Format date for labels
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE"
        var days: [String] = []
        
        // Create data for each day
        for (i, macroEntry) in self.entries.enumerated() {
            let xValue = Double(i)
            
            // Create stacked values array [proteins, carbs, fats]
            let yValues = [Double(macroEntry.proteins * 4), // 4 calories per gram of protein
                           Double(macroEntry.carbs * 4),    // 4 calories per gram of carb
                           Double(macroEntry.fats * 9)]     // 9 calories per gram of fat
            
            // Stacked bar entry
            chartEntries.append(BarChartDataEntry(x: xValue, yValues: yValues))
            
            // Add date label
            days.append(dateFormatter.string(from: macroEntry.date))
        }
        
        // Create dataset
        let dataSet = BarChartDataSet(entries: chartEntries, label: "Macros")
        dataSet.colors = [UIColor.proteinColor, UIColor.carbColor, UIColor.fatColor]
        dataSet.stackLabels = ["Protein", "Carbs", "Fat"]
        dataSet.valueFont = .systemFont(ofSize: 10)
        dataSet.valueFormatter = IntegerValueFormatter()
        dataSet.valueTextColor = .label
        
        // Create data object
        let data = BarChartData(dataSet: dataSet)
        
        // Configure bar width
        data.barWidth = 0.6
        
        // Update x-axis range and labels
        barChartView.xAxis.axisMinimum = -0.5
        barChartView.xAxis.axisMaximum = Double(days.count - 1) + 0.5
        barChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: days)
        barChartView.xAxis.labelCount = days.count
        
        // Set data and animate
        barChartView.data = data
        barChartView.animate(yAxisDuration: 1.0)
    }
    
    private func updateSummaryViews() {
        guard !entries.isEmpty else {
            calorieAverageView.configure(value: 0, caption: "No data")
            calorieStreakView.configure(value: 0, caption: "No streak")
            return
        }
        
        // Calculate average calories
        let totalCalories = entries.reduce(0) { $0 + $1.calories }
        let averageCalories = Int(totalCalories / Double(entries.count))
        calorieAverageView.configure(value: averageCalories, caption: "kcal daily")
        
        // Calculate streak days (consecutive days where calories > 0)
        var streak = 0
        for entry in entries.reversed() {
            if entry.calories > 0 {
                streak += 1
            } else {
                break
            }
        }
        calorieStreakView.configure(value: streak, caption: "\(streak == 1 ? "day" : "days")")
    }
}

// MARK: - Average Summary View
fileprivate class AverageSummaryView: UIView {
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 28, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let captionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let colorIndicator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 3
        return view
    }()
    
    init(title: String, color: UIColor) {
        super.init(frame: .zero)
        titleLabel.text = title
        colorIndicator.backgroundColor = color
        valueLabel.textColor = color
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .tertiarySystemBackground
        layer.cornerRadius = 12
        
        addSubview(colorIndicator)
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(captionLabel)
        
        NSLayoutConstraint.activate([
            // Color indicator
            colorIndicator.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            colorIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            colorIndicator.widthAnchor.constraint(equalToConstant: 30),
            colorIndicator.heightAnchor.constraint(equalToConstant: 6),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: colorIndicator.bottomAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            
            // Value label
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            // Caption label
            captionLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            captionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            captionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            captionLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12)
        ])
    }
    
    func configure(value: Int, caption: String) {
        // Animate the value change
        animateValue(to: value)
        captionLabel.text = caption
    }
    
    private func animateValue(to newValue: Int) {
        let oldValue = Int(valueLabel.text ?? "0") ?? 0
        
        // Only animate if the difference is significant
        if abs(newValue - oldValue) > 20 {
            // Number counting animation
            let duration: TimeInterval = 1.0
            let steps = 20
            let stepDuration = duration / Double(steps)
            
            var currentStep = 0
            let stepValue = (newValue - oldValue) / steps
            
            Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                currentStep += 1
                let currentValue = oldValue + (stepValue * currentStep)
                
                self.valueLabel.text = "\(min(currentValue, newValue))"
                
                if currentStep >= steps {
                    self.valueLabel.text = "\(newValue)"
                    timer.invalidate()
                }
            }
        } else {
            // Just set the value without animation for small changes
            valueLabel.text = "\(newValue)"
        }
    }
}

// MARK: - Integer Value Formatter
fileprivate class IntegerValueFormatter: ValueFormatter {
    func stringForValue(_ value: Double, entry: ChartDataEntry, dataSetIndex: Int, viewPortHandler: ViewPortHandler?) -> String {
        return "\(Int(value))"
    }
} 