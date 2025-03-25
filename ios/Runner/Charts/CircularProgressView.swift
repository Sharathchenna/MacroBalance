import UIKit

class CircularProgressView: UIView {
    // MARK: - Properties
    var progress: CGFloat = 0 {
        didSet {
            // Only animate if visible (avoids animation during initial setup)
            if superview != nil {
                animateProgress(from: oldValue, to: progress)
            } else {
                setNeedsDisplay()
            }
        }
    }
    
    var progressColor: UIColor = .systemBlue {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var trackColor: UIColor? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var showGlowEffect: Bool = true {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var showValueIndicator: Bool = false {
        didSet {
            valueIndicator.isHidden = !showValueIndicator
        }
    }
    
    var progressWidth: CGFloat = 5.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var progressValue: Int = 0 {
        didSet {
            valueIndicator.text = "\(progressValue)"
        }
    }
    
    var progressUnit: String = "" {
        didSet {
            unitLabel.text = progressUnit
        }
    }
    
    // Animation properties
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0
    private var animationFromValue: CGFloat = 0
    private var animationToValue: CGFloat = 0
    private var animationDuration: CFTimeInterval = 0.75
    
    // Shadow layer
    private let shadowLayer = CAShapeLayer()
    
    // Value indicator
    private let valueIndicator: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    private let unitLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        
        // Add value indicator labels
        addSubview(valueIndicator)
        addSubview(unitLabel)
        
        NSLayoutConstraint.activate([
            valueIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            valueIndicator.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            
            unitLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            unitLabel.topAnchor.constraint(equalTo: valueIndicator.bottomAnchor, constant: 2)
        ])
    }
    
    // MARK: - Animation
    private func animateProgress(from startValue: CGFloat, to endValue: CGFloat) {
        // Stop any existing animation
        displayLink?.invalidate()
        displayLink = nil
        
        // Set up animation values
        animationFromValue = startValue
        animationToValue = endValue
        animationStartTime = CACurrentMediaTime()
        
        // Create display link
        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        displayLink?.add(to: .main, forMode: .common)
        
        // Add small haptic feedback if progress increases significantly
        if endValue > startValue + 0.2 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    @objc private func handleDisplayLink(_ displayLink: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - animationStartTime
        
        if elapsed >= animationDuration {
            // Animation completed
            displayLink.invalidate()
            self.displayLink = nil
            setNeedsDisplay()
            return
        }
        
        // Calculate current progress using elastic ease-out for a nice spring effect
        let t = CGFloat(elapsed / animationDuration)
        
        // Custom elastic easing function
        let c4 = (2.0 * .pi) / 3.0
        let easedT: CGFloat
        
        if t == 0 {
            easedT = 0
        } else if t >= 1 {
            easedT = 1
        } else {
            easedT = pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1
        }
        
        let currentProgress = animationFromValue + (animationToValue - animationFromValue) * easedT
        
        // Only redraw if we have a meaningful change
        if abs(currentProgress - progress) > 0.001 {
            setNeedsDisplay()
        }
    }
    
    // MARK: - Drawing
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - progressWidth / 2
        
        // Determine if we're in dark mode
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        let glowOpacity: CGFloat = isDarkMode ? 0.7 : 0.5
        
        // Draw background circle (track)
        context.saveGState()
        context.setLineWidth(progressWidth)
        let actualTrackColor = trackColor ?? progressColor.withAlphaComponent(0.15)
        context.setStrokeColor(actualTrackColor.cgColor)
        context.setLineCap(.round)
        
        context.addArc(center: center,
                      radius: radius,
                      startAngle: 0,
                      endAngle: 2 * .pi,
                      clockwise: false)
        context.strokePath()
        context.restoreGState()
        
        // Draw glow effect if enabled
        if showGlowEffect && progress > 0.05 {
            context.saveGState()
            context.setLineWidth(progressWidth * 1.8)
            context.setStrokeColor(progressColor.withAlphaComponent(0.3).cgColor)
            context.setShadow(
                offset: .zero,
                blur: 10.0,
                color: progressColor.withAlphaComponent(glowOpacity).cgColor
            )
            
            let progressAngle = 2 * .pi * progress
            
            // Draw shorter arc for glow to avoid full circle shadow
            context.addArc(center: center,
                          radius: radius,
                          startAngle: -.pi / 2,
                          endAngle: progressAngle - .pi / 2,
                          clockwise: false)
            
            context.strokePath()
            context.restoreGState()
        }
        
        // Draw progress arc
        context.saveGState()
        context.setLineWidth(progressWidth)
        context.setStrokeColor(progressColor.cgColor)
        context.setLineCap(.round)
        
        let progressAngle = 2 * .pi * progress
        
        context.addArc(center: center,
                      radius: radius,
                      startAngle: -.pi / 2,
                      endAngle: progressAngle - .pi / 2,
                      clockwise: false)
        
        context.strokePath()
        context.restoreGState()
        
        // Draw endpoint marker dot if progress is greater than 0
        if progress > 0 {
            context.saveGState()
            
            // Calculate position of the endpoint
            let dotRadius = progressWidth * 0.8
            let angle = progressAngle - .pi / 2
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            
            // Draw shadow for dot
            context.setShadow(offset: CGSize(width: 0, height: 2), blur: 3, color: UIColor.black.withAlphaComponent(0.2).cgColor)
            
            // Draw dot
            context.setFillColor(progressColor.cgColor)
            context.addArc(center: CGPoint(x: x, y: y), radius: dotRadius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
            context.fillPath()
            
            context.restoreGState()
        }
        
        // Show value indicator if enabled
        valueIndicator.isHidden = !showValueIndicator
        unitLabel.isHidden = !showValueIndicator
        
        // Set value indicator color
        if progress >= 1.0 {
            valueIndicator.textColor = .systemGreen
        } else if progress >= 0.7 {
            valueIndicator.textColor = progressColor
        } else {
            valueIndicator.textColor = .label
        }
    }
    
    // MARK: - Configuration
    func configure(value: Int, goal: Int, progress: CGFloat, unit: String = "") {
        self.progressValue = value
        self.progressUnit = unit
        self.progress = min(max(progress, 0), 1.2) // Clamp between 0-120%
        
        // Make value indicator visible if configured
        if showValueIndicator {
            valueIndicator.text = "\(value)"
            unitLabel.text = unit
        }
    }
    
    // MARK: - Lifecycle
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Redraw when dark/light mode changes
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            setNeedsDisplay()
        }
    }
    
    // MARK: - Cleanup
    deinit {
        displayLink?.invalidate()
    }
} 