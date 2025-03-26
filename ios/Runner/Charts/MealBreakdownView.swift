import UIKit
import DGCharts

class MealBreakdownView: UIView {
    // MARK: - UI Components
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
        chart.legend.verticalAlignment = .bottom // Move legend to bottom
        chart.legend.orientation = .horizontal
        chart.legend.drawInside = false // Draw outside chart area
        chart.legend.font = .systemFont(ofSize: 11) // Slightly smaller font
        chart.legend.formSize = 8 // Smaller form size
        chart.legend.xEntrySpace = 10
        chart.legend.textColor = .label
        
        // Configure x-axis (values)
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.labelFont = .systemFont(ofSize: 10)
        chart.xAxis.drawGridLinesEnabled = true // Enable subtle grid lines
        chart.xAxis.gridColor = .tertiaryLabel.withAlphaComponent(0.5)
        chart.xAxis.gridLineDashLengths = [2, 2]
        chart.xAxis.granularity = 1
        chart.xAxis.axisLineColor = .tertiaryLabel
        chart.xAxis.labelTextColor = .secondaryLabel // Dimmer axis labels
        
        // Configure left axis (meal names)
        chart.leftAxis.labelFont = .systemFont(ofSize: 11, weight: .medium) // Adjust font
        chart.leftAxis.labelTextColor = .label
        chart.leftAxis.drawGridLinesEnabled = false
        chart.leftAxis.drawAxisLineEnabled = false
        chart.leftAxis.drawLabelsEnabled = true
        chart.leftAxis.labelAlignment = .right // Align labels to the right, closer to bars
        chart.leftAxis.xOffset = -8 // Adjust offset
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
        backgroundColor = .secondarySystemGroupedBackground // Card background
        layer.cornerRadius = 18 // Consistent radius
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.08
        layer.masksToBounds = false
        
        // Add subviews directly
        addSubview(titleLabel)
        addSubview(barChartView)
        addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Bar Chart constraints
            barChartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12), // Less space
            barChartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8), // Less padding
            barChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            barChartView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12), // Less padding
            
            // Empty State constraints (Center within chart area)
            emptyStateLabel.centerXAnchor.constraint(equalTo: barChartView.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: barChartView.centerYAnchor, constant: -20) // Adjust offset
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
            dataSet.valueFont = .systemFont(ofSize: 10, weight: .medium) // Smaller font for values
            dataSet.valueFormatter = MacroValueFormatter()
            dataSet.valueTextColor = .secondaryLabel // Dimmer value text
            dataSet.drawValuesEnabled = true
            
            // Configure highlight
            dataSet.highlightEnabled = true
            dataSet.highlightColor = color.withAlphaComponent(0.7)
            
            dataSets.append(dataSet)
        }
        
        // Create and set chart data
        let data = BarChartData(dataSets: dataSets)
        data.barWidth = 0.7 // Slightly narrower bars
        data.setValueFont(.systemFont(ofSize: 10, weight: .medium)) // Consistent value font
        
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
        emptyStateLabel.alpha = 0 // Start hidden for animation
        UIView.animate(withDuration: 0.3) {
            self.emptyStateLabel.alpha = 1.0 // Fade in empty state
        }
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
        contentView.backgroundColor = UIColor.systemGray2.withAlphaComponent(0.85) // Darker background
        contentView.layer.cornerRadius = 6 // Smaller radius
        contentView.clipsToBounds = true
        
        // Configure title label
        titleLabel.textColor = .label
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold) // Adjust font
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        
        // Configure macro stack
        macroStackView.axis = .vertical
        macroStackView.spacing = 2 // Tighter spacing
        macroStackView.distribution = .fillProportionally // Allow different heights if needed
        
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
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8), // More padding
            
            macroStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4), // Less space
            macroStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8), // More padding
            macroStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            macroStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6) // Less bottom padding
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
                macroLabel.font = .systemFont(ofSize: 11, weight: .medium) // Smaller font
                macroLabel.textColor = colors[i].adjustBrightness(by: -0.1) // Slightly darker color
                
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
            calorieLabel.text = "Total: \(Int(calories)) kcal" // Add "Total"
            calorieLabel.font = .systemFont(ofSize: 11, weight: .semibold) // Adjust font
            calorieLabel.textColor = .label
            
            // Add a small spacer before the total
            let spacer = UIView()
            spacer.heightAnchor.constraint(equalToConstant: 2).isActive = true
            macroStackView.addArrangedSubview(spacer)
            
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
