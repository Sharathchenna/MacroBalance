import UIKit
import DGCharts

class MacrosDistributionChartView: UIView {
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Macro Distribution"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let pieChartView: DGCharts.PieChartView = {
        let chart = DGCharts.PieChartView()
        chart.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure chart appearance
        chart.drawHoleEnabled = true
        chart.holeRadiusPercent = 0.5
        chart.transparentCircleRadiusPercent = 0.6
        chart.drawEntryLabelsEnabled = false
        chart.rotationEnabled = true
        chart.highlightPerTapEnabled = true
        
        // Legend configuration
        chart.legend.horizontalAlignment = .center
        chart.legend.verticalAlignment = .bottom
        chart.legend.orientation = .horizontal
        chart.legend.drawInside = false
        chart.legend.font = .systemFont(ofSize: 12)
        
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
        addSubview(pieChartView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            pieChartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            pieChartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            pieChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            pieChartView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Configuration
    func configure(with entry: Models.MacrosEntry?) {
        guard let entry = entry else {
            resetChart()
            return
        }
        
        let total = entry.proteins + entry.carbs + entry.fats
        guard total > 0 else {
            resetChart()
            return
        }
        
        // Create data entries
        let entries: [PieChartDataEntry] = [
            PieChartDataEntry(value: Double(entry.proteins), label: "Protein"),
            PieChartDataEntry(value: Double(entry.carbs), label: "Carbs"),
            PieChartDataEntry(value: Double(entry.fats), label: "Fat")
        ]
        
        // Create dataset
        let dataSet = PieChartDataSet(entries: entries)
        
        // Configure dataset appearance
        dataSet.colors = [.proteinColor, .carbColor, .fatColor]
        dataSet.valueFont = .systemFont(ofSize: 14, weight: .medium)
        dataSet.valueTextColor = .label
        dataSet.valueFormatter = MacroValueFormatter(total: total)
        dataSet.valueLineWidth = 1
        dataSet.valueLinePart1Length = 0.4
        dataSet.valueLinePart2Length = 0.4
        dataSet.yValuePosition = .outsideSlice
        
        // Create and set chart data
        pieChartView.data = PieChartData(dataSet: dataSet)
        
        // Animate chart
        pieChartView.animate(xAxisDuration: 1.0, yAxisDuration: 1.0)
    }
    
    private func resetChart() {
        pieChartView.data = nil
    }
}

// MARK: - Value Formatter
private class MacroValueFormatter: NSObject, ValueFormatter {
    private let total: Double
    
    init(total: Double) {
        self.total = total
        super.init()
    }
    
    func stringForValue(_ value: Double,
                       entry: ChartDataEntry,
                       dataSetIndex: Int,
                       viewPortHandler: ViewPortHandler?) -> String {
        let percentage = total > 0 ? Int(value * 100 / total) : 0
        return "\(Int(value))g (\(percentage)%)"
    }
} 