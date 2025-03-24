import SwiftUI
import UIKit
import DGCharts

// MARK: - Chart Configuration
struct MacrosChartConfig {
    let showLegend: Bool
    let showValues: Bool
    let showAxisLabels: Bool
    let showGridLines: Bool
    let animate: Bool
    
    static let `default` = MacrosChartConfig(
        showLegend: true,
        showValues: true,
        showAxisLabels: true,
        showGridLines: true,
        animate: true
    )
}

// MARK: - Chart Factory
class MacrosChartFactory {
    static func createLineChart(config: MacrosChartConfig = .default) -> LineChartView {
        let chart = LineChartView()
        configureBaseChart(chart, config: config)
        return chart
    }
    
    static func createPieChart(config: MacrosChartConfig = .default) -> DGCharts.PieChartView {
        let chart = DGCharts.PieChartView()
        configureBaseChart(chart, config: config)
        configurePieChart(chart)
        return chart
    }
    
    static func createBarChart(config: MacrosChartConfig = .default) -> HorizontalBarChartView {
        let chart = HorizontalBarChartView()
        configureBaseChart(chart, config: config)
        return chart
    }
    
    private static func configureBaseChart(_ chart: ChartViewBase, config: MacrosChartConfig) {
        // Configure legend
        chart.legend.enabled = config.showLegend
        chart.legend.horizontalAlignment = .center
        chart.legend.verticalAlignment = .bottom
        chart.legend.orientation = .horizontal
        chart.legend.drawInside = false
        chart.legend.font = .systemFont(ofSize: 12)
        
        // Description configuration
        chart.chartDescription.enabled = false
    }
    
    private static func configurePieChart(_ chart: DGCharts.PieChartView) {
        chart.drawHoleEnabled = true
        chart.holeRadiusPercent = 0.5
        chart.transparentCircleRadiusPercent = 0.6
        chart.drawEntryLabelsEnabled = false
        chart.rotationEnabled = true
        chart.highlightPerTapEnabled = true
    }
}

// MARK: - SwiftUI Chart View
struct MacrosChartView: UIViewRepresentable {
    let entries: [Models.MacrosEntry]
    
    func makeUIView(context: Context) -> DGCharts.PieChartView {
        let chart = MacrosChartFactory.createPieChart()
        return chart
    }
    
    func updateUIView(_ uiView: DGCharts.PieChartView, context: Context) {
        guard let entry = entries.last else { return }
        
        let dataEntries = [
            PieChartDataEntry(value: Double(entry.proteins), label: "Protein"),
            PieChartDataEntry(value: Double(entry.carbs), label: "Carbs"),
            PieChartDataEntry(value: Double(entry.fats), label: "Fat")
        ]
        
        let dataSet = PieChartDataSet(entries: dataEntries)
        dataSet.colors = [.proteinColor, .carbColor, .fatColor]
        dataSet.valueFont = .systemFont(ofSize: 14, weight: .medium)
        dataSet.valueTextColor = .label
        
        uiView.data = PieChartData(dataSet: dataSet)
        
        if context.coordinator.shouldAnimate {
            uiView.animate(xAxisDuration: 1.0, yAxisDuration: 1.0)
            context.coordinator.shouldAnimate = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var shouldAnimate = true
    }
}

class PieChartView: UIView {
    private var layers: [CAShapeLayer] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }
    
    func updateChart(with data: [(value: Double, color: UIColor)], total: Double) {
        // Remove existing layers
        layers.forEach { $0.removeFromSuperlayer() }
        layers.removeAll()
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) * 0.4
        let innerRadius = radius * 0.618
        
        var startAngle: CGFloat = -.pi / 2
        
        for (value, color) in data {
            let endAngle = startAngle + CGFloat(2 * .pi * (value / total))
            
            let path = UIBezierPath()
            path.move(to: center)
            path.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            path.close()
            
            let innerPath = UIBezierPath()
            innerPath.move(to: center)
            innerPath.addArc(withCenter: center, radius: innerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            innerPath.close()
            
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath
            shapeLayer.fillColor = color.cgColor
            
            let maskLayer = CAShapeLayer()
            maskLayer.path = innerPath.cgPath
            maskLayer.fillColor = UIColor.black.cgColor
            
            shapeLayer.mask = maskLayer
            layer.addSublayer(shapeLayer)
            layers.append(shapeLayer)
            
            startAngle = endAngle
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layers.forEach { $0.frame = bounds }
    }
}