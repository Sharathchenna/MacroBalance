import UIKit

// Renamed to avoid redeclaration conflict
class MacroCircularProgressView: UIView {
    private let progressLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()
    
    var progress: Float = 0 {
        didSet {
            updateProgress()
        }
    }
    
    init(progress: Float, color: UIColor) {
        self.progress = progress
        super.init(frame: .zero)
        setup(color: color)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup(color: .systemGreen)
    }
    
    private func setup(color: UIColor) {
        backgroundLayer.fillColor = nil
        backgroundLayer.strokeColor = UIColor.systemGray5.cgColor
        backgroundLayer.lineWidth = 12
        layer.addSublayer(backgroundLayer)
        
        progressLayer.fillColor = nil
        progressLayer.strokeColor = color.cgColor
        progressLayer.lineWidth = 12
        progressLayer.lineCap = .round
        layer.addSublayer(progressLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - progressLayer.lineWidth / 2
        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + 2 * CGFloat.pi
        
        let path = UIBezierPath(arcCenter: center,
                               radius: radius,
                               startAngle: startAngle,
                               endAngle: endAngle,
                               clockwise: true)
        
        backgroundLayer.path = path.cgPath
        progressLayer.path = path.cgPath
        
        updateProgress()
    }
    
    private func updateProgress() {
        progressLayer.strokeEnd = CGFloat(progress)
        
        // Add animation
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = progress
        animation.duration = 1
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        progressLayer.add(animation, forKey: "progressAnimation")
    }
} 