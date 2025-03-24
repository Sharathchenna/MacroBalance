import UIKit
import DGCharts

class MealBreakdownView: UIView {
    // MARK: - UI Components
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Meal Breakdown"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No meals logged today"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let barChartView: HorizontalBarChartView = {
        let chart = HorizontalBarChartView()
        chart.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure chart appearance
        chart.rightAxis.enabled = false
        chart.legend.form = .circle
        chart.legend.horizontalAlignment = .center
        chart.legend.verticalAlignment = .top
        chart.legend.orientation = .horizontal
        chart.legend.drawInside = true
        chart.legend.font = .systemFont(ofSize: 12)
        chart.legend.formSize = 10
        chart.legend.xEntrySpace = 10
        chart.legend.textColor = .label
        
        // Configure x-axis (values)
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.labelFont = .systemFont(ofSize: 10)
        chart.xAxis.drawGridLinesEnabled = false
        chart.xAxis.granularity = 1
        chart.xAxis.axisLineColor = .tertiaryLabel
        
        // Configure left axis (meal names)
        chart.leftAxis.labelFont = .systemFont(ofSize: 12)
        chart.leftAxis.labelTextColor = .label
        chart.leftAxis.drawGridLinesEnabled = false
        chart.leftAxis.drawAxisLineEnabled = false
        chart.leftAxis.drawLabelsEnabled = true
        chart.leftAxis.labelAlignment = .left
        chart.leftAxis.spaceTop = 0.15
        chart.leftAxis.spaceBottom = 0.15
        chart.leftAxis.axisMinimum = -0.5
        
        // Enable zooming and scaling
        chart.scaleYEnabled = false
        chart.scaleXEnabled = false
        chart.doubleTapToZoomEnabled = false
        chart.pinchZoomEnabled = false
        
        // Description configuration
        chart.chartDescription.enabled = false
        
        // Interaction
        chart.highlightPerTapEnabled = true
        
        return chart
    }()
    
    // MARK: - Properties
    private var meals: [Models.Meal] = []
    private let mealTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupChartDelegate()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupChartDelegate()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 16
        
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(barChartView)
        containerView.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            barChartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            barChartView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            barChartView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            barChartView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: barChartView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: barChartView.centerYAnchor)
        ])
        
        // Set marker for chart
        let marker = MealDetailMarker()
        marker.chartView = barChartView
        barChartView.marker = marker
    }
    
    private func setupChartDelegate() {
        barChartView.delegate = self
    }
    
    // MARK: - Configuration
    func configure(with meals: [Models.Meal]) {
        self.meals = meals
        
        guard !meals.isEmpty else {
            resetChart()
            return
        }
        
        // Show chart and hide empty state
        barChartView.isHidden = false
        emptyStateLabel.isHidden = true
        
        // Sort meals by time
        let sortedMeals = meals.sorted { $0.time < $1.time }
        
        // Create data entries for each meal
        var dataEntries: [[BarChartDataEntry]] = []
        var mealNames: [String] = []
        
        for (index, meal) in sortedMeals.enumerated() {
            let yValue = Double(index)
            
            // Create entries for protein, carbs, and fat
            let proteinEntry = BarChartDataEntry(x: Double(meal.proteins), y: yValue)
            let carbsEntry = BarChartDataEntry(x: Double(meal.carbs), y: yValue)
            let fatEntry = BarChartDataEntry(x: Double(meal.fats), y: yValue)
            
            dataEntries.append([proteinEntry, carbsEntry, fatEntry])
            
            // Format meal name with time
            let timeString = mealTimeFormatter.string(from: meal.time)
            mealNames.append("\(meal.name) (\(timeString))")
        }
        
        // Create datasets
        var dataSets: [BarChartDataSet] = []
        
        // Create stacked bars for each macro type
        for macroIndex in 0..<3 {
            let entries = dataEntries.map { $0[macroIndex] }
            let label = ["Protein", "Carbs", "Fat"][macroIndex]
            let color = [UIColor.proteinColor, UIColor.carbColor, UIColor.fatColor][macroIndex]
            
            let dataSet = BarChartDataSet(entries: entries, label: label)
            dataSet.colors = [color]
            dataSet.valueFont = .systemFont(ofSize: 11, weight: .medium)
            dataSet.valueFormatter = MacroValueFormatter()
            dataSet.valueTextColor = .label
            dataSet.drawValuesEnabled = true
            
            // Configure highlight
            dataSet.highlightEnabled = true
            dataSet.highlightColor = color.withAlphaComponent(0.7)
            
            dataSets.append(dataSet)
        }
        
        // Create and set chart data
        let data = BarChartData(dataSets: dataSets)
        data.barWidth = 0.8
        data.setValueFont(.systemFont(ofSize: 11, weight: .medium))
        
        // Configure the x-axis
        barChartView.xAxis.axisMinimum = 0
        let maxValue = meals.map { $0.proteins + $0.carbs + $0.fats }.max() ?? 0
        barChartView.xAxis.axisMaximum = Double(maxValue) * 1.1 // Add 10% padding
        
        // Configure the y-axis (meal names)
        barChartView.leftAxis.valueFormatter = IndexAxisValueFormatter(values: mealNames)
        barChartView.leftAxis.axisMaximum = Double(meals.count) - 0.5
        barChartView.leftAxis.labelCount = meals.count
        
        // Set the data
        barChartView.data = data
        
        // Set visible range based on meal count
        barChartView.setVisibleYRangeMaximum(6, axis: .left)
        
        // Ensure we can see the latest meal (if there are many)
        if meals.count > 5 {
            barChartView.moveViewToY(Double(meals.count - 1), axis: .left)
        }
        
        // Animate chart
        barChartView.animate(xAxisDuration: 1.0, yAxisDuration: 1.0, easingOption: .easeOutCubic)
    }
    
    private func resetChart() {
        barChartView.data = nil
        barChartView.isHidden = true
        emptyStateLabel.isHidden = false
    }
    
    // Add a method to explicitly show the empty state
    func showEmptyState() {
        resetChart()
    }
}

// MARK: - ChartViewDelegate
extension MealBreakdownView: ChartViewDelegate {
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        // Provide haptic feedback when a bar is selected
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Value Formatter
private class MacroValueFormatter: ValueFormatter {
    func stringForValue(_ value: Double,
                       entry: ChartDataEntry,
                       dataSetIndex: Int,
                       viewPortHandler: ViewPortHandler?) -> String {
        return value > 5 ? "\(Int(value))g" : ""
    }
}

// MARK: - MealDetailMarker
private class MealDetailMarker: MarkerView {
    private let contentView = UIView()
    private let macroStackView = UIStackView()
    private let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: 150, height: 80))
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // Configure the content view
        contentView.backgroundColor = UIColor.systemGray4.withAlphaComponent(0.9)
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
        
        // Configure title label
        titleLabel.textColor = .label
        titleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        
        // Configure macro stack
        macroStackView.axis = .vertical
        macroStackView.spacing = 3
        macroStackView.distribution = .fillEqually
        
        // Add subviews
        contentView.addSubview(titleLabel)
        contentView.addSubview(macroStackView)
        addSubview(contentView)
        
        // Set constraints
        contentView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        macroStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            
            macroStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            macroStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            macroStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            macroStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])
    }
    
    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        // Clear previous macro labels
        macroStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        guard let barChart = chartView as? HorizontalBarChartView,
              let data = barChart.data else { return }
        
        // Get the meal name
        let yValue = Int(entry.y)
        if let yFormatter = barChart.leftAxis.valueFormatter as? IndexAxisValueFormatter,
           let mealName = yFormatter.values.getOrNil(index: yValue) {
            titleLabel.text = mealName
        } else {
            titleLabel.text = "Meal \(yValue + 1)"
        }
        
        // Get protein, carbs and fat values for this meal
        let macros = ["Protein", "Carbs", "Fat"]
        let colors = [UIColor.proteinColor, UIColor.carbColor, UIColor.fatColor]
        
        for (i, dataset) in data.dataSets.enumerated() {
            let entries = dataset.entriesForXValue(entry.y)
            if !entries.isEmpty {
                let macroValue = entries.first?.x ?? 0
                
                let macroLabel = UILabel()
                macroLabel.text = "\(macros[i]): \(Int(macroValue))g"
                macroLabel.font = .systemFont(ofSize: 12, weight: .medium)
                macroLabel.textColor = colors[i]
                
                macroStackView.addArrangedSubview(macroLabel)
            }
        }
        
        // Add total calories if we can calculate
        if macroStackView.arrangedSubviews.count == 3 {
            let proteinValue = data.dataSets[0].entriesForXValue(entry.y).first?.x ?? 0
            let carbsValue = data.dataSets[1].entriesForXValue(entry.y).first?.x ?? 0
            let fatValue = data.dataSets[2].entriesForXValue(entry.y).first?.x ?? 0
            
            let calories = (proteinValue * 4) + (carbsValue * 4) + (fatValue * 9)
            
            let calorieLabel = UILabel()
            calorieLabel.text = "Calories: \(Int(calories)) kcal"
            calorieLabel.font = .systemFont(ofSize: 12, weight: .bold)
            calorieLabel.textColor = .label
            
            macroStackView.addArrangedSubview(calorieLabel)
        }
        
        super.refreshContent(entry: entry, highlight: highlight)
    }
    
    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        var offset = CGPoint(x: -self.bounds.size.width/2, y: -self.bounds.size.height - 10)
        
        if let chart = chartView {
            let width = self.bounds.size.width
            
            if point.x + offset.x < 0 {
                offset.x = -point.x
            } else if point.x + width + offset.x > chart.bounds.width {
                offset.x = chart.bounds.width - point.x - width
            }
        }
        
        return offset
    }
}

// MARK: - Array Extension
private extension Array {
    func getOrNil(index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 