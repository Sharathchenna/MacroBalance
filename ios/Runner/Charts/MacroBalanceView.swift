import UIKit
import DGCharts

class MacroBalanceView: UIView {
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Macro Balance"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "See how your macros are balanced"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let radarChartView: RadarChartView = {
        let chart = RadarChartView()
        chart.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure chart appearance
        chart.webLineWidth = 1.0
        chart.webColor = UIColor.quaternaryLabel
        chart.webAlpha = 0.8
        
        // Configure rotation and interaction
        chart.rotationEnabled = true
        chart.highlightPerTapEnabled = true
        
        // Configure legend
        chart.legend.enabled = true
        chart.legend.horizontalAlignment = .center
        chart.legend.verticalAlignment = .bottom
        chart.legend.orientation = .horizontal
        chart.legend.drawInside = false
        chart.legend.font = .systemFont(ofSize: 12)
        chart.legend.xEntrySpace = 10
        chart.legend.textColor = .label
        
        // Configure y-axis
        chart.yAxis.labelFont = .systemFont(ofSize: 9)
        chart.yAxis.labelTextColor = .secondaryLabel
        chart.yAxis.axisMinimum = 0
        chart.yAxis.drawLabelsEnabled = false
        
        // Configure x-axis
        chart.xAxis.labelFont = .systemFont(ofSize: 11, weight: .medium)
        chart.xAxis.labelTextColor = .label
        chart.xAxis.labelPosition = .bottom
        
        // Configure description
        chart.chartDescription.enabled = false
        
        // Add animation spring effect
        chart.animate(xAxisDuration: 1.4, yAxisDuration: 1.4, easingOption: .easeOutBack)
        
        return chart
    }()
    
    // Instantiate BalanceScoreView here
    private let balanceScoreView = BalanceScoreView()
    
    // MARK: - Properties
    private var currentEntry: Models.MacrosEntry?
    
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
        backgroundColor = .secondarySystemGroupedBackground // Card background
        layer.cornerRadius = 18 // Consistent radius
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.08
        layer.masksToBounds = false
        
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(radarChartView)
        addSubview(balanceScoreView) // Add the instance to the view hierarchy
        
        // Ensure translatesAutoresizingMaskIntoConstraints is set *before* activating constraints
        balanceScoreView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            // Subtitle constraints
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Balance score view constraints
            // balanceScoreView.translatesAutoresizingMaskIntoConstraints = false, // Moved outside activate block
            balanceScoreView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            balanceScoreView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            balanceScoreView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Radar chart constraints
            radarChartView.topAnchor.constraint(equalTo: balanceScoreView.bottomAnchor, constant: 12),
            radarChartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            radarChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            radarChartView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            radarChartView.heightAnchor.constraint(equalTo: radarChartView.widthAnchor, multiplier: 0.8)
        ])
    }
    
    // MARK: - Configuration
    func configure(with entry: Models.MacrosEntry) {
        self.currentEntry = entry
        updateRadarChart(with: entry)
        updateBalanceScore(with: entry)
    }
    
    private func updateRadarChart(with entry: Models.MacrosEntry) {
        // Calculate percentages of goal for each macro
        let proteinPercentage = entry.proteinGoal > 0 ? min(entry.proteins / entry.proteinGoal, 1.2) * 100 : 0
        let carbsPercentage = entry.carbGoal > 0 ? min(entry.carbs / entry.carbGoal, 1.2) * 100 : 0
        let fatsPercentage = entry.fatGoal > 0 ? min(entry.fats / entry.fatGoal, 1.2) * 100 : 0
        let caloriesPercentage = entry.calorieGoal > 0 ? min(entry.calories / entry.calorieGoal, 1.2) * 100 : 0
        
        // Calculate additional nutrition metrics
        let fiberPercentage = entry.fiber > 0 ? min(entry.fiber / 25, 1.2) * 100 : 50 // Default to 50% if fiber is 0
        let waterPercentage = entry.water > 0 ? min(entry.water / 2500, 1.2) * 100 : 60 // Default to 60% if water is 0
        
        // Create radar data entries
        let radarEntries = [
            RadarChartDataEntry(value: Double(proteinPercentage)),
            RadarChartDataEntry(value: Double(carbsPercentage)),
            RadarChartDataEntry(value: Double(fatsPercentage)),
            RadarChartDataEntry(value: Double(caloriesPercentage)),
            RadarChartDataEntry(value: Double(fiberPercentage)),
            RadarChartDataEntry(value: Double(waterPercentage))
        ]
        
        // Create dataset
        let set = RadarChartDataSet(entries: radarEntries, label: "Macro Balance")
        set.colors = [UIColor.systemIndigo.withAlphaComponent(0.9)]
        set.fillColor = UIColor.systemIndigo.withAlphaComponent(0.4)
        set.drawFilledEnabled = true
        set.fillAlpha = 0.6
        set.lineWidth = 2.5
        set.drawHighlightCircleEnabled = true
        set.highlightCircleFillColor = .systemIndigo.withAlphaComponent(0.8)
        set.highlightCircleStrokeColor = .white
        set.highlightCircleStrokeWidth = 2
        set.drawValuesEnabled = false
        
        // Create and set chart data
        let data = RadarChartData(dataSet: set)
        radarChartView.data = data
        
        // Configure axis labels
        radarChartView.xAxis.valueFormatter = IndexAxisValueFormatter(values: ["Protein", "Carbs", "Fats", "Calories", "Fiber", "Water"])
        
        // Set visible range
        radarChartView.yAxis.axisMaximum = 120 // Max 120% to show overages
        
        // Animate chart
        radarChartView.animate(xAxisDuration: 1.5, yAxisDuration: 1.5, easingOption: .easeOutBack)
    }
    
    private func updateBalanceScore(with entry: Models.MacrosEntry) {
        // Calculate balance score
        let proteinRatio = entry.proteinGoal > 0 ? entry.proteins / entry.proteinGoal : 0
        let carbsRatio = entry.carbGoal > 0 ? entry.carbs / entry.carbGoal : 0
        let fatsRatio = entry.fatGoal > 0 ? entry.fats / entry.fatGoal : 0
        
        let proteinScore = 100 - min(abs(proteinRatio - 1.0) * 100, 100)
        let carbsScore = 100 - min(abs(carbsRatio - 1.0) * 100, 100)
        let fatsScore = 100 - min(abs(fatsRatio - 1.0) * 100, 100)
        
        let overallScore = (proteinScore * 0.4 + carbsScore * 0.3 + fatsScore * 0.3)
        
        // Update the balance score view
        balanceScoreView.setScore(Int(overallScore), withAnimation: true) // Keep animation call, but logic inside setScore is simplified
    }
}

// MARK: - Balance Score View
class BalanceScoreView: UIView {
    private let scoreLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 36, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let captionLabel: UILabel = {
        let label = UILabel()
        label.text = "Balance Score"
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let feedbackLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
    
    private func setupUI() {
        backgroundColor = .clear
        
        addSubview(scoreLabel)
        addSubview(captionLabel)
        addSubview(feedbackLabel)
        
        NSLayoutConstraint.activate([
            scoreLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            scoreLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            captionLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 8), // Increased spacing
            captionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            feedbackLabel.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 6),
            feedbackLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            feedbackLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            feedbackLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            feedbackLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        setScore(0, withAnimation: false)
    }
    
    func setScore(_ score: Int, withAnimation animate: Bool) {
        // Simplified version without CADisplayLink animation for now
        scoreLabel.text = "\(score)"
        
        // Still apply pop animation if requested
        if animate {
             scoreLabel.transform = .identity // Reset transform before animating
             UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
                 self.scoreLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
             }, completion: { _ in
                 UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseIn, animations: {
                     self.scoreLabel.transform = .identity
                 })
             })
        }

        // Update color and feedback text
        if score >= 85 {
            scoreLabel.textColor = .systemGreen
            feedbackLabel.text = "Excellent macro balance!"
        } else if score >= 70 {
            scoreLabel.textColor = .systemYellow
            feedbackLabel.text = "Good balance, small adjustments needed"
        } else {
            scoreLabel.textColor = .systemRed
            feedbackLabel.text = "Improve your macro ratios for better results"
        }
    }

    // Keep animation functions commented out
    /*
    private func countAnimation(from: Int, to: Int) {
        // ... Full CADisplayLink logic ...
    }
    
    @objc private func updateCountAnimation(_ displayLink: CADisplayLink) {
        // ... Full CADisplayLink logic ...
    }
    */
} // End of BalanceScoreView class

// Keep associated object keys commented out
/*
private var displayLinkKey: UInt8 = 0
private var startTimeKey: UInt8 = 1
private var fromValueKey: UInt8 = 2
private var toValueKey: UInt8 = 3
private var durationKey: UInt8 = 4
*/
