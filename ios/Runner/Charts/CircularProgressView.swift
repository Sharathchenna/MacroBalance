import UIKit

class CircularProgressView: UIView {
    // MARK: - Properties
    var progress: CGFloat = 0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var progressColor: UIColor = .systemBlue {
        didSet {
            setNeedsDisplay()
        }
    }
    
    private let progressWidth: CGFloat = 4
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - progressWidth
        
        // Draw background circle
        context.setLineWidth(progressWidth)
        context.setStrokeColor(progressColor.withAlphaComponent(0.2).cgColor)
        
        context.addArc(center: center,
                      radius: radius,
                      startAngle: 0,
                      endAngle: 2 * .pi,
                      clockwise: false)
        context.strokePath()
        
        // Draw progress arc
        context.setLineWidth(progressWidth)
        context.setStrokeColor(progressColor.cgColor)
        
        context.addArc(center: center,
                      radius: radius,
                      startAngle: -.pi / 2,
                      endAngle: 2 * .pi * progress - .pi / 2,
                      clockwise: false)
        context.strokePath()
    }
} 