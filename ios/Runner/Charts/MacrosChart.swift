import SwiftUI
import UIKit

// Color extension to match the image style
extension Color {
    static let proteinColor = Color(red: 0.98, green: 0.76, blue: 0.34) // Golden yellow
    static let carbColor = Color(red: 0.35, green: 0.78, blue: 0.71) // Teal green
    static let fatColor = Color(red: 0.56, green: 0.27, blue: 0.68) // Purple
}

struct MacrosChartView: UIViewRepresentable {
    let entries: [MacrosEntry]
    
    func makeUIView(context: Context) -> PieChartView {
        return PieChartView()
    }
    
    func updateUIView(_ uiView: PieChartView, context: Context) {
        guard let entry = entries.last else { return }
        let total = entry.proteins + entry.carbs + entry.fats
        let data = [
            (value: entry.proteins, color: UIColor(red: 0.98, green: 0.76, blue: 0.34, alpha: 1)),
            (value: entry.carbs, color: UIColor(red: 0.35, green: 0.78, blue: 0.71, alpha: 1)),
            (value: entry.fats, color: UIColor(red: 0.56, green: 0.27, blue: 0.68, alpha: 1))
        ]
        uiView.updateChart(with: data, total: total)
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