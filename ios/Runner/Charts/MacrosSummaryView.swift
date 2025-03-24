import UIKit

class MacrosSummaryView: UIView {
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Daily Overview"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let calorieView = MacroItemView(title: "Calories", color: .systemIndigo, icon: "flame.fill")
    private let proteinView = MacroItemView(title: "Protein", color: .proteinColor, icon: "p.circle.fill")
    private let carbsView = MacroItemView(title: "Carbs", color: .carbColor, icon: "c.circle.fill")
    private let fatView = MacroItemView(title: "Fat", color: .fatColor, icon: "f.circle.fill")
    
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
        
        addSubview(titleLabel)
        addSubview(stackView)
        
        [calorieView, proteinView, carbsView, fatView].forEach {
            stackView.addArrangedSubview($0)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Configuration
    func configure(with entry: Models.MacrosEntry?) {
        guard let entry = entry else {
            resetValues()
            return
        }
        
        // Configure calorie view
        let calorieProgress = entry.calorieGoal > 0 ? entry.calories / entry.calorieGoal : 0
        calorieView.configure(
            value: Int(entry.calories),
            goal: Int(entry.calorieGoal),
            progress: CGFloat(calorieProgress),
            unit: "kcal"
        )
        
        // Configure protein view
        let proteinProgress = entry.proteinGoal > 0 ? entry.proteins / entry.proteinGoal : 0
        proteinView.configure(
            value: Int(entry.proteins),
            goal: Int(entry.proteinGoal),
            progress: CGFloat(proteinProgress),
            unit: "g"
        )
        
        // Configure carbs view
        let carbsProgress = entry.carbGoal > 0 ? entry.carbs / entry.carbGoal : 0
        carbsView.configure(
            value: Int(entry.carbs),
            goal: Int(entry.carbGoal),
            progress: CGFloat(carbsProgress),
            unit: "g"
        )
        
        // Configure fat view
        let fatProgress = entry.fatGoal > 0 ? entry.fats / entry.fatGoal : 0
        fatView.configure(
            value: Int(entry.fats),
            goal: Int(entry.fatGoal),
            progress: CGFloat(fatProgress),
            unit: "g"
        )
    }
    
    private func resetValues() {
        [calorieView, proteinView, carbsView, fatView].forEach {
            $0.configure(value: 0, goal: 0, progress: 0, unit: "g")
        }
    }
}

// MARK: - MacroItemView
private class MacroItemView: UIView {
    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .tertiaryLabel
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressRing: CircularProgressView = {
        let view = CircularProgressView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let valueStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let goalLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .tertiaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var color: UIColor
    
    init(title: String, color: UIColor, icon: String) {
        self.color = color
        super.init(frame: .zero)
        titleLabel.text = title
        iconView.image = UIImage(systemName: icon)
        progressRing.progressColor = color
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Add card view first
        addSubview(cardView)
        
        // Add elements to card
        cardView.addSubview(titleLabel)
        cardView.addSubview(iconView)
        cardView.addSubview(progressRing)
        cardView.addSubview(valueStack)
        
        // Add labels to value stack
        valueStack.addArrangedSubview(valueLabel)
        valueStack.addArrangedSubview(goalLabel)
        
        NSLayoutConstraint.activate([
            // Card constraints
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 10),
            
            // Icon constraints
            iconView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            iconView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            // Progress ring constraints
            progressRing.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            progressRing.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            progressRing.widthAnchor.constraint(equalToConstant: 60),
            progressRing.heightAnchor.constraint(equalToConstant: 60),
            
            // Value stack constraints
            valueStack.centerXAnchor.constraint(equalTo: progressRing.centerXAnchor),
            valueStack.centerYAnchor.constraint(equalTo: progressRing.centerYAnchor),
            valueStack.leadingAnchor.constraint(greaterThanOrEqualTo: cardView.leadingAnchor, constant: 4),
            valueStack.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -4),
            valueStack.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(value: Int, goal: Int, progress: CGFloat, unit: String) {
        valueLabel.text = "\(value)"
        goalLabel.text = "/ \(goal) \(unit)"
        
        // Update progress color based on progress
        if progress > 1.0 {
            progressRing.progressColor = .systemRed
        } else if progress >= 0.9 {
            progressRing.progressColor = .systemGreen
        } else {
            progressRing.progressColor = color
        }
        
        // Animate progress
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            self.progressRing.progress = min(progress, 1.2) // Cap at 120% for visual feedback
        }
    }
} 