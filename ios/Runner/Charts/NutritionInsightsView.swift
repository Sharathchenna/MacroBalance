import UIKit

class NutritionInsightsView: UIView {
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Nutrition Insights"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let aiIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "sparkles")
        imageView.tintColor = .systemIndigo
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let insightsTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.isScrollEnabled = false
        tableView.showsVerticalScrollIndicator = false
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        return tableView
    }()
    
    private let refreshButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        button.tintColor = .systemIndigo
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let emptyStateImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chart.bar.doc.horizontal")
        imageView.tintColor = .tertiaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "Log meals to get personalized insights"
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Properties
    private var insights: [NutritionInsight] = []
    private var isLoading = false
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupTableView()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupTableView()
        setupActions()
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
        
        // Add subviews
        addSubview(titleLabel)
        addSubview(aiIconView)
        addSubview(insightsTableView)
        addSubview(refreshButton)
        
        // Empty state setup
        addSubview(emptyStateView)
        emptyStateView.addSubview(emptyStateImageView)
        emptyStateView.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            // AI icon constraints
            aiIconView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            aiIconView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            aiIconView.widthAnchor.constraint(equalToConstant: 22), // Slightly larger
            aiIconView.heightAnchor.constraint(equalToConstant: 22),
            
            // Refresh button constraints
            refreshButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            refreshButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            // Let intrinsic size determine width/height if possible, or use slightly larger fixed size
            
            // Table view constraints
            insightsTableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12), // More space
            insightsTableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0), // Edge to edge within card
            insightsTableView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
            insightsTableView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8), // Padding at bottom
            
            // Empty state view constraints (Center within the table view area)
            emptyStateView.leadingAnchor.constraint(equalTo: insightsTableView.leadingAnchor, constant: 16),
            emptyStateView.trailingAnchor.constraint(equalTo: insightsTableView.trailingAnchor, constant: -16),
            emptyStateView.centerXAnchor.constraint(equalTo: insightsTableView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: insightsTableView.centerYAnchor, constant: -20), // Adjust vertical offset
            
            // Empty state image constraints
            emptyStateImageView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateImageView.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyStateImageView.widthAnchor.constraint(equalToConstant: 44), // Larger icon
            emptyStateImageView.heightAnchor.constraint(equalToConstant: 44),
            
            // Empty state label constraints
            emptyStateLabel.topAnchor.constraint(equalTo: emptyStateImageView.bottomAnchor, constant: 12), // More space
            emptyStateLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: emptyStateView.leadingAnchor), // Allow shrinking
            emptyStateLabel.trailingAnchor.constraint(lessThanOrEqualTo: emptyStateView.trailingAnchor),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            emptyStateLabel.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor)
        ])
    }
    
    private func setupTableView() {
        insightsTableView.register(InsightCell.self, forCellReuseIdentifier: "InsightCell")
        insightsTableView.dataSource = self as UITableViewDataSource
        insightsTableView.delegate = self as UITableViewDelegate
    }
    
    private func setupActions() {
        refreshButton.addTarget(self, action: #selector(refreshInsights), for: .touchUpInside)
    }
    
    // MARK: - Configuration
    func configure(with entries: [Models.MacrosEntry]) {
        if entries.isEmpty {
            showEmptyState()
            return
        }
        
        // If we already have insights, just update the UI
        if !insights.isEmpty {
            insightsTableView.reloadData()
            hideEmptyState()
            return
        }
        
        // Generate insights based on the entries
        generateInsights(from: entries)
    }
    
    private func showEmptyState() {
        emptyStateView.isHidden = false
        insightsTableView.isHidden = true
    }
    
    private func hideEmptyState() {
        emptyStateView.isHidden = true
        insightsTableView.isHidden = false
    }
    
    @objc private func refreshInsights() {
        // Show loading indicator
        startLoadingAnimation()
        
        // Simulating API call with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            // Shuffle the insights for demonstration purposes
            self.insights.shuffle()
            
            // Add a new random insight
            let randomInsight = NutritionInsight.generateRandomInsight()
            self.insights.append(randomInsight)
            
            // Update UI
            self.insightsTableView.reloadData()
            self.stopLoadingAnimation()
            
            // Apply haptic feedback
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    private func startLoadingAnimation() {
        isLoading = true
        
        // Start rotation animation
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = 2 * Double.pi
        rotation.duration = 0.8 // Faster rotation
        rotation.repeatCount = .infinity
        refreshButton.layer.add(rotation, forKey: "rotationAnimation")
        
        // Disable button and fade slightly
        refreshButton.isEnabled = false
        UIView.animate(withDuration: 0.2) {
            self.refreshButton.alpha = 0.5
        }
    }
    
    private func stopLoadingAnimation() {
        isLoading = false
        
        // Stop rotation animation
        refreshButton.layer.removeAnimation(forKey: "rotationAnimation")
        
        // Enable button and restore alpha
        refreshButton.isEnabled = true
        UIView.animate(withDuration: 0.2) {
            self.refreshButton.alpha = 1.0
        }
    }
    
    private func generateInsights(from entries: [Models.MacrosEntry]) {
        // Simulate loading
        startLoadingAnimation()
        
        // In a real app, you would analyze data and generate actual insights
        // For demo purposes, we'll generate some sample insights
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            self.insights = NutritionInsight.generateSampleInsights()
            
            // Update UI
            self.hideEmptyState()
            self.insightsTableView.reloadData()
            self.stopLoadingAnimation()
        }
    }
}

// MARK: - UITableViewDataSource
extension NutritionInsightsView: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return insights.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "InsightCell", for: indexPath) as? InsightCell else {
            return UITableViewCell()
        }
        
        let insight = insights[indexPath.row]
        cell.configure(with: insight)
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension NutritionInsightsView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Expand/collapse the selected insight
        let insight = insights[indexPath.row]
        insight.isExpanded.toggle()
        
        // Update cell with animation
        tableView.reloadRows(at: [indexPath], with: .fade) // Use fade animation
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - InsightCell
class InsightCell: UITableViewCell {
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemIndigo
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground // Use primary background for cell cards
        view.layer.cornerRadius = 14 // Slightly larger radius
        view.translatesAutoresizingMaskIntoConstraints = false
        // Shadow will be applied in configure
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(cardView)
        cardView.addSubview(iconImageView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(detailLabel)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4), // Less vertical space between cells
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12), // More horizontal padding for main view
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            iconImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14), // More padding
            iconImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            iconImageView.widthAnchor.constraint(equalToConstant: 26), // Slightly larger icon
            iconImageView.heightAnchor.constraint(equalToConstant: 26),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor), // Align title with icon top
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10), // Adjust spacing
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6), // Adjust spacing
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            detailLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14) // More padding
        ])
    }
    
    func configure(with insight: NutritionInsight) {
        iconImageView.image = UIImage(systemName: insight.iconName)
        titleLabel.text = insight.title
        
        // Show full or truncated description based on expanded state
        if insight.isExpanded {
            detailLabel.text = insight.detailedDescription
        } else {
            detailLabel.text = insight.shortDescription
        }
        
        // Apply card shadow
        applyShadow()
        
        // Apply color based on type
        titleLabel.textColor = insight.type.color
        iconImageView.tintColor = insight.type.color
    }
    
    private func applyShadow() {
        // Refined shadow for cell cards
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4
        cardView.layer.shadowOpacity = 0.06 // Subtle shadow
        cardView.layer.masksToBounds = false
    }
}

// MARK: - Nutrition Insight Model
class NutritionInsight {
    enum InsightType {
        case suggestion
        case achievement
        case warning
        case tip
        
        var color: UIColor {
            switch self {
            case .suggestion: return .systemIndigo
            case .achievement: return .systemGreen
            case .warning: return .systemOrange
            case .tip: return .systemBlue
            }
        }
        
        var iconName: String {
            switch self {
            case .suggestion: return "lightbulb.fill"
            case .achievement: return "crown.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .tip: return "info.circle.fill"
            }
        }
    }
    
    let title: String
    let shortDescription: String
    let detailedDescription: String
    let type: InsightType
    let iconName: String
    var isExpanded: Bool = false
    
    init(title: String, shortDescription: String, detailedDescription: String, type: InsightType, iconName: String? = nil) {
        self.title = title
        self.shortDescription = shortDescription
        self.detailedDescription = detailedDescription
        self.type = type
        self.iconName = iconName ?? type.iconName
    }
    
    static func generateSampleInsights() -> [NutritionInsight] {
        return [
            NutritionInsight(
                title: "Protein Goals Consistently Met",
                shortDescription: "You've been hitting your protein targets consistently.",
                detailedDescription: "Great job! You've been meeting your protein goals consistently for the past 5 days. Maintaining adequate protein intake helps with muscle preservation and recovery, especially during periods of caloric deficit. Keep it up!",
                type: .achievement
            ),
            NutritionInsight(
                title: "Carb Intake Trending High",
                shortDescription: "Your carb intake has been higher than your target.",
                detailedDescription: "Your carbohydrate intake has exceeded your targets by 15-20% over the past week. Consider replacing some carb sources with more protein or healthy fats to help balance your macros. Try adding more vegetables and reducing refined carbohydrates.",
                type: .warning
            ),
            NutritionInsight(
                title: "Try Meal Prepping",
                shortDescription: "Meal prepping can help you maintain your macro goals.",
                detailedDescription: "Based on your meal patterns, you might benefit from meal prepping. Try preparing proteins and complex carbs in advance for 2-3 days. This has been shown to improve adherence to nutrition goals by 40% in similar users. Would you like some simple meal prep recipes?",
                type: .suggestion,
                iconName: "fork.knife"
            )
        ]
    }
    
    static func generateRandomInsight() -> NutritionInsight {
        let randomInsights = [
            NutritionInsight(
                title: "Increase Water Intake",
                shortDescription: "Your hydration could use some improvement.",
                detailedDescription: "Based on your activity level and nutrition profile, we recommend increasing your water intake to at least 3 liters per day. Proper hydration supports metabolic function and can help manage hunger cues. Try keeping a water bottle with you throughout the day.",
                type: .tip,
                iconName: "drop.fill"
            ),
            NutritionInsight(
                title: "Fiber Goal Reached",
                shortDescription: "You've been meeting your fiber targets recently.",
                detailedDescription: "Great job hitting your fiber goals! Adequate fiber intake supports digestive health, helps maintain steady blood sugar levels, and contributes to feeling full longer. You're currently averaging 28g of fiber daily, which is excellent.",
                type: .achievement
            ),
            NutritionInsight(
                title: "Try Adding More Vegetables",
                shortDescription: "Increasing vegetable intake can improve your nutrition profile.",
                detailedDescription: "Your micronutrient profile could benefit from more vegetable variety. Try adding 1-2 additional servings of colorful vegetables daily. This can improve your vitamin and mineral intake while keeping calories low. Consider leafy greens, bell peppers, or broccoli.",
                type: .suggestion,
                iconName: "leaf.fill"
            )
        ]
        
        return randomInsights.randomElement()!
    }
}
