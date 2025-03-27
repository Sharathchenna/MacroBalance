import UIKit
import DGCharts

final class MacrosTrendChartView: UIView {
    // Define constants that will be accessed by marker
    fileprivate static let markerWidth: CGFloat = 80
    fileprivate static let markerHeight: CGFloat = 40
    
    // MARK: - Types
    fileprivate enum Constants {
        static let cornerRadius: CGFloat = 16
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let titleFontSize: CGFloat = 20
        static let legendFontSize: CGFloat = 12
        static let axisFontSize: CGFloat = 10
        static let lineWidth: CGFloat = 2.5
        static let circleRadius: CGFloat = 3.5
        static let circleHoleRadius: CGFloat = 1.5
        static let animationDuration: TimeInterval = 1.2
        static let cubicIntensity: CGFloat = 0.2
        static let visibleDaysRange: Double = 7
    }
    
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Macros Trend"
        label.font = UIFont.systemFont(ofSize: Constants.titleFontSize, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var periodToggle: UISegmentedControl = {
        let segment = UISegmentedControl(items: ["7 Days", "14 Days", "30 Days"])
        segment.selectedSegmentIndex = 0
        segment.translatesAutoresizingMaskIntoConstraints = false
        segment.addTarget(self, action: #selector(periodChanged), for: .valueChanged)
        return segment
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
        chart.legend.drawInside = false
        chart.legend.font = .systemFont(ofSize: Constants.legendFontSize)
        chart.legend.yOffset = 0
        chart.legend.xOffset = -8
        
        // Configure x-axis
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.labelFont = .systemFont(ofSize: Constants.axisFontSize)
        chart.xAxis.granularity = 1
        chart.xAxis.labelCount = 5
        chart.xAxis.axisLineWidth = 0.5
        chart.xAxis.axisLineColor = .tertiaryLabel
        chart.xAxis.gridColor = .quaternaryLabel
        chart.xAxis.gridLineDashLengths = [4, 2]
        
        // Configure left axis
        chart.leftAxis.labelFont = .systemFont(ofSize: Constants.axisFontSize)
        chart.leftAxis.axisMinimum = 0
        chart.leftAxis.drawGridLinesEnabled = true
        chart.leftAxis.gridColor = .quaternaryLabel
        chart.leftAxis.gridLineDashLengths = [4, 2]
        chart.leftAxis.axisLineColor = .tertiaryLabel
        chart.leftAxis.axisLineWidth = 0.5
        
        // Enable zooming
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
    private let dateFormatter = DateFormatter()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupDateFormatter()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupDateFormatter()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = Constants.cornerRadius
        
        addSubview(titleLabel)
        addSubview(periodToggle)
        addSubview(lineChartView)
        addSubview(infoLabel)
        
        NSLayoutConstraint.activate([
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: Constants.padding),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.padding),
            
            // Period Toggle constraints
            periodToggle.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            periodToggle.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: Constants.smallPadding),
            periodToggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.padding),
            
            // Chart constraints
            lineChartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Constants.padding),
            lineChartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.smallPadding),
            lineChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.smallPadding),
            lineChartView.bottomAnchor.constraint(equalTo: infoLabel.topAnchor, constant: -Constants.smallPadding),
            
            // Info Label constraints
            infoLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.padding),
            infoLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.padding),
            infoLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
        
        // Set chart marker
        let marker = ChartMarker()
        marker.chartView = lineChartView
        lineChartView.marker = marker
    }
    
    private func setupDateFormatter() {
        dateFormatter.dateFormat = "MM/dd"
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateChartWithPeriod()
        }
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
        self.allEntries = entries
        updateChartWithPeriod()
    }
    
    private func updateChartWithPeriod() {
        guard !allEntries.isEmpty else {
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
        let proteinDataSet = createDataSet(
            entries: proteinEntries,
            label: "Protein",
            color: .proteinColor,
            fillColor: .proteinColor.withAlphaComponent(0.2)
        )
        
        let carbDataSet = createDataSet(
            entries: carbEntries,
            label: "Carbs",
            color: .carbColor,
            fillColor: .carbColor.withAlphaComponent(0.2)
        )
        
        let fatDataSet = createDataSet(
            entries: fatEntries,
            label: "Fat",
            color: .fatColor,
            fillColor: .fatColor.withAlphaComponent(0.2)
        )
        
        // Create and set chart data
        let data = LineChartData(dataSets: [proteinDataSet, carbDataSet, fatDataSet])
        data.setDrawValues(false)
        lineChartView.data = data
        
        // Update x-axis values with dates
        let dates = periodEntries.map { dateFormatter.string(from: $0.date) }
        lineChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: dates)
        
        // Set visible range
        setInitialChartVisibleRange(count: periodEntries.count)
        
        // Animate chart
        lineChartView.animate(
            xAxisDuration: Constants.animationDuration,
            yAxisDuration: Constants.animationDuration,
            easingOption: .easeInOutQuart
        )
    }
    
    private func setInitialChartVisibleRange(count: Int) {
        if count > Int(Constants.visibleDaysRange) {
            lineChartView.setVisibleXRangeMaximum(Constants.visibleDaysRange)
            lineChartView.moveViewToX(Double(count - 1))
        }
    }
    
    private func createDataSet(
        entries: [ChartDataEntry],
        label: String,
        color: UIColor,
        fillColor: UIColor
    ) -> LineChartDataSet {
        let dataSet = LineChartDataSet(entries: entries, label: label)
        
        // Configure appearance
        dataSet.colors = [color]
        dataSet.lineWidth = Constants.lineWidth
        dataSet.drawCirclesEnabled = true
        dataSet.circleColors = [color]
        dataSet.circleRadius = Constants.circleRadius
        dataSet.circleHoleRadius = Constants.circleHoleRadius
        dataSet.drawCircleHoleEnabled = true
        dataSet.circleHoleColor = traitCollection.userInterfaceStyle == .dark ? .black : .white
        dataSet.mode = .cubicBezier
        dataSet.cubicIntensity = Constants.cubicIntensity
        dataSet.drawValuesEnabled = false
        
        // Add gradient fill
        dataSet.fill = getFill(for: color)
        dataSet.drawFilledEnabled = true
        
        // Line style
        dataSet.drawHorizontalHighlightIndicatorEnabled = false
        dataSet.highlightLineWidth = 1.5
        dataSet.highlightColor = color.withAlphaComponent(0.5)
        dataSet.highlightLineDashLengths = [4, 2]
        
        return dataSet
    }
    
    private func getFill(for color: UIColor) -> Fill {
        let gradientColors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors, locations: locations)!
        return LinearGradientFill(gradient: gradient, angle: 90)
    }
    
    private func resetChart() {
        lineChartView.data = nil
        lineChartView.notifyDataSetChanged()
    }
}

// MARK: - ChartMarker
private final class ChartMarker: MarkerView {
    private let contentView = UIView()
    private let valueLabel = UILabel()
    private let dateLabel = UILabel()
    private let dateFormatter = DateFormatter()
    
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: MacrosTrendChartView.markerWidth, height: MacrosTrendChartView.markerHeight))
        setupUI()
        setupDateFormatter()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupDateFormatter()
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
    
    private func setupDateFormatter() {
        dateFormatter.dateFormat = "MMM d"
    }
    
    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        // Format the value
        valueLabel.text = "\(Int(entry.y))g"
        
        // Format the date if available
        if let date = entry.data as? Date {
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
        var offset = super.offsetForDrawing(atPoint: point)
        offset.y = -bounds.size.height - 5
        
        guard let chart = chartView else { return offset }
        
        let width = bounds.size.width
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
