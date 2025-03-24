import UIKit
import DGCharts

class MealBreakdownView: UIView {
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Meal Breakdown"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let barChartView: HorizontalBarChartView = {
        let chart = HorizontalBarChartView()
        chart.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure chart appearance
        chart.rightAxis.enabled = false
        chart.legend.enabled = false
        
        // Configure x-axis (values)
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.labelFont = .systemFont(ofSize: 10)
        chart.xAxis.drawGridLinesEnabled = false
        chart.xAxis.granularity = 1
        
        // Configure left axis (meal names)
        chart.leftAxis.labelFont = .systemFont(ofSize: 12)
        chart.leftAxis.drawGridLinesEnabled = false
        chart.leftAxis.drawAxisLineEnabled = false
        chart.leftAxis.drawLabelsEnabled = true
        chart.leftAxis.labelAlignment = .left
        chart.leftAxis.spaceTop = 0.2
        
        // Enable zooming and scaling
        chart.scaleYEnabled = false
        chart.scaleXEnabled = false
        chart.doubleTapToZoomEnabled = false
        
        // Description configuration
        chart.chartDescription.enabled = false
        
        return chart
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.1
        
        addSubview(titleLabel)
        addSubview(barChartView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            barChartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            barChartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            barChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            barChartView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Configuration
    func configure(with meals: [Models.Meal]) {
        guard !meals.isEmpty else {
            resetChart()
            return
        }
        
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
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let timeString = timeFormatter.string(from: meal.time)
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
            dataSet.valueFont = .systemFont(ofSize: 10)
            dataSet.valueFormatter = MacroValueFormatter()
            dataSet.valueTextColor = .label
            
            dataSets.append(dataSet)
        }
        
        // Create and set chart data
        let data = BarChartData(dataSets: dataSets)
        data.barWidth = 0.8
        
        // Configure the x-axis
        barChartView.xAxis.axisMinimum = 0
        let maxValue = meals.map { $0.proteins + $0.carbs + $0.fats }.max() ?? 0
        barChartView.xAxis.axisMaximum = Double(maxValue) * 1.1 // Add 10% padding
        
        // Configure the y-axis (meal names)
        barChartView.leftAxis.valueFormatter = IndexAxisValueFormatter(values: mealNames)
        barChartView.leftAxis.axisMinimum = -0.5
        barChartView.leftAxis.axisMaximum = Double(meals.count) - 0.5
        barChartView.leftAxis.labelCount = meals.count
        
        // Set the data
        barChartView.data = data
        
        // Animate chart
        barChartView.animate(xAxisDuration: 1.0, yAxisDuration: 1.0)
    }
    
    private func resetChart() {
        barChartView.data = nil
    }
}

// MARK: - Value Formatter
private class MacroValueFormatter: ValueFormatter {
    func stringForValue(_ value: Double,
                       entry: ChartDataEntry,
                       dataSetIndex: Int,
                       viewPortHandler: ViewPortHandler?) -> String {
        return value > 0 ? "\(Int(value))g" : ""
    }
} 