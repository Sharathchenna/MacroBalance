import UIKit
import DGCharts

class MacrosTrendChartView: UIView {
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "7-Day Macro Trends"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let lineChartView: LineChartView = {
        let chart = LineChartView()
        chart.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure chart appearance
        chart.rightAxis.enabled = false
        chart.legend.form = .circle
        chart.legend.horizontalAlignment = .center
        chart.legend.verticalAlignment = .bottom
        chart.legend.orientation = .horizontal
        chart.legend.drawInside = false
        chart.legend.font = .systemFont(ofSize: 12)
        
        // Configure x-axis
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.labelFont = .systemFont(ofSize: 10)
        chart.xAxis.granularity = 1
        chart.xAxis.valueFormatter = DateAxisValueFormatter()
        
        // Configure left axis
        chart.leftAxis.labelFont = .systemFont(ofSize: 10)
        chart.leftAxis.axisMinimum = 0
        chart.leftAxis.drawGridLinesEnabled = true
        chart.leftAxis.drawZeroLineEnabled = true
        
        // Enable zooming and scaling
        chart.scaleYEnabled = false
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
        addSubview(lineChartView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            lineChartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            lineChartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            lineChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            lineChartView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Configuration
    func configure(with entries: [Models.MacrosEntry]) {
        guard !entries.isEmpty else {
            resetChart()
            return
        }
        
        // Create data entries for each macro type
        var proteinEntries: [ChartDataEntry] = []
        var carbEntries: [ChartDataEntry] = []
        var fatEntries: [ChartDataEntry] = []
        
        // Get last 7 days of data
        let lastSevenDays = Array(entries.suffix(7))
        
        // Create entries for each day
        for (index, entry) in lastSevenDays.enumerated() {
            let xValue = Double(index)
            
            proteinEntries.append(ChartDataEntry(x: xValue, y: Double(entry.proteins)))
            carbEntries.append(ChartDataEntry(x: xValue, y: Double(entry.carbs)))
            fatEntries.append(ChartDataEntry(x: xValue, y: Double(entry.fats)))
        }
        
        // Create datasets
        let proteinDataSet = createDataSet(entries: proteinEntries,
                                         label: "Protein",
                                         color: .proteinColor)
        let carbDataSet = createDataSet(entries: carbEntries,
                                      label: "Carbs",
                                      color: .carbColor)
        let fatDataSet = createDataSet(entries: fatEntries,
                                     label: "Fat",
                                     color: .fatColor)
        
        // Create and set chart data
        let data = LineChartData(dataSets: [proteinDataSet, carbDataSet, fatDataSet])
        lineChartView.data = data
        
        // Update x-axis values with dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"
        let dates = lastSevenDays.map { dateFormatter.string(from: $0.date) }
        lineChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: dates)
        
        // Animate chart
        lineChartView.animate(xAxisDuration: 1.0, yAxisDuration: 1.0)
    }
    
    private func createDataSet(entries: [ChartDataEntry],
                             label: String,
                             color: UIColor) -> LineChartDataSet {
        let dataSet = LineChartDataSet(entries: entries, label: label)
        
        // Configure appearance
        dataSet.colors = [color]
        dataSet.lineWidth = 2
        dataSet.drawCirclesEnabled = true
        dataSet.circleColors = [color]
        dataSet.circleRadius = 4
        dataSet.drawCircleHoleEnabled = false
        dataSet.mode = .cubicBezier
        dataSet.drawValuesEnabled = true
        dataSet.valueFont = .systemFont(ofSize: 10)
        dataSet.valueFormatter = MacroValueFormatter()
        
        // Add gradient fill
        let gradientColors = [color.cgColor, color.withAlphaComponent(0.1).cgColor]
        let gradient = CGGradient(colorsSpace: nil,
                                colors: gradientColors as CFArray,
                                locations: [1.0, 0.0])!
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        dataSet.drawFilledEnabled = true
        
        return dataSet
    }
    
    private func resetChart() {
        lineChartView.data = nil
    }
}

// MARK: - Value Formatter
private class MacroValueFormatter: ValueFormatter {
    func stringForValue(_ value: Double,
                       entry: ChartDataEntry,
                       dataSetIndex: Int,
                       viewPortHandler: ViewPortHandler?) -> String {
        return "\(Int(value))g"
    }
}

// MARK: - Date Axis Value Formatter
private class DateAxisValueFormatter: NSObject, AxisValueFormatter {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }()
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let date = Date(timeIntervalSinceNow: TimeInterval(value * 24 * 60 * 60))
        return dateFormatter.string(from: date)
    }
} 