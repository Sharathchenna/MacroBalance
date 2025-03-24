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
    
    private let progressWidth: CGFloat = 5.0
    private var displayLink: CADisplayLink?
    private var animationStartTime: CFTimeInterval = 0
    private var animationFromValue: CGFloat = 0
    private var animationToValue: CGFloat = 0
    private var animationDuration: CFTimeInterval = 0.75
    
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
        
        // Calculate current progress using easeOutQuart timing function for a nice spring effect
        let t = CGFloat(elapsed / animationDuration)
        let easedT = 1 - pow(1 - t, 4) // easeOutQuart
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
            context.setStrokeColor(progressColor.withAlphaComponent(0.25).cgColor)
            context.setShadow(
                offset: .zero,
                blur: 5.0,
                color: progressColor.withAlphaComponent(0.5).cgColor
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
    }
    
    // MARK: - Cleanup
    deinit {
        displayLink?.invalidate()
    }
} 