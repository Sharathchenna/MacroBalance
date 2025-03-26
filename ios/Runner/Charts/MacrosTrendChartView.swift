import UIKit
import DGCharts

class MacrosTrendChartView: UIView {
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Macros Trend"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let periodToggle: UISegmentedControl = {
        let segment = UISegmentedControl(items: ["7 Days", "14 Days", "30 Days"])
        segment.selectedSegmentIndex = 0
        segment.translatesAutoresizingMaskIntoConstraints = false
        return segment
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillProportionally
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let lineChartView: LineChartView = {
        let chart = LineChartView()
        chart.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure chart appearance
        chart.rightAxis.enabled = false
        chart.legend.form = .circle
        chart.legend.horizontalAlignment = .right
        chart.legend.verticalAlignment = .top
        chart.legend.orientation = .horizontal
        chart.legend.drawInside = false // Keep legend outside chart area
        chart.legend.font = .systemFont(ofSize: 12)
        chart.legend.yOffset = 0 // Adjust offset if needed
        chart.legend.xOffset = -8
        
        // Configure x-axis
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.labelFont = .systemFont(ofSize: 10)
        chart.xAxis.granularity = 1
        // chart.xAxis.valueFormatter = DateAxisValueFormatter() // Remove initial incorrect formatter
        chart.xAxis.labelCount = 5 // Consider if forceLabelsEnabled is needed
        chart.xAxis.axisLineWidth = 1.0
        chart.xAxis.axisLineColor = .tertiaryLabel
        chart.xAxis.gridColor = .quaternaryLabel
        chart.xAxis.gridLineDashLengths = [4, 2]
        
        // Configure left axis
        chart.leftAxis.labelFont = .systemFont(ofSize: 10)
        chart.leftAxis.axisMinimum = 0
        chart.leftAxis.drawGridLinesEnabled = true
        chart.leftAxis.gridColor = .quaternaryLabel
        chart.leftAxis.gridLineDashLengths = [4, 2]
        chart.leftAxis.axisLineColor = .tertiaryLabel
        
        // Enable pinch zooming
        chart.scaleYEnabled = false
        chart.scaleXEnabled = true
        chart.pinchZoomEnabled = true
        chart.doubleTapToZoomEnabled = true
        
        // Description configuration
        chart.chartDescription.enabled = false
        
        return chart
    }()
    
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.text = "Pinch to zoom, double tap to reset"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Properties
    private var allEntries: [Models.MacrosEntry] = []
    private var periodDays: Int = 7
    
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
        layer.cornerRadius = 16
        
        // Add subviews directly to self
        addSubview(titleLabel)
        addSubview(periodToggle)
        addSubview(lineChartView)
        addSubview(infoLabel)
        
        // Set up chart appearance (some might be redundant from initialization block)
        lineChartView.rightAxis.enabled = false
        lineChartView.legend.form = .circle
        lineChartView.legend.horizontalAlignment = .right
        lineChartView.legend.verticalAlignment = .top
        lineChartView.legend.orientation = .horizontal
        lineChartView.legend.drawInside = false // Keep legend outside chart area
        lineChartView.legend.font = .systemFont(ofSize: 12)
        lineChartView.legend.yOffset = 0 // Adjust offset if needed
        lineChartView.legend.xOffset = -8
        
        // Configure x-axis with better styling
        lineChartView.xAxis.labelPosition = .bottom
        lineChartView.xAxis.labelFont = .systemFont(ofSize: 10)
        // lineChartView.xAxis.valueFormatter = DateAxisValueFormatter() // Remove initial incorrect formatter
        lineChartView.xAxis.labelCount = 5 // Consider if forceLabelsEnabled is needed
        lineChartView.xAxis.axisLineWidth = 0.5
        lineChartView.xAxis.axisLineColor = .tertiaryLabel
        lineChartView.xAxis.gridColor = .quaternaryLabel
        lineChartView.xAxis.gridLineDashLengths = [4, 2]
        
        // Configure left axis with improved appearance
        lineChartView.leftAxis.labelFont = .systemFont(ofSize: 10)
        lineChartView.leftAxis.axisMinimum = 0
        lineChartView.leftAxis.gridColor = .quaternaryLabel
        lineChartView.leftAxis.gridLineDashLengths = [4, 2]
        lineChartView.leftAxis.axisLineColor = .tertiaryLabel
        lineChartView.leftAxis.axisLineWidth = 0.5

        NSLayoutConstraint.activate([
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            // Period Toggle constraints (relative to title and trailing edge)
            periodToggle.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            periodToggle.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8), // Ensure space between title and toggle
            periodToggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            // Removed fixed width constraint
            
            // Chart constraints
            lineChartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            lineChartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            lineChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            lineChartView.bottomAnchor.constraint(equalTo: infoLabel.topAnchor, constant: -8),
            
            // Info Label constraints
            infoLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            infoLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
        
        // Set chart marker
        let marker = ChartMarker()
        marker.chartView = lineChartView
        lineChartView.marker = marker
    }
    
    private func setupActions() {
        periodToggle.addTarget(self, action: #selector(periodChanged), for: .valueChanged)
    }
    
    @objc private func periodChanged() {
        switch periodToggle.selectedSegmentIndex {
        case 0:
            periodDays = 7
        case 1:
            periodDays = 14
        case 2:
            periodDays = 30
        default:
            periodDays = 7
        }
        
        updateChartWithPeriod()
    }
    
    // MARK: - Configuration
    func configure(with entries: [Models.MacrosEntry]) {
        print("[MacrosTrendChartView] configure called with \(entries.count) entries.") // Log entry count
        self.allEntries = entries
        updateChartWithPeriod()
    }
    
    private func updateChartWithPeriod() {
        print("[MacrosTrendChartView] updateChartWithPeriod called. Period: \(periodDays) days.") // Log period
        guard !allEntries.isEmpty else {
            print("[MacrosTrendChartView] No entries, resetting chart.") // Log empty case
            resetChart()
            return
        }
        
        // Get specified days of data
        let periodEntries = Array(allEntries.suffix(min(periodDays, allEntries.count)))
        
        // Create data entries for each macro type
        var proteinEntries: [ChartDataEntry] = []
        var carbEntries: [ChartDataEntry] = []
        var fatEntries: [ChartDataEntry] = []
        
        // Create entries for each day
        for (index, entry) in periodEntries.enumerated() {
            let xValue = Double(index)
            
            proteinEntries.append(ChartDataEntry(x: xValue, y: Double(entry.proteins), data: entry.date))
            carbEntries.append(ChartDataEntry(x: xValue, y: Double(entry.carbs), data: entry.date))
            fatEntries.append(ChartDataEntry(x: xValue, y: Double(entry.fats), data: entry.date))
        }
        
        // Create datasets
        let proteinDataSet = createDataSet(entries: proteinEntries,
                                         label: "Protein",
                                         color: .proteinColor,
                                         fillColor: .proteinColor.withAlphaComponent(0.2))
        
        let carbDataSet = createDataSet(entries: carbEntries,
                                      label: "Carbs",
                                      color: .carbColor,
                                      fillColor: .carbColor.withAlphaComponent(0.2))
        
        let fatDataSet = createDataSet(entries: fatEntries,
                                     label: "Fat",
                                     color: .fatColor,
                                     fillColor: .fatColor.withAlphaComponent(0.2))
        
        // Create and set chart data
        let data = LineChartData(dataSets: [proteinDataSet, carbDataSet, fatDataSet])
        data.setDrawValues(false) // Hide values for cleaner look
        lineChartView.data = data
        
        // Update x-axis values with dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd"
        let dates = periodEntries.map { dateFormatter.string(from: $0.date) }
        lineChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: dates)
        
        // Set visible range
        setInitialChartVisibleRange(count: periodEntries.count)
        
        // Animate chart
        lineChartView.animate(xAxisDuration: 1.2, yAxisDuration: 1.2, easingOption: .easeInOutQuart)
    }
    
    private func setInitialChartVisibleRange(count: Int) {
        if count > 7 {
            lineChartView.setVisibleXRangeMaximum(7) // Show 7 days at a time
            lineChartView.moveViewToX(Double(count - 1)) // Move to latest data
        }
    }
    
    private func createDataSet(entries: [ChartDataEntry],
                             label: String,
                             color: UIColor,
                             fillColor: UIColor) -> LineChartDataSet {
        let dataSet = LineChartDataSet(entries: entries, label: label)
        
        // Configure appearance
        dataSet.colors = [color]
        dataSet.lineWidth = 2.5
        dataSet.drawCirclesEnabled = true
        dataSet.circleColors = [color]
        dataSet.circleRadius = 3.5
        dataSet.circleHoleRadius = 1.5
        dataSet.drawCircleHoleEnabled = true
        dataSet.circleHoleColor = .systemBackground
        dataSet.mode = .cubicBezier
        dataSet.cubicIntensity = 0.2
        dataSet.drawValuesEnabled = false
        
        // Add gradient fill
        let gradientColors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors, locations: locations)!
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        dataSet.drawFilledEnabled = true
        
        // Line style
        dataSet.drawHorizontalHighlightIndicatorEnabled = false
        dataSet.highlightLineWidth = 1.5
        dataSet.highlightColor = color.withAlphaComponent(0.5)
        dataSet.highlightLineDashLengths = [4, 2]
        
        return dataSet
    }
    
    private func getGradient(for color: UIColor) -> CGGradient {
        let gradientColors = [
            color.cgColor,
            color.withAlphaComponent(0).cgColor
        ]
        let locations: [CGFloat] = [0.0, 1.0]
        return CGGradient(
            colorsSpace: nil,
            colors: gradientColors as CFArray,
            locations: locations
        )!
    }
    
    private func resetChart() {
        print("[MacrosTrendChartView] resetChart called.") // Log reset
        lineChartView.data = nil
        lineChartView.notifyDataSetChanged()
    }
}

// MARK: - ChartMarker
private class ChartMarker: MarkerView {
    private let contentView = UIView()
    private let valueLabel = UILabel()
    private let dateLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: 80, height: 40))
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // Configure the content view
        contentView.backgroundColor = UIColor.systemGray.withAlphaComponent(0.85)
        contentView.layer.cornerRadius = 6
        contentView.clipsToBounds = true
        
        // Configure the labels
        valueLabel.textColor = .white
        valueLabel.font = .systemFont(ofSize: 12, weight: .bold)
        valueLabel.textAlignment = .center
        
        dateLabel.textColor = .white
        dateLabel.font = .systemFont(ofSize: 10)
        dateLabel.textAlignment = .center
        
        // Add subviews
        contentView.addSubview(valueLabel)
        contentView.addSubview(dateLabel)
        addSubview(contentView)
        
        // Set constraints
        contentView.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            valueLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            dateLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        ])
    }
    
    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        // Format the value
        valueLabel.text = "\(Int(entry.y))g"
        
        // Format the date if available
        if let date = entry.data as? Date {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            dateLabel.text = dateFormatter.string(from: date)
        } else {
            dateLabel.text = ""
        }
        
        // Apply dataset color to marker
        if let dataSet = chartView?.data?.dataSets[highlight.dataSetIndex] as? LineChartDataSet,
           let color = dataSet.colors.first {
            contentView.backgroundColor = color.withAlphaComponent(0.85)
        }
        
        super.refreshContent(entry: entry, highlight: highlight)
    }
    
    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        // Adjust marker position to be above the data point
        var offset = super.offsetForDrawing(atPoint: point)
        offset.y = -self.bounds.size.height - 5 // Position the marker above the point
        
        // Adjust horizontal position to keep marker within chart bounds
        guard let chart = chartView else { return offset }
        
        let width = self.bounds.size.width
        let leftMargin = 15.0
        let rightMargin = 15.0
        
        if point.x + offset.x < leftMargin {
            offset.x = leftMargin - point.x
        } else if point.x + width + offset.x > chart.bounds.width - rightMargin {
            offset.x = chart.bounds.width - rightMargin - width - point.x
        }
        
        return offset
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
