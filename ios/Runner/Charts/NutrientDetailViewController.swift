import UIKit
import SwiftUI

// MARK: - Models
struct NutrientInfo {
    let name: String
    let amount: String
    let percentage: Int
    
    static func defaultVitamins() -> [(String, String, Int)] {
        return [
            ("Vitamin A", "800 mcg", 65),
            ("Vitamin C", "90 mg", 75),
            ("Vitamin D", "15 mcg", 30),
            ("Vitamin E", "15 mg", 55),
            ("Vitamin K", "120 mcg", 40),
            ("Vitamin B6", "1.7 mg", 85),
            ("Vitamin B12", "2.4 mcg", 90),
            ("Folate", "400 mcg", 70)
        ]
    }
    
    static func defaultMinerals() -> [(String, String, Int)] {
        return [
            ("Calcium", "1000 mg", 60),
            ("Iron", "8 mg", 45),
            ("Magnesium", "420 mg", 50),
            ("Zinc", "11 mg", 65),
            ("Potassium", "3500 mg", 40),
            ("Sodium", "2300 mg", 75),
            ("Phosphorus", "700 mg", 80),
            ("Selenium", "55 mcg", 70)
        ]
    }
    
    static func defaultOtherNutrients() -> [(String, String, Int)] {
        return [
            ("Fiber", "38 g", 25),
            ("Omega-3", "1.6 g", 30),
            ("Omega-6", "17 g", 70),
            ("Cholesterol", "300 mg", 55),
            ("Sugar", "24 g", 60),
            ("Water", "3.7 L", 85)
        ]
    }
}

class NutrientDetailViewController: UIViewController {
    // MARK: - Properties
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let dataManager = StatsDataManager.shared
    
    // Nutrient arrays with default values
    private var vitamins: [(String, String, Int)] = NutrientInfo.defaultVitamins()
    private var minerals: [(String, String, Int)] = NutrientInfo.defaultMinerals()
    private var otherNutrients: [(String, String, Int)] = NutrientInfo.defaultOtherNutrients()
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "Nutrient Details"
        view.backgroundColor = .systemBackground
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.axis = .vertical
        contentView.spacing = 16
        contentView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        contentView.isLayoutMarginsRelativeArrangement = true
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        setupOverview()
        setupMacronutrients()
        setupVitamins()
        setupMinerals()
        setupOtherNutrients()
    }
    
    private func setupOverview() {
        let card = createCardView()
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.distribution = .equalSpacing
        headerStack.alignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = "Today's Nutrition Score"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        
        let scoreView = createScoreView()
        
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(scoreView)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = "Track your nutrient intake to ensure a balanced diet"
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        
        stackView.addArrangedSubview(headerStack)
        stackView.addArrangedSubview(descriptionLabel)
        
        card.addSubview(stackView)
        contentView.addArrangedSubview(card)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
    }
    
    private func createScoreView() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let scoreRing = CircularProgressView(frame: .zero)
        scoreRing.translatesAutoresizingMaskIntoConstraints = false
        scoreRing.progressColor = .systemGreen
        scoreRing.trackColor = .systemGray5
        scoreRing.lineWidth = 8
        scoreRing.progress = 0.75 // Example score
        
        let scoreLabel = UILabel()
        scoreLabel.text = "75%"
        scoreLabel.font = .systemFont(ofSize: 16, weight: .bold)
        scoreLabel.textAlignment = .center
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(scoreRing)
        container.addSubview(scoreLabel)
        
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 60),
            container.heightAnchor.constraint(equalToConstant: 60),
            
            scoreRing.topAnchor.constraint(equalTo: container.topAnchor),
            scoreRing.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scoreRing.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scoreRing.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            scoreLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            scoreLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
    }
    
    private func setupNutrientCategory(title: String, nutrients: [(String, String, Int)], color: UIColor) {
        let card = createCardView()
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        
        stackView.addArrangedSubview(titleLabel)
        
        for (name, amount, percentage) in nutrients {
            stackView.addArrangedSubview(createNutrientRow(
                name: name,
                amount: amount,
                percentage: percentage,
                color: color
            ))
        }
        
        card.addSubview(stackView)
        contentView.addArrangedSubview(card)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
    }
    
    private func createNutrientRow(name: String, amount: String, percentage: Int, color: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 16)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let amountLabel = UILabel()
        amountLabel.text = amount
        amountLabel.font = .systemFont(ofSize: 14)
        amountLabel.textColor = .secondaryLabel
        amountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let progressContainer = UIView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let progressBar = UIProgressView(progressViewStyle: .bar)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = color
        progressBar.trackTintColor = color.withAlphaComponent(0.1)
        progressBar.progress = Float(percentage) / 100
        progressBar.layer.cornerRadius = 3
        progressBar.clipsToBounds = true
        
        let percentageLabel = UILabel()
        percentageLabel.text = "\(percentage)%"
        percentageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        percentageLabel.textColor = color
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        progressContainer.addSubview(progressBar)
        progressContainer.addSubview(percentageLabel)
        
        container.addSubview(nameLabel)
        container.addSubview(amountLabel)
        container.addSubview(progressContainer)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 44),
            
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            amountLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
            amountLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            progressContainer.leadingAnchor.constraint(equalTo: container.centerXAnchor),
            progressContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            progressContainer.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            progressBar.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: percentageLabel.leadingAnchor, constant: -8),
            progressBar.centerYAnchor.constraint(equalTo: progressContainer.centerYAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 6),
            
            percentageLabel.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            percentageLabel.centerYAnchor.constraint(equalTo: progressContainer.centerYAnchor),
            percentageLabel.widthAnchor.constraint(equalToConstant: 45)
        ])
        
        return container
    }
    
    private func setupMacronutrients() {
        setupNutrientCategory(
            title: "Macronutrients",
            nutrients: [
                ("Protein", "65g", 85),
                ("Carbs", "180g", 72),
                ("Fat", "55g", 65)
            ],
            color: .systemBlue
        )
    }
    
    private func setupVitamins() {
        setupNutrientCategory(
            title: "Vitamins",
            nutrients: vitamins,
            color: .systemGreen
        )
    }
    
    private func setupMinerals() {
        setupNutrientCategory(
            title: "Minerals",
            nutrients: minerals,
            color: .systemOrange
        )
    }
    
    private func setupOtherNutrients() {
        setupNutrientCategory(
            title: "Other Nutrients",
            nutrients: otherNutrients,
            color: .systemPurple
        )
    }
    
    private func createCardView() -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 6
        card.layer.shadowOpacity = 0.1
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }
}

// MARK: - Chips Flow Layout
class ChipsFlowLayout: UIView {
    private var arrangedSubviews: [UIView] = []
    private let spacing: CGFloat = 8
    
    func addArrangedSubview(_ view: UIView) {
        arrangedSubviews.append(view)
        addSubview(view)
        setNeedsLayout()
    }
    
    var minimumInteritemSpacing: CGFloat = 8
    var minimumLineSpacing: CGFloat = 8
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var xOffset: CGFloat = 0
        var yOffset: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for view in arrangedSubviews {
            view.sizeToFit()
            let viewSize = view.bounds.size
            
            if xOffset + viewSize.width > bounds.width {
                // Move to next row
                xOffset = 0
                yOffset += rowHeight + minimumLineSpacing
                rowHeight = 0
            }
            
            view.frame = CGRect(x: xOffset, y: yOffset, width: viewSize.width, height: viewSize.height)
            
            xOffset += viewSize.width + minimumInteritemSpacing
            rowHeight = max(rowHeight, viewSize.height)
        }
        
        // Update frame height if needed
        let height = yOffset + rowHeight
        if frame.size.height != height {
            frame.size.height = height
        }
    }
    
    override var intrinsicContentSize: CGSize {
        layoutSubviews()
        return CGSize(width: UIView.noIntrinsicMetric, height: frame.size.height)
    }
}