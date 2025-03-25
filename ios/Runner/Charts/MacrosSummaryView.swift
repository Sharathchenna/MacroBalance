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
    
    private let remainingLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.text = "Remaining: --"
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
        
        addSubview(titleLabel)
        addSubview(remainingLabel)
        addSubview(stackView)
        
        [calorieView, proteinView, carbsView, fatView].forEach {
            stackView.addArrangedSubview($0)
        }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            remainingLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            remainingLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
        
        // Add tap gesture for interactivity
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Configuration
    func configure(with entry: Models.MacrosEntry?) {
        guard let entry = entry else {
            resetValues()
            return
        }
        
        // Store current entry
        self.currentEntry = entry
        
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
        
        // Update remaining calories
        updateRemainingLabel(entry: entry)
    }
    
    private func resetValues() {
        [calorieView, proteinView, carbsView, fatView].forEach {
            $0.configure(value: 0, goal: 0, progress: 0, unit: "g")
        }
        remainingLabel.text = "Remaining: --"
    }
    
    private func updateRemainingLabel(entry: Models.MacrosEntry) {
        let remaining = max(0, entry.calorieGoal - entry.calories)
        
        // Create attributed string with colored remaining value
        let attributedText = NSMutableAttributedString(string: "Remaining: ")
        
        let remainingString = "\(Int(remaining)) kcal"
        let coloredPart = NSAttributedString(
            string: remainingString,
            attributes: [
                .foregroundColor: remaining > 0 ? UIColor.systemGreen : UIColor.systemRed,
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold)
            ]
        )
        
        attributedText.append(coloredPart)
        remainingLabel.attributedText = attributedText
        
        // Add animation when remaining changes
        animateRemainingLabel()
    }
    
    private func animateRemainingLabel() {
        // Scale animation
        UIView.animate(withDuration: 0.2, animations: {
            self.remainingLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.remainingLabel.transform = .identity
            }
        })
    }
    
    @objc private func handleTap() {
        // Animate each macro item view in sequence
        animateItemsSequentially()
        
        // Provide haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func animateItemsSequentially() {
        let views = [calorieView, proteinView, carbsView, fatView]
        
        for (index, view) in views.enumerated() {
            // Stagger animations slightly
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                self.animateItemView(view)
            }
        }
    }
    
    private func animateItemView(_ view: MacroItemView) {
        UIView.animate(withDuration: 0.2, animations: {
            view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [], animations: {
                view.transform = .identity
            })
        })
    }
}

// MARK: - MacroItemView
class MacroItemView: UIView {
    // UI Components
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
        view.showValueIndicator = true
        return view
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
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add shadow
        view.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 1
        view.layer.masksToBounds = false
        
        return view
    }()
    
    // Properties
    private var color: UIColor
    private var currentValue: Int = 0
    private var goalValue: Int = 0
    private var unitText: String = ""
    
    // MARK: - Initialization
    init(title: String, color: UIColor, icon: String) {
        self.color = color
        super.init(frame: .zero)
        titleLabel.text = title
        iconView.image = UIImage(systemName: icon)
        progressRing.progressColor = color
        progressRing.progressWidth = 6
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Add card view first
        addSubview(cardView)
        
        // Add elements to card
        cardView.addSubview(titleLabel)
        cardView.addSubview(iconView)
        cardView.addSubview(progressRing)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Card constraints
            cardView.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
            
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            
            // Icon constraints
            iconView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            iconView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            // Progress ring constraints
            progressRing.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            progressRing.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            progressRing.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            progressRing.widthAnchor.constraint(equalToConstant: 70),
            progressRing.heightAnchor.constraint(equalToConstant: 70)
        ])
        
        // Add tap gesture for interaction
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        cardView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Configuration
    func configure(value: Int, goal: Int, progress: CGFloat, unit: String = "g") {
        self.currentValue = value
        self.goalValue = goal
        self.unitText = unit
        
        // Update progress color based on progress
        if progress > 1.0 {
            progressRing.progressColor = .systemRed
        } else if progress >= 0.9 {
            progressRing.progressColor = .systemGreen
        } else {
            progressRing.progressColor = color
        }
        
        // Configure progress ring
        progressRing.configure(
            value: value,
            goal: goal,
            progress: min(progress, 1.2), // Cap at 120% for visual feedback
            unit: unit
        )
    }
    
    // MARK: - Interaction
    @objc private func handleTap() {
        // Animate progress ring
        UIView.animate(withDuration: 0.2, animations: {
            self.progressRing.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.progressRing.transform = .identity
            }
        })
        
        // Format strings for alert
        let title = titleLabel.text ?? "Macro"
        let value = "\(currentValue) \(unitText)"
        let goal = "\(goalValue) \(unitText)"
        let percentage = Int(min((Double(currentValue) / max(1, Double(goalValue))) * 100, 100))
        
        // Show mini toast with value/goal
        showToast(message: "\(title): \(value)/\(goal) (\(percentage)%)")
        
        // Provide haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // MARK: - Toast
    private func showToast(message: String) {
        // Create toast label
        let toastLabel = UILabel()
        toastLabel.backgroundColor = UIColor.label.withAlphaComponent(0.8)
        toastLabel.textColor = .systemBackground
        toastLabel.font = .systemFont(ofSize: 12, weight: .medium)
        toastLabel.textAlignment = .center
        toastLabel.text = message
        toastLabel.alpha = 0
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Add to window for proper display
        if let window = UIApplication.shared.windows.first {
            window.addSubview(toastLabel)
            
            // Position the toast at the bottom of the window
            NSLayoutConstraint.activate([
                toastLabel.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                toastLabel.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                toastLabel.widthAnchor.constraint(lessThanOrEqualTo: window.widthAnchor, constant: -40),
                toastLabel.heightAnchor.constraint(equalToConstant: 36)
            ])
            
            // Add padding
            toastLabel.layoutIfNeeded()
            toastLabel.frame = toastLabel.frame.insetBy(dx: -20, dy: 0)
            
            // Animate in
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
                toastLabel.alpha = 1
            }, completion: { _ in
                // Animate out after delay
                UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseIn, animations: {
                    toastLabel.alpha = 0
                }, completion: { _ in
                    toastLabel.removeFromSuperview()
                })
            })
        }
    }
}

// The UIColor extensions are removed since they're defined in ChartUtilities.swift 