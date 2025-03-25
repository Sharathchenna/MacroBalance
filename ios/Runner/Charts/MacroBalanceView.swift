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
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 20
        layer.masksToBounds = true
        
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(radarChartView)
        addSubview(balanceScoreView)
        
        NSLayoutConstraint.activate([
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            // Subtitle constraints
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            // Radar chart constraints
            radarChartView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            radarChartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            radarChartView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            radarChartView.widthAnchor.constraint(equalTo: heightAnchor, multiplier: 0.8),
            
            // Balance score view constraints
            balanceScoreView.centerYAnchor.constraint(equalTo: radarChartView.centerYAnchor),
            balanceScoreView.leadingAnchor.constraint(equalTo: radarChartView.trailingAnchor, constant: 8),
            balanceScoreView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            balanceScoreView.heightAnchor.constraint(equalToConstant: 100)
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
        let proteinPercentage = min(entry.proteins / entry.proteinGoal, 1.2) * 100
        let carbsPercentage = min(entry.carbs / entry.carbGoal, 1.2) * 100
        let fatsPercentage = min(entry.fats / entry.fatGoal, 1.2) * 100
        let caloriesPercentage = min(entry.calories / entry.calorieGoal, 1.2) * 100
        
        // Calculate additional nutrition metrics
        // Default to 50% if fiber is 0
        let fiberPercentage = entry.fiber > 0 ? min(entry.fiber / 25, 1.2) * 100 : 50 
        // Default to 60% if water is 0
        let waterPercentage = entry.water > 0 ? min(entry.water / 2500, 1.2) * 100 : 60 
        
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
        set.colors = [UIColor.systemIndigo]
        set.fillColor = UIColor.systemIndigo.withAlphaComponent(0.5)
        set.drawFilledEnabled = true
        set.fillAlpha = 0.7
        set.lineWidth = 2
        set.drawHighlightCircleEnabled = true
        set.highlightCircleFillColor = .systemIndigo
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
        
        // Animate chart with spring effect
        radarChartView.animate(xAxisDuration: 1.5, yAxisDuration: 1.5, easingOption: .easeOutBack)
    }
    
    private func updateBalanceScore(with entry: Models.MacrosEntry) {
        // Calculate balance score based on how close macros are to ideal proportions
        let proteinRatio = entry.proteins / entry.proteinGoal
        let carbsRatio = entry.carbs / entry.carbGoal
        let fatsRatio = entry.fats / entry.fatGoal
        
        // Give better scores for values close to 1.0 (100% of goal)
        // Penalize values that are either too low or too high
        let proteinScore = 100 - min(abs(proteinRatio - 1.0) * 100, 100)
        let carbsScore = 100 - min(abs(carbsRatio - 1.0) * 100, 100)
        let fatsScore = 100 - min(abs(fatsRatio - 1.0) * 100, 100)
        
        // Calculate overall score (weighted average)
        let overallScore = (proteinScore * 0.4 + carbsScore * 0.3 + fatsScore * 0.3)
        
        // Update the balance score view
        balanceScoreView.setScore(Int(overallScore), withAnimation: true)
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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .tertiarySystemBackground
        layer.cornerRadius = 16
        
        addSubview(scoreLabel)
        addSubview(captionLabel)
        addSubview(feedbackLabel)
        
        NSLayoutConstraint.activate([
            scoreLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            scoreLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            captionLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 4),
            captionLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            captionLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            
            feedbackLabel.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 8),
            feedbackLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            feedbackLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            feedbackLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -12)
        ])
        
        // Default score
        setScore(0, withAnimation: false)
    }
    
    func setScore(_ score: Int, withAnimation animate: Bool) {
        // Update score label with counting animation if requested
        if animate {
            countAnimation(from: Int(scoreLabel.text ?? "0") ?? 0, to: score)
        } else {
            scoreLabel.text = "\(score)"
        }
        
        // Update color based on score
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
    
    private func countAnimation(from: Int, to: Int) {
        // Reset any existing animation
        layer.removeAllAnimations()
        
        // Perform counting animation
        let steps = 20
        let duration = 1.0
        let stepDuration = duration / Double(steps)
        
        var currentStep = 0
        let stepValue = (to - from) / steps
        
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            let currentValue = from + (stepValue * currentStep)
            
            self.scoreLabel.text = "\(min(currentValue, to))"
            
            if currentStep >= steps {
                self.scoreLabel.text = "\(to)"
                timer.invalidate()
                
                // Add a subtle "pop" animation at the end
                UIView.animate(withDuration: 0.2, animations: {
                    self.scoreLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                }, completion: { _ in
                    UIView.animate(withDuration: 0.1) {
                        self.scoreLabel.transform = .identity
                    }
                })
            }
        }
    }
} 