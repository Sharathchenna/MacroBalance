import UIKit

class GoalProgressView: UIView {
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Goal Progress"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let goalTypeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let headerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let recommendationView: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemBackground
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let recommendationIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .secondaryLabel
        imageView.image = UIImage(systemName: "lightbulb.fill")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let recommendationLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Progress bars
    private let proteinProgress = MacroProgressView(title: "Protein", color: UIColor(red: 0.94, green: 0.67, blue: 0.23, alpha: 1.0))
    private let carbsProgress = MacroProgressView(title: "Carbs", color: UIColor(red: 0.3, green: 0.69, blue: 0.64, alpha: 1.0))
    private let fatProgress = MacroProgressView(title: "Fat", color: UIColor(red: 0.91, green: 0.27, blue: 0.53, alpha: 1.0))
    
    // Animation properties
    private var isAnimating = false
    
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
        
        // Setup header stack with title and goal type
        addSubview(headerStack)
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(goalTypeLabel)
        
        // Setup recommendation view
        addSubview(recommendationView)
        recommendationView.addSubview(recommendationIcon)
        recommendationView.addSubview(recommendationLabel)
        
        // Setup progress stack
        addSubview(progressStackView)
        
        [proteinProgress, carbsProgress, fatProgress].forEach {
            progressStackView.addArrangedSubview($0)
        }
        
        NSLayoutConstraint.activate([
            // Header stack
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Recommendation view
            recommendationView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            recommendationView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            recommendationView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            recommendationIcon.topAnchor.constraint(equalTo: recommendationView.topAnchor, constant: 12),
            recommendationIcon.leadingAnchor.constraint(equalTo: recommendationView.leadingAnchor, constant: 12),
            recommendationIcon.widthAnchor.constraint(equalToConstant: 22),
            recommendationIcon.heightAnchor.constraint(equalToConstant: 22),
            
            recommendationLabel.topAnchor.constraint(equalTo: recommendationView.topAnchor, constant: 12),
            recommendationLabel.leadingAnchor.constraint(equalTo: recommendationIcon.trailingAnchor, constant: 10),
            recommendationLabel.trailingAnchor.constraint(equalTo: recommendationView.trailingAnchor, constant: -12),
            recommendationLabel.bottomAnchor.constraint(equalTo: recommendationView.bottomAnchor, constant: -12),
            
            // Progress stack
            progressStackView.topAnchor.constraint(equalTo: recommendationView.bottomAnchor, constant: 16),
            progressStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            progressStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            progressStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Configuration
    func configure(with entry: Models.MacrosEntry?, goalType: GoalType) {
        guard let entry = entry else {
            resetProgress()
            return
        }
        
        // Update goal type label
        goalTypeLabel.text = "Goal: \(goalType.displayName)"
        
        // Colorize goal type label based on goal type
        switch goalType {
        case .deficit:
            goalTypeLabel.textColor = UIColor.systemBlue
        case .maintenance:
            goalTypeLabel.textColor = UIColor.systemGreen
        case .surplus:
            goalTypeLabel.textColor = UIColor.systemOrange
        }
        
        // Update progress bars
        proteinProgress.configure(
            current: Int(entry.proteins),
            goal: Int(entry.proteinGoal),
            progress: CGFloat(entry.proteinGoalPercentage / 100)
        )
        
        carbsProgress.configure(
            current: Int(entry.carbs),
            goal: Int(entry.carbGoal),
            progress: CGFloat(entry.carbGoalPercentage / 100)
        )
        
        fatProgress.configure(
            current: Int(entry.fats),
            goal: Int(entry.fatGoal),
            progress: CGFloat(entry.fatGoalPercentage / 100)
        )
        
        // Update recommendation based on goal type and current progress
        updateRecommendation(for: goalType, with: entry)
    }
    
    func updateRecommendations(_ recommendations: MacroRecommendations) {
        // Start animation
        startUpdateAnimation()
        
        // Update progress bar goals
        proteinProgress.updateGoal(recommendations.proteinGoal)
        carbsProgress.updateGoal(recommendations.carbsGoal)
        fatProgress.updateGoal(recommendations.fatGoal)
        
        // Update recommendation text with animation
        UIView.transition(with: recommendationLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.recommendationLabel.text = recommendations.recommendation
        }
        
        // Complete animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.finishUpdateAnimation()
        }
    }
    
    private func resetProgress() {
        [proteinProgress, carbsProgress, fatProgress].forEach {
            $0.configure(current: 0, goal: 0, progress: 0)
        }
        recommendationLabel.text = "Set your macro goals to track progress"
        goalTypeLabel.text = "Goal: Not Set"
        goalTypeLabel.textColor = .secondaryLabel
    }
    
    private func updateRecommendation(for goalType: GoalType, with entry: Models.MacrosEntry) {
        let totalCalories = entry.calories
        let calorieGoal = entry.calorieGoal
        
        var recommendation: String
        var iconName = "lightbulb.fill"
        
        switch goalType {
        case .deficit:
            if totalCalories > calorieGoal {
                recommendation = "You're over your calorie goal. Focus on protein-rich foods to maintain muscle mass while cutting."
                iconName = "arrow.up.circle.fill"
            } else {
                recommendation = "Great job staying under your calorie goal! Keep protein high to preserve muscle."
                iconName = "checkmark.circle.fill"
            }
            
        case .maintenance:
            let difference = abs(totalCalories - calorieGoal)
            let threshold = calorieGoal * 0.1 // 10% threshold
            
            if difference <= threshold {
                recommendation = "You're right on track with your maintenance calories!"
                iconName = "checkmark.circle.fill"
            } else if totalCalories > calorieGoal {
                recommendation = "You're slightly over maintenance. Consider adjusting portion sizes."
                iconName = "arrow.up.circle.fill"
            } else {
                recommendation = "You're under maintenance. Consider adding a healthy snack."
                iconName = "arrow.down.circle.fill"
            }
            
        case .surplus:
            if totalCalories < calorieGoal {
                recommendation = "You're under your bulking calories. Try adding healthy calorie-dense foods."
                iconName = "arrow.down.circle.fill"
            } else if entry.proteinGoalPercentage < 90 {
                recommendation = "Hit your protein goal to maximize muscle growth."
                iconName = "exclamationmark.circle.fill"
            } else {
                recommendation = "Great job hitting your bulking goals! Keep it up!"
                iconName = "checkmark.circle.fill"
            }
        }
        
        recommendationLabel.text = recommendation
        recommendationIcon.image = UIImage(systemName: iconName)
        
        // Set appropriate icon color
        if iconName.contains("checkmark") {
            recommendationIcon.tintColor = .systemGreen
        } else if iconName.contains("exclamationmark") {
            recommendationIcon.tintColor = .systemYellow
        } else if iconName.contains("arrow.up") {
            recommendationIcon.tintColor = .systemRed
        } else if iconName.contains("arrow.down") {
            recommendationIcon.tintColor = .systemBlue
        } else {
            recommendationIcon.tintColor = .secondaryLabel
        }
    }
    
    // MARK: - Animation
    private func startUpdateAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        
        UIView.animate(withDuration: 0.2, animations: {
            self.progressStackView.alpha = 0.5
            self.recommendationView.alpha = 0.5
            self.progressStackView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            self.recommendationView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        })
    }
    
    private func finishUpdateAnimation() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
            self.progressStackView.alpha = 1.0
            self.recommendationView.alpha = 1.0
            self.progressStackView.transform = .identity
            self.recommendationView.transform = .identity
        }, completion: { _ in
            self.isAnimating = false
        })
    }
}

// MARK: - MacroProgressView
private class MacroProgressView: UIView {
    private let titleStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemBackground
        view.layer.cornerRadius = 6
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let progressBar: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let percentageLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressBackground: UIView = {
        let view = UIView()
        view.backgroundColor = .quaternarySystemFill
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var progressConstraint: NSLayoutConstraint?
    private var progressColor: UIColor
    private var currentValue: Int = 0
    private var goalValue: Int = 0
    
    init(title: String, color: UIColor) {
        self.progressColor = color
        super.init(frame: .zero)
        titleLabel.text = title
        progressBar.backgroundColor = color
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Add title and value label to title stack
        titleStackView.addArrangedSubview(titleLabel)
        titleStackView.addArrangedSubview(valueLabel)
        
        // Add stack view to main view
        addSubview(titleStackView)
        
        // Add progress container
        addSubview(progressContainer)
        
        // Add progress background and bar
        progressContainer.addSubview(progressBackground)
        progressContainer.addSubview(progressBar)
        
        // Add percentage label
        progressBar.addSubview(percentageLabel)
        
        NSLayoutConstraint.activate([
            titleStackView.topAnchor.constraint(equalTo: topAnchor),
            titleStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            progressContainer.topAnchor.constraint(equalTo: titleStackView.bottomAnchor, constant: 6),
            progressContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressContainer.heightAnchor.constraint(equalToConstant: 22),
            
            progressBackground.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressBackground.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressBackground.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            progressBackground.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
            
            progressBar.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressBar.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressBar.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
            
            percentageLabel.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            percentageLabel.centerXAnchor.constraint(equalTo: progressBar.centerXAnchor)
        ])
        
        // Create width constraint for progress bar (will be updated)
        progressConstraint = progressBar.widthAnchor.constraint(equalTo: progressContainer.widthAnchor, multiplier: 0)
        progressConstraint?.isActive = true
    }
    
    func configure(current: Int, goal: Int, progress: CGFloat) {
        currentValue = current
        goalValue = goal
        
        valueLabel.text = "\(current)/\(goal)g"
        
        // Calculate and set percentage
        let percentage = goal > 0 ? Int((Double(current) / Double(goal)) * 100) : 0
        percentageLabel.text = "\(percentage)%"
        
        // Animate progress bar
        let finalProgress = min(max(progress, 0), 1.5) // Cap between 0% and 150%
        
        // Update progress bar color based on progress
        if progress >= 0.9 && progress <= 1.1 {
            progressBar.backgroundColor = .systemGreen // On target
        } else if progress > 1.1 {
            progressBar.backgroundColor = .systemRed // Over
        } else {
            progressBar.backgroundColor = progressColor // Under
        }
        
        // Show/hide percentage label based on width
        UIView.animate(withDuration: 0.5) {
            self.progressConstraint?.constant = 0
            self.progressConstraint?.isActive = false
            self.progressConstraint = self.progressBar.widthAnchor.constraint(equalTo: self.progressContainer.widthAnchor, multiplier: CGFloat(finalProgress))
            self.progressConstraint?.isActive = true
            
            self.layoutIfNeeded()
            
            // Show percentage label only if enough width
            self.percentageLabel.alpha = finalProgress > 0.2 ? 1.0 : 0.0
        }
    }
    
    func updateGoal(_ goal: Int) {
        let currentProgress = currentValue > 0 && goal > 0 ? CGFloat(Double(currentValue) / Double(goal)) : 0
        configure(current: currentValue, goal: goal, progress: currentProgress)
    }
}

// MARK: - MacroRecommendations
struct MacroRecommendations {
    let proteinGoal: Int
    let carbsGoal: Int
    let fatGoal: Int
    let recommendation: String
}

// MARK: - MacroRecommendationService
enum MacroRecommendationService {
    static func getRecommendations(for goalType: GoalType) -> MacroRecommendations {
        switch goalType {
        case .deficit:
            return MacroRecommendations(
                proteinGoal: 180,
                carbsGoal: 150,
                fatGoal: 50,
                recommendation: "Higher protein, lower carbs for muscle preservation during cutting"
            )
            
        case .maintenance:
            return MacroRecommendations(
                proteinGoal: 150,
                carbsGoal: 200,
                fatGoal: 65,
                recommendation: "Balanced macros for maintaining current body composition"
            )
            
        case .surplus:
            return MacroRecommendations(
                proteinGoal: 180,
                carbsGoal: 300,
                fatGoal: 80,
                recommendation: "Higher overall calories with emphasis on protein and carbs for muscle growth"
            )
        }
    }
}

// MARK: - GoalType with proper implementation
extension GoalType {
    var displayName: String {
        switch self {
        case .deficit: return "Weight Loss"
        case .maintenance: return "Maintenance"
        case .surplus: return "Muscle Gain"
        }
    }
}