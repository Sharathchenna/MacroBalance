import UIKit
import SwiftUI

class MacrosViewController: UIViewController {
    // MARK: - Properties
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let pieChartView = PieChartView()
    private let dataManager = StatsDataManager.shared
    private var macroEntries: [MacrosEntry] = []
    private let refreshControl = UIRefreshControl()
    private var trendChartContainer: UIView?
    
    // Macro goals
    private var proteinGoal: Double = 150
    private var carbsGoal: Double = 250
    private var fatGoal: Double = 65
    
    // Current macros
    private var currentProtein: Double = 0
    private var currentCarbs: Double = 0
    private var currentFat: Double = 0
    
    // UI Components
    private var todayMacrosView: UIView?
    private var calorieCounterView: UIView?
    private var macroBreakdownView: UIView?
    private var nutrientBreakdownView: UIView?
    private var goalSettingsView: UIView?
    
    // Animation properties
    private var animationDuration: TimeInterval = 0.7
    private var chartDisplayed = false
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupChartView()
        setupRefreshControl()
        loadMacroData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !chartDisplayed {
            animateChartAppearance()
            chartDisplayed = true
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "Macro Balance"
        view.backgroundColor = .systemBackground
        
        // Navigation bar styling
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "slider.horizontal.3"),
            style: .plain,
            target: self,
            action: #selector(showGoalSettings)
        )
        navigationItem.rightBarButtonItem = settingsButton
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.axis = .vertical
        contentView.spacing = 16
        contentView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 30, right: 16)
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
        
        setupCalorieCounter()
        setupMacroDistribution()
        setupPieChartContainer()
        setupMacroBreakdown()
        setupMacroTrendAnalysis()
        setupNutrientBreakdown()
    }
    
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        scrollView.refreshControl = refreshControl
    }
    
    @objc private func refreshData() {
        loadMacroData()
    }
    
    // MARK: - Calorie Counter View
    private func setupCalorieCounter() {
        let card = createCardView()
        calorieCounterView = card
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Calorie intake information
        let calorieInfoStack = UIStackView()
        calorieInfoStack.axis = .vertical
        calorieInfoStack.spacing = 8
        calorieInfoStack.alignment = .leading
        
        let titleLabel = UILabel()
        titleLabel.text = "Calorie Balance"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        
        let calorieLabel = UILabel()
        calorieLabel.text = "0 / 0"
        calorieLabel.font = .systemFont(ofSize: 24, weight: .bold)
        calorieLabel.accessibilityIdentifier = "calorieValueLabel"
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "calories consumed"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        
        calorieInfoStack.addArrangedSubview(titleLabel)
        calorieInfoStack.addArrangedSubview(calorieLabel)
        calorieInfoStack.addArrangedSubview(subtitleLabel)
        
        // Progress ring
        let progressContainer = UIView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let progressRingView = CircularProgressView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        progressRingView.translatesAutoresizingMaskIntoConstraints = false
        progressRingView.progressColor = .systemBlue
        progressRingView.trackColor = UIColor.systemGray5
        progressRingView.lineWidth = 10
        progressRingView.accessibilityIdentifier = "calorieProgressRing"
        
        progressContainer.addSubview(progressRingView)
        
        NSLayoutConstraint.activate([
            progressRingView.centerXAnchor.constraint(equalTo: progressContainer.centerXAnchor),
            progressRingView.centerYAnchor.constraint(equalTo: progressContainer.centerYAnchor),
            progressRingView.widthAnchor.constraint(equalToConstant: 80),
            progressRingView.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        stackView.addArrangedSubview(calorieInfoStack)
        stackView.addArrangedSubview(progressContainer)
        
        card.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 120),
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        contentView.addArrangedSubview(card)
    }
    
    // MARK: - Macro Distribution View
    private func setupMacroDistribution() {
        let card = createCardView()
        todayMacrosView = card
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Today's Macros"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        
        let distributonStack = UIStackView()
        distributonStack.axis = .horizontal
        distributonStack.spacing = 24
        distributonStack.distribution = .fillEqually
        
        let macros = [
            ("Protein", "0g (0%)", UIColor.systemRed),
            ("Carbs", "0g (0%)", UIColor.systemBlue),
            ("Fat", "0g (0%)", UIColor.systemYellow)
        ]
        
        macros.forEach { name, value, color in
            distributonStack.addArrangedSubview(createMacroItem(name: name, value: value, color: color))
        }
        
        [titleLabel, distributonStack].forEach {
            stackView.addArrangedSubview($0)
        }
        
        card.addSubview(stackView)
        contentView.addArrangedSubview(card)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 120),
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
    }
    
    private func createMacroItem(name: String, value: String, color: UIColor) -> UIView {
        let container = UIView()
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let colorIndicator = UIView()
        colorIndicator.backgroundColor = color
        colorIndicator.layer.cornerRadius = 4
        colorIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 14)
        nameLabel.textColor = .secondaryLabel
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        valueLabel.accessibilityIdentifier = "macroValue\(name)"
        valueLabel.textAlignment = .center
        
        [colorIndicator, nameLabel, valueLabel].forEach {
            stack.addArrangedSubview($0)
        }
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            colorIndicator.widthAnchor.constraint(equalToConstant: 16),
            colorIndicator.heightAnchor.constraint(equalToConstant: 8),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    // MARK: - Pie Chart Container
    private func setupPieChartContainer() {
        let chartContainer = createCardView()
        
        let titleLabel = UILabel()
        titleLabel.text = "Macro Distribution"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        pieChartView.translatesAutoresizingMaskIntoConstraints = false
        pieChartView.alpha = 0 // Start hidden for animation
        
        chartContainer.addSubview(titleLabel)
        chartContainer.addSubview(pieChartView)
        
        contentView.addArrangedSubview(chartContainer)
        
        NSLayoutConstraint.activate([
            chartContainer.heightAnchor.constraint(equalToConstant: 300),
            titleLabel.topAnchor.constraint(equalTo: chartContainer.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: 16),
            
            pieChartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            pieChartView.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: 16),
            pieChartView.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor, constant: -16),
            pieChartView.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Macro Breakdown View
    private func setupMacroBreakdown() {
        let breakdownCard = createCardView()
        macroBreakdownView = breakdownCard
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.distribution = .equalSpacing
        headerStack.alignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = "Macro Distribution"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        
        let editButton = UIButton(type: .system)
        editButton.setImage(UIImage(systemName: "slider.horizontal.3"), for: .normal)
        editButton.addTarget(self, action: #selector(showGoalSettings), for: .touchUpInside)
        
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(editButton)
        
        stackView.addArrangedSubview(headerStack)
        
        // Add macro rows with enhanced visuals
        addMacroRow(to: stackView, name: "Protein", color: .systemRed, icon: "dumbbell.fill")
        addMacroRow(to: stackView, name: "Carbs", color: .systemBlue, icon: "leaf.fill")
        addMacroRow(to: stackView, name: "Fat", color: .systemYellow, icon: "drop.fill")
        
        breakdownCard.addSubview(stackView)
        contentView.addArrangedSubview(breakdownCard)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: breakdownCard.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: breakdownCard.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: breakdownCard.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: breakdownCard.bottomAnchor, constant: -16)
        ])
    }

    private func addMacroRow(to stackView: UIStackView, name: String, color: UIColor, icon: String) {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let rowStack = UIStackView()
        rowStack.axis = .vertical
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Header with icon and name
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center
        
        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = color.withAlphaComponent(0.1)
        iconContainer.layer.cornerRadius = 8
        
        let iconImage = UIImageView(image: UIImage(systemName: icon))
        iconImage.tintColor = color
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconImage.contentMode = .scaleAspectFit
        
        iconContainer.addSubview(iconImage)
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 32),
            iconContainer.heightAnchor.constraint(equalToConstant: 32),
            iconImage.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImage.widthAnchor.constraint(equalToConstant: 16),
            iconImage.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        
        headerStack.addArrangedSubview(iconContainer)
        headerStack.addArrangedSubview(nameLabel)
        headerStack.addArrangedSubview(UIView()) // Spacer
        
        // Progress section
        let progressContainer = UIView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let progressBar = UIProgressView(progressViewStyle: .bar)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = color
        progressBar.trackTintColor = color.withAlphaComponent(0.1)
        progressBar.layer.cornerRadius = 4
        progressBar.clipsToBounds = true
        progressBar.progress = 0.0 // Will be updated with actual data
        
        let valueStack = UIStackView()
        valueStack.axis = .horizontal
        valueStack.distribution = .equalSpacing
        valueStack.translatesAutoresizingMaskIntoConstraints = false
        
        let currentLabel = UILabel()
        currentLabel.text = "0g"
        currentLabel.font = .systemFont(ofSize: 14)
        currentLabel.textColor = .secondaryLabel
        
        let goalLabel = UILabel()
        goalLabel.text = "Goal: 0g"
        goalLabel.font = .systemFont(ofSize: 14)
        goalLabel.textColor = .secondaryLabel
        
        valueStack.addArrangedSubview(currentLabel)
        valueStack.addArrangedSubview(goalLabel)
        
        progressContainer.addSubview(progressBar)
        progressContainer.addSubview(valueStack)
        
        NSLayoutConstraint.activate([
            progressBar.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            progressBar.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 8),
            
            valueStack.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            valueStack.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            valueStack.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 4),
            valueStack.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor)
        ])
        
        rowStack.addArrangedSubview(headerStack)
        rowStack.addArrangedSubview(progressContainer)
        
        container.addSubview(rowStack)
        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: container.topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        stackView.addArrangedSubview(container)
    }
    
    // MARK: - Trend Analysis
    private func setupMacroTrendAnalysis() {
        let trendCard = createCardView()
        trendChartContainer = trendCard
        
        let titleLabel = UILabel()
        titleLabel.text = "7-Day Macro Trend"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let chartPlaceholder = UIView()
        chartPlaceholder.backgroundColor = .systemGray6
        chartPlaceholder.layer.cornerRadius = 8
        chartPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        chartPlaceholder.tag = 100 // Tag for finding and replacing later
        
        trendCard.addSubview(titleLabel)
        trendCard.addSubview(chartPlaceholder)
        
        contentView.addArrangedSubview(trendCard)
        
        NSLayoutConstraint.activate([
            trendCard.heightAnchor.constraint(equalToConstant: 300),
            titleLabel.topAnchor.constraint(equalTo: trendCard.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: trendCard.leadingAnchor, constant: 16),
            
            chartPlaceholder.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            chartPlaceholder.leadingAnchor.constraint(equalTo: trendCard.leadingAnchor, constant: 16),
            chartPlaceholder.trailingAnchor.constraint(equalTo: trendCard.trailingAnchor, constant: -16),
            chartPlaceholder.bottomAnchor.constraint(equalTo: trendCard.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Nutrient Breakdown
    private func setupNutrientBreakdown() {
        let nutrientCard = createCardView()
        nutrientBreakdownView = nutrientCard
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Micronutrient Overview"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Tap to see detailed breakdown"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        
        // Add micronutrient preview icons
        let micronutrientStack = UIStackView()
        micronutrientStack.axis = .horizontal
        micronutrientStack.distribution = .fillEqually
        micronutrientStack.spacing = 8
        
        let micronutrients = [
            ("Vitamin A", "30%", UIColor.systemOrange),
            ("Iron", "45%", UIColor.systemRed),
            ("Calcium", "60%", UIColor.systemBlue),
            ("Fiber", "25%", UIColor.systemGreen)
        ]
        
        micronutrients.forEach { name, value, color in
            micronutrientStack.addArrangedSubview(createNutrientItem(name: name, value: value, color: color))
        }
        
        stackView.addArrangedSubview(micronutrientStack)
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showNutrientDetail))
        nutrientCard.addGestureRecognizer(tapGesture)
        
        nutrientCard.addSubview(stackView)
        contentView.addArrangedSubview(nutrientCard)
        
        NSLayoutConstraint.activate([
            nutrientCard.heightAnchor.constraint(equalToConstant: 180),
            stackView.topAnchor.constraint(equalTo: nutrientCard.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: nutrientCard.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: nutrientCard.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: nutrientCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func createNutrientItem(name: String, value: String, color: UIColor) -> UIView {
        let container = UIView()
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let circleView = CircularProgressView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        circleView.translatesAutoresizingMaskIntoConstraints = false
        circleView.progressColor = color
        circleView.lineWidth = 4
        
        // Extract percentage value
        if let percentString = value.components(separatedBy: "%").first,
           let percent = Double(percentString) {
            circleView.progress = CGFloat(percent / 100.0)
        }
        
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 12)
        nameLabel.textColor = .secondaryLabel
        nameLabel.textAlignment = .center
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        valueLabel.textAlignment = .center
        
        [circleView, nameLabel, valueLabel].forEach {
            stack.addArrangedSubview($0)
        }
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            circleView.widthAnchor.constraint(equalToConstant: 40),
            circleView.heightAnchor.constraint(equalToConstant: 40),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    // MARK: - Helper Methods
    private func createCardView() -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 6
        card.layer.shadowOpacity = 0.1
        return card
    }
    
    private func setupChartView() {
        loadMacroData()
    }
    
    private func loadMacroData() {
        dataManager.fetchMacroData { [weak self] entries in
            guard let self = self else { return }
            self.macroEntries = entries
            
            DispatchQueue.main.async {
                self.updateUI(with: entries)
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    private func updateUI(with entries: [MacrosEntry]) {
        guard let entry = entries.last else { return }
        
        // Update member variables
        currentProtein = entry.proteins
        currentCarbs = entry.carbs
        currentFat = entry.fats
        proteinGoal = entry.proteinGoal
        carbsGoal = entry.carbGoal
        fatGoal = entry.fatGoal
        
        // Update pie chart
        updateChartData(with: entries)
        
        // Update Today's Macros card
        if let macrosView = todayMacrosView {
            let proteinText = String(format: "%.0fg (%.0f%%)", entry.proteins, entry.proteinPercentage)
            let carbsText = String(format: "%.0fg (%.0f%%)", entry.carbs, entry.carbsPercentage)
            let fatText = String(format: "%.0fg (%.0f%%)", entry.fats, entry.fatsPercentage)
            
            if let stackView = macrosView.subviews.first as? UIStackView,
               let distributionStack = stackView.arrangedSubviews.last as? UIStackView {
                
                if let proteinItem = distributionStack.arrangedSubviews[0].subviews.first as? UIStackView,
                   let proteinLabel = proteinItem.arrangedSubviews.last as? UILabel {
                    proteinLabel.text = proteinText
                }
                
                if let carbsItem = distributionStack.arrangedSubviews[1].subviews.first as? UIStackView,
                   let carbsLabel = carbsItem.arrangedSubviews.last as? UILabel {
                    carbsLabel.text = carbsText
                }
                
                if let fatItem = distributionStack.arrangedSubviews[2].subviews.first as? UIStackView,
                   let fatLabel = fatItem.arrangedSubviews.last as? UILabel {
                    fatLabel.text = fatText
                }
            }
        }
        
        // Update macro breakdown
        if let breakdownView = macroBreakdownView {
            if let stackView = breakdownView.subviews.first as? UIStackView {
                // Skip the title label
                if stackView.arrangedSubviews.count >= 4 {
                    let proteinRow = stackView.arrangedSubviews[1]
                    updateProgressRow(row: proteinRow, current: Int(entry.proteins), goal: Int(entry.proteinGoal))
                    
                    let carbsRow = stackView.arrangedSubviews[2]
                    updateProgressRow(row: carbsRow, current: Int(entry.carbs), goal: Int(entry.carbsGoal))
                    
                    let fatRow = stackView.arrangedSubviews[3]
                    updateProgressRow(row: fatRow, current: Int(entry.fats), goal: Int(entry.fatGoal))
                }
            }
        }
        
        // Update calorie counter
        if let calorieView = calorieCounterView {
            let calorieTotal = entry.calories
            let calorieGoal = entry.calorieGoal
            
            if let stackView = calorieView.subviews.first as? UIStackView {
                let infoStack = stackView.arrangedSubviews[0] as? UIStackView
                let progressContainer = stackView.arrangedSubviews[1]
                
                // Update calorie label
                if let infoStack = infoStack,
                   let calorieLabel = infoStack.arrangedSubviews[1] as? UILabel {
                    calorieLabel.text = String(format: "%.0f / %.0f", calorieTotal, calorieGoal)
                }
                
                // Update progress ring
                if let progressRing = progressContainer.subviews.first as? CircularProgressView {
                    let progress = calorieGoal > 0 ? min(calorieTotal / calorieGoal, 1.0) : 0
                    
                    // Animate progress change
                    UIView.animate(withDuration: 1.0) {
                        progressRing.progress = CGFloat(progress)
                    }
                }
            }
        }
        
        // Update trend chart if we have multiple entries
        if entries.count > 1, let trendContainer = trendChartContainer {
            updateTrendChart(with: entries, in: trendContainer)
        }
    }
    
    private func updateProgressRow(row: UIView, current: Int, goal: Int) {
        for subview in row.subviews {
            if let progressView = subview as? UIProgressView {
                let progress = goal > 0 ? Float(current) / Float(goal) : 0
                UIView.animate(withDuration: 0.5) {
                    progressView.setProgress(progress, animated: true)
                }
            } else if let label = subview as? UILabel, label.textColor == .secondaryLabel {
                label.text = "\(current)/\(goal)g"
            }
        }
    }
    
    private func updateChartData(with entries: [MacrosEntry]) {
        guard let entry = entries.last else { return }
        let total = entry.proteins + entry.carbs + entry.fats
        
        // Use the enhanced colors from MacrosChartView
        let data = [
            (value: entry.proteins, color: UIColor(red: 0.98, green: 0.76, blue: 0.34, alpha: 1)),
            (value: entry.carbs, color: UIColor(red: 0.35, green: 0.78, blue: 0.71, alpha: 1)),
            (value: entry.fats, color: UIColor(red: 0.56, green: 0.27, blue: 0.68, alpha: 1))
        ]
        
        pieChartView.updateChart(with: data, total: total)
    }
    
    private func updateTrendChart(with entries: [MacrosEntry], in container: UIView) {
        // Remove placeholder if it exists
        if let placeholder = container.viewWithTag(100) {
            placeholder.removeFromSuperview()
        }
        
        // Create line chart in SwiftUI
        let trendChart = MacroTrendChartView(entries: entries)
            .environment(\.colorScheme, traitCollection.userInterfaceStyle == .dark ? .dark : .light)
        
        let hostingController = UIHostingController(rootView: trendChart)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hostingController)
        container.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        // Add top-level constraints
        let titleInset: CGFloat = 50  // Account for the title
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor, constant: titleInset),
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
    }
    
    private func animateChartAppearance() {
        // Animate pie chart appearance
        UIView.animate(withDuration: animationDuration) {
            self.pieChartView.alpha = 1.0
        }
        
        // Animate progress bars if needed
        // Add more animations for other UI elements
    }
    
    // MARK: - Action Handlers
    @objc private func showGoalSettings() {
        let alertController = UIAlertController(
            title: "Adjust Macro Goals",
            message: "Set your daily macro nutrient targets",
            preferredStyle: .alert
        )
        
        alertController.addTextField { textField in
            textField.placeholder = "Protein (g)"
            textField.keyboardType = .numberPad
            textField.text = "\(Int(self.proteinGoal))"
        }
        
        alertController.addTextField { textField in
            textField.placeholder = "Carbs (g)"
            textField.keyboardType = .numberPad
            textField.text = "\(Int(self.carbsGoal))"
        }
        
        alertController.addTextField { textField in
            textField.placeholder = "Fat (g)"
            textField.keyboardType = .numberPad
            textField.text = "\(Int(self.fatGoal))"
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            guard let proteinText = alertController.textFields?[0].text,
                  let carbsText = alertController.textFields?[1].text,
                  let fatText = alertController.textFields?[2].text,
                  let protein = Double(proteinText),
                  let carbs = Double(carbsText),
                  let fat = Double(fatText) else {
                return
            }
            
            // Save the new goals to UserDefaults
            UserDefaults.standard.set(protein, forKey: "protein_goal")
            UserDefaults.standard.set(carbs, forKey: "carbs_goal")
            UserDefaults.standard.set(fat, forKey: "fat_goal")
            
            // Update the UI with the new goals
            self.proteinGoal = protein
            self.carbsGoal = carbs
            self.fatGoal = fat
            
            // Create a new entry with the updated goals
            if let lastEntry = self.macroEntries.last {
                let updatedEntry = MacrosEntry(
                    date: lastEntry.date,
                    proteins: lastEntry.proteins,
                    carbs: lastEntry.carbs,
                    fats: lastEntry.fats,
                    proteinGoal: protein,
                    carbGoal: carbs,
                    fatGoal: fat
                )
                
                // Update the UI with the new entry
                self.updateUI(with: [updatedEntry])
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    @objc private func showNutrientDetail() {
        let detailVC = NutrientDetailViewController()
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Animated Progress View
class AnimatedProgressView: UIProgressView {
    override func layoutSubviews() {
        super.layoutSubviews()
        let transform = CGAffineTransform(scaleX: 1, y: 2)
        self.transform = transform
    }
}

// MARK: - Circular Progress View
class CircularProgressView: UIView {
    private var progressLayer = CAShapeLayer()
    private var trackLayer = CAShapeLayer()
    
    var progressColor: UIColor = .systemBlue {
        didSet {
            progressLayer.strokeColor = progressColor.cgColor
        }
    }
    
    var trackColor: UIColor = .systemGray6 {
        didSet {
            trackLayer.strokeColor = trackColor.cgColor
        }
    }
    
    var lineWidth: CGFloat = 10 {
        didSet {
            trackLayer.lineWidth = lineWidth
            progressLayer.lineWidth = lineWidth
            setNeedsDisplay()
        }
    }
    
    var progress: CGFloat = 0 {
        didSet {
            progressLayer.strokeEnd = progress
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    private func setupLayers() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - lineWidth/2
        let startAngle = -CGFloat.pi / 2
        let endAngle = 2 * CGFloat.pi - CGFloat.pi / 2
        
        let circularPath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        
        trackLayer.path = circularPath.cgPath
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = trackColor.cgColor
        trackLayer.lineWidth = lineWidth
        trackLayer.strokeEnd = 1.0
        layer.addSublayer(trackLayer)
        
        progressLayer.path = circularPath.cgPath
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = progressColor.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.strokeEnd = progress
        progressLayer.lineCap = .round
        layer.addSublayer(progressLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - lineWidth/2
        let startAngle = -CGFloat.pi / 2
        let endAngle = 2 * CGFloat.pi - CGFloat.pi / 2
        
        let circularPath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        
        trackLayer.path = circularPath.cgPath
        progressLayer.path = circularPath.cgPath
    }
}