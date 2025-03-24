import UIKit

class GoalProgressView: UIView {
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Goal Progress"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
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
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Progress bars
    private let proteinProgress = MacroProgressView(title: "Protein", color: .proteinColor)
    private let carbsProgress = MacroProgressView(title: "Carbs", color: .carbColor)
    private let fatProgress = MacroProgressView(title: "Fat", color: .fatColor)
    
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
        
        addSubview(stackView)
        
        [titleLabel, recommendationLabel, progressStackView].forEach {
            stackView.addArrangedSubview($0)
        }
        
        [proteinProgress, carbsProgress, fatProgress].forEach {
            progressStackView.addArrangedSubview($0)
        }
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Configuration
    func configure(with entry: Models.MacrosEntry?, goalType: GoalType) {
        guard let entry = entry else {
            resetProgress()
            return
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
        // Update progress bar goals
        proteinProgress.updateGoal(recommendations.proteinGoal)
        carbsProgress.updateGoal(recommendations.carbsGoal)
        fatProgress.updateGoal(recommendations.fatGoal)
        
        // Update recommendation text
        recommendationLabel.text = recommendations.recommendation
    }
    
    private func resetProgress() {
        [proteinProgress, carbsProgress, fatProgress].forEach {
            $0.configure(current: 0, goal: 0, progress: 0)
        }
        recommendationLabel.text = "Set your macro goals to track progress"
    }
    
    private func updateRecommendation(for goalType: GoalType, with entry: Models.MacrosEntry) {
        let totalCalories = entry.calories
        let calorieGoal = entry.calorieGoal
        
        var recommendation: String
        
        switch goalType {
        case .cutting:
            if totalCalories > calorieGoal {
                recommendation = "You're over your calorie goal. Focus on protein-rich foods to maintain muscle mass while cutting."
            } else {
                recommendation = "Great job staying under your calorie goal! Keep protein high to preserve muscle."
            }
            
        case .maintenance:
            let difference = abs(totalCalories - calorieGoal)
            let threshold = calorieGoal * 0.1 // 10% threshold
            
            if difference <= threshold {
                recommendation = "You're right on track with your maintenance calories!"
            } else if totalCalories > calorieGoal {
                recommendation = "You're slightly over maintenance. Consider adjusting portion sizes."
            } else {
                recommendation = "You're under maintenance. Consider adding a healthy snack."
            }
            
        case .bulking:
            if totalCalories < calorieGoal {
                recommendation = "You're under your bulking calories. Try adding healthy calorie-dense foods."
            } else if entry.proteinGoalPercentage < 90 {
                recommendation = "Hit your protein goal to maximize muscle growth."
            } else {
                recommendation = "Great job hitting your bulking goals! Keep it up!"
            }
        }
        
        recommendationLabel.text = recommendation
    }
}

// MARK: - MacroProgressView
private class MacroProgressView: UIView {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressBar: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .bar)
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.layer.cornerRadius = 4
        progress.clipsToBounds = true
        return progress
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init(title: String, color: UIColor) {
        super.init(frame: .zero)
        titleLabel.text = title
        progressBar.progressTintColor = color
        progressBar.trackTintColor = color.withAlphaComponent(0.2)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        [titleLabel, progressBar, valueLabel].forEach { addSubview($0) }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            
            progressBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 8),
            
            valueLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(current: Int, goal: Int, progress: CGFloat) {
        valueLabel.text = "\(current)g / \(goal)g"
        UIView.animate(withDuration: 0.5) {
            self.progressBar.progress = Float(min(progress, 1.0))
        }
    }
    
    func updateGoal(_ goal: Int) {
        let current = Int(valueLabel.text?.components(separatedBy: "g /").first ?? "0") ?? 0
        configure(current: current, goal: goal, progress: CGFloat(Double(current) / Double(goal)))
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
        case .cutting:
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
            
        case .bulking:
            return MacroRecommendations(
                proteinGoal: 180,
                carbsGoal: 300,
                fatGoal: 80,
                recommendation: "Higher overall calories with emphasis on protein and carbs for muscle growth"
            )
        }
    }
} 