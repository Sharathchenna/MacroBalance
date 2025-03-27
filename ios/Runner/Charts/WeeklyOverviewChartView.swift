import UIKit
import DGCharts

final class WeeklyOverviewChartView: UIView {
    
    // MARK: - Types
    private enum Constants {
        static let cornerRadius: CGFloat = 20
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let titleFontSize: CGFloat = 20
        static let subtitleFontSize: CGFloat = 14
        static let legendFontSize: CGFloat = 11
        static let legendFormSize: CGFloat = 8
        static let axisFontSize: CGFloat = 10
        static let barWidth: Double = 0.6
        static let animationDuration: TimeInterval = 1.0
    }
    
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Weekly Overview"
        label.font = UIFont.systemFont(ofSize: Constants.titleFontSize, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Last 7 days at a glance"
        label.font = UIFont.systemFont(ofSize: Constants.subtitleFontSize)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var barChartView: BarChartView = {
        let chart = BarChartView()
        chart.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure chart appearance
        chart.drawBarShadowEnabled = false
        chart.drawValueAboveBarEnabled = true
        chart.highlightFullBarEnabled = false
        chart.doubleTapToZoomEnabled = false
        chart.pinchZoomEnabled = false
        chart.highlightPerTapEnabled = true
        
        // Configure legend
        chart.legend.enabled = true
        chart.legend.horizontalAlignment = .right
        chart.legend.verticalAlignment = .top
        chart.legend.orientation = .horizontal
        chart.legend.drawInside = true
        chart.legend.yOffset = 10
        chart.legend.font = .systemFont(ofSize: Constants.legendFontSize)
        chart.legend.form = .circle
        chart.legend.formSize = Constants.legendFormSize
        
        // Configure right-side axis
        chart.rightAxis.enabled = false
        
        // Configure left-side axis
        chart.leftAxis.labelFont = .systemFont(ofSize: Constants.axisFontSize)
        chart.leftAxis.labelTextColor = .secondaryLabel
        chart.leftAxis.axisMinimum = 0
        chart.leftAxis.drawGridLinesEnabled = true
        chart.leftAxis.gridColor = .tertiarySystemFill
        chart.leftAxis.gridLineDashLengths = [4, 2]
        
        // Configure x-axis
        chart.xAxis.labelPosition = .bottom
        chart.xAxis.labelFont = .systemFont(ofSize: Constants.axisFontSize)
        chart.xAxis.labelTextColor = .secondaryLabel
        chart.xAxis.drawGridLinesEnabled = false
        chart.xAxis.granularity = 1
        chart.xAxis.centerAxisLabelsEnabled = true
        
        // Configure description
        chart.chartDescription.enabled = false
        
        return chart
    }()
    
    // MARK: - Properties
    private var entries: [Models.MacrosEntry] = []
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
        layer.masksToBounds = true
        
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(barChartView)
        
        NSLayoutConstraint.activate([
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: Constants.padding),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.padding),
            
            // Subtitle constraints
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.padding),
            
            // Bar chart constraints
            barChartView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: Constants.padding),
            barChartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.smallPadding),
            barChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.smallPadding),
            barChartView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Constants.padding)
        ])
    }
    
    private func setupDateFormatter() {
        dateFormatter.dateFormat = "EEE"
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateChart()
        }
    }
    
    // MARK: - Configuration
    func configure(with entries: [Models.MacrosEntry]) {
        self.entries = entries
        updateChart()
    }
    
    private func updateChart() {
        guard !entries.isEmpty else {
            barChartView.data = nil
            barChartView.notifyDataSetChanged()
            return
        }
        
        updateMacrosChart()
    }
    
    private func updateMacrosChart() {
        // Create entries for stacked bar chart
        var chartEntries: [BarChartDataEntry] = []
        var days: [String] = []
        
        // Process data for each day
        for (i, macroEntry) in entries.enumerated() {
            let xValue = Double(i)
            
            // Create stacked values array [proteins, carbs, fats] in GRAMS
            let yValues = [
                Double(macroEntry.proteins),
                Double(macroEntry.carbs),
                Double(macroEntry.fats)
            ]
            
            // Add stacked bar entry
            chartEntries.append(BarChartDataEntry(x: xValue, yValues: yValues))
            
            // Add date label
            days.append(dateFormatter.string(from: macroEntry.date))
        }
        
        // Create dataset
        let dataSet = BarChartDataSet(entries: chartEntries, label: "Macros")
        configureDataSet(dataSet)
        
        // Create data object
        let data = BarChartData(dataSet: dataSet)
        data.barWidth = Constants.barWidth
        
        // Configure x-axis
        configureXAxis(with: days)
        
        // Set data and animate
        barChartView.data = data
        barChartView.animate(yAxisDuration: Constants.animationDuration)
    }
    
    private func configureDataSet(_ dataSet: BarChartDataSet) {
        dataSet.colors = [UIColor.proteinColor, UIColor.carbColor, UIColor.fatColor]
        dataSet.stackLabels = ["Protein", "Carbs", "Fat"]
        dataSet.valueFont = .systemFont(ofSize: Constants.axisFontSize)
        dataSet.valueFormatter = IntegerValueFormatter()
        dataSet.valueTextColor = traitCollection.userInterfaceStyle == .dark ? .white : .darkText
    }
    
    private func configureXAxis(with days: [String]) {
        barChartView.xAxis.axisMinimum = -0.5
        barChartView.xAxis.axisMaximum = Double(days.count - 1) + 0.5
        barChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: days)
        barChartView.xAxis.labelCount = days.count
    }
}

// MARK: - Integer Value Formatter
fileprivate final class IntegerValueFormatter: ValueFormatter {
    func stringForValue(_ value: Double, entry: ChartDataEntry, dataSetIndex: Int, viewPortHandler: ViewPortHandler?) -> String {
        return value < 1 ? "" : "\(Int(value))"
    }
}
