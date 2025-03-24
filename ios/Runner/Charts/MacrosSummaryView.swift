import UIKit

class MacrosSummaryView: UIView {
    // MARK: - UI Components
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let calorieView = MacroItemView(title: "Calories", color: .systemBlue)
    private let proteinView = MacroItemView(title: "Protein", color: .proteinColor)
    private let carbsView = MacroItemView(title: "Carbs", color: .carbColor)
    private let fatView = MacroItemView(title: "Fat", color: .fatColor)
    
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
        
        [calorieView, proteinView, carbsView, fatView].forEach {
            stackView.addArrangedSubview($0)
        }
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
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
            progress: CGFloat(calorieProgress)
        )
        
        // Configure protein view
        let proteinProgress = entry.proteinGoal > 0 ? entry.proteins / entry.proteinGoal : 0
        proteinView.configure(
            value: Int(entry.proteins),
            goal: Int(entry.proteinGoal),
            progress: CGFloat(proteinProgress)
        )
        
        // Configure carbs view
        let carbsProgress = entry.carbGoal > 0 ? entry.carbs / entry.carbGoal : 0
        carbsView.configure(
            value: Int(entry.carbs),
            goal: Int(entry.carbGoal),
            progress: CGFloat(carbsProgress)
        )
        
        // Configure fat view
        let fatProgress = entry.fatGoal > 0 ? entry.fats / entry.fatGoal : 0
        fatView.configure(
            value: Int(entry.fats),
            goal: Int(entry.fatGoal),
            progress: CGFloat(fatProgress)
        )
    }
    
    private func resetValues() {
        [calorieView, proteinView, carbsView, fatView].forEach {
            $0.configure(value: 0, goal: 0, progress: 0)
        }
    }
}

// MARK: - MacroItemView
private class MacroItemView: UIView {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let progressRing: CircularProgressView = {
        let view = CircularProgressView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    init(title: String, color: UIColor) {
        super.init(frame: .zero)
        titleLabel.text = title
        progressRing.progressColor = color
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(stackView)
        
        [titleLabel, progressRing, valueLabel].forEach {
            stackView.addArrangedSubview($0)
        }
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            progressRing.widthAnchor.constraint(equalToConstant: 44),
            progressRing.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    func configure(value: Int, goal: Int, progress: CGFloat) {
        valueLabel.text = "\(value)/\(goal)"
        progressRing.progress = min(progress, 1.0)
    }
} 