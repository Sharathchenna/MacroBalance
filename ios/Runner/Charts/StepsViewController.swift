import UIKit
import SwiftUI
import DGCharts

class StepsViewController: UIViewController {
    // MARK: - Properties
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let dataManager = StatsDataManager.shared
    private var stepsEntries: [StepsEntry] = []
    private let refreshControl = UIRefreshControl()
    private var chartContainer: UIView?
    
    // UI Components
    private var todayStepsView: UIView?
    private var weeklyAverageView: UIView?
    private var achievementsView: UIView?
    private var goalSettingsView: UIView?
    
    // Animation properties
    private var animationDuration: TimeInterval = 0.7
    private var chartDisplayed = false
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupRefreshControl()
        loadStepsData()
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
        title = "Daily Steps"
        view.backgroundColor = .systemBackground
        
        // Setup edit goal button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(showGoalSettings)
        )
        
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
        
        setupTodaySteps()
        setupStepsChart()
        setupWeeklyStats()
        setupAchievements()
        setupTips()
    }
    
    private func setupTodaySteps() {
        let card = createCardView()
        todayStepsView = card
        
        let containerStack = UIStackView()
        containerStack.axis = .horizontal
        containerStack.spacing = 16
        containerStack.alignment = .center
        containerStack.distribution = .fillEqually
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Left side - Step count and progress
        let leftStack = UIStackView()
        leftStack.axis = .vertical
        leftStack.spacing = 8
        leftStack.alignment = .center
        
        let stepsLabel = UILabel()
        stepsLabel.text = "0"
        stepsLabel.font = .monospacedDigitSystemFont(ofSize: 40, weight: .bold)
        stepsLabel.textAlignment = .center
        stepsLabel.accessibilityIdentifier = "todayStepsLabel"
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "steps today"
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = .secondaryLabel
        
        let progressLabel = UILabel()
        progressLabel.text = "0% of daily goal"
        progressLabel.font = .systemFont(ofSize: 14, weight: .medium)
        progressLabel.textColor = .systemBlue
        
        [stepsLabel, subtitleLabel, progressLabel].forEach {
            leftStack.addArrangedSubview($0)
        }
        
        // Right side - Circular progress
        let progressContainer = UIView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let progressRing = CircularProgressView(frame: .zero)
        progressRing.translatesAutoresizingMaskIntoConstraints = false
        progressRing.progressColor = .systemBlue
        progressRing.trackColor = .systemGray6
        progressRing.lineWidth = 12
        progressRing.progress = 0.0
        
        progressContainer.addSubview(progressRing)
        
        NSLayoutConstraint.activate([
            progressRing.widthAnchor.constraint(equalToConstant: 100),
            progressRing.heightAnchor.constraint(equalToConstant: 100),
            progressRing.centerXAnchor.constraint(equalTo: progressContainer.centerXAnchor),
            progressRing.centerYAnchor.constraint(equalTo: progressContainer.centerYAnchor)
        ])
        
        containerStack.addArrangedSubview(leftStack)
        containerStack.addArrangedSubview(progressContainer)
        
        card.addSubview(containerStack)
        contentView.addArrangedSubview(card)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 160),
            containerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            containerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            containerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            containerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupStepsChart() {
        let chartCard = createCardView()
        chartContainer = chartCard
        
        let titleLabel = UILabel()
        titleLabel.text = "Weekly Activity"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let chartPlaceholder = UIView()
        chartPlaceholder.backgroundColor = .systemGray6
        chartPlaceholder.layer.cornerRadius = 8
        chartPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        chartPlaceholder.tag = 100
        
        chartCard.addSubview(titleLabel)
        chartCard.addSubview(chartPlaceholder)
        
        contentView.addArrangedSubview(chartCard)
        
        NSLayoutConstraint.activate([
            chartCard.heightAnchor.constraint(equalToConstant: 300),
            titleLabel.topAnchor.constraint(equalTo: chartCard.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: chartCard.leadingAnchor, constant: 16),
            
            chartPlaceholder.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            chartPlaceholder.leadingAnchor.constraint(equalTo: chartCard.leadingAnchor, constant: 16),
            chartPlaceholder.trailingAnchor.constraint(equalTo: chartCard.trailingAnchor, constant: -16),
            chartPlaceholder.bottomAnchor.constraint(equalTo: chartCard.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupWeeklyStats() {
        let card = createCardView()
        weeklyAverageView = card
        
        let titleLabel = UILabel()
        titleLabel.text = "Weekly Overview"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let statsStack = UIStackView()
        statsStack.axis = .horizontal
        statsStack.distribution = .fillEqually
        statsStack.spacing = 16
        statsStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Add stat items
        let stats = [
            ("Average", "0", "steps/day", "chart.bar.fill"),
            ("Total", "0", "steps", "sum"),
            ("Best Day", "0", "steps", "star.fill")
        ]
        
        stats.forEach { title, value, unit, icon in
            statsStack.addArrangedSubview(createStatItem(title: title, value: value, unit: unit, icon: icon))
        }
        
        card.addSubview(titleLabel)
        card.addSubview(statsStack)
        
        contentView.addArrangedSubview(card)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            
            statsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            statsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            statsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            statsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            card.heightAnchor.constraint(equalToConstant: 150)
        ])
    }
    
    private func setupAchievements() {
        let card = createCardView()
        achievementsView = card
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.distribution = .equalSpacing
        
        let titleLabel = UILabel()
        titleLabel.text = "Achievements"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        
        let viewAllButton = UIButton(type: .system)
        viewAllButton.setTitle("View All", for: .normal)
        viewAllButton.addTarget(self, action: #selector(showAllAchievements), for: .touchUpInside)
        
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(viewAllButton)
        
        let achievementsStack = UIStackView()
        achievementsStack.axis = .horizontal
        achievementsStack.distribution = .fillEqually
        achievementsStack.spacing = 12
        
        // Add achievement badges
        let achievements = [
            ("7 Day Streak", "flame.fill", UIColor.systemOrange),
            ("10K Steps", "figure.walk", UIColor.systemGreen),
            ("Early Bird", "sunrise.fill", UIColor.systemPurple)
        ]
        
        achievements.forEach { title, icon, color in
            achievementsStack.addArrangedSubview(createAchievementBadge(title: title, icon: icon, color: color))
        }
        
        stackView.addArrangedSubview(headerStack)
        stackView.addArrangedSubview(achievementsStack)
        
        card.addSubview(stackView)
        contentView.addArrangedSubview(card)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            card.heightAnchor.constraint(equalToConstant: 160)
        ])
    }
    
    private func setupTips() {
        let card = createCardView()
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Tips & Insights"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        
        let tipView = createTipView(
            icon: "lightbulb.fill",
            color: .systemYellow,
            title: "Stay Active",
            message: "Try to take a 5-minute walk every hour to reach your daily goal."
        )
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(tipView)
        
        card.addSubview(stackView)
        contentView.addArrangedSubview(card)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            card.heightAnchor.constraint(equalToConstant: 120)
        ])
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
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }
    
    private func createStatItem(title: String, value: String, unit: String, icon: String) -> UIView {
        let container = UIView()
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        iconView.heightAnchor.constraint(equalToConstant: 24).isActive = true
        iconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14)
        titleLabel.textColor = .secondaryLabel
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .medium)
        
        let unitLabel = UILabel()
        unitLabel.text = unit
        unitLabel.font = .systemFont(ofSize: 12)
        unitLabel.textColor = .secondaryLabel
        
        [iconView, titleLabel, valueLabel, unitLabel].forEach {
            stack.addArrangedSubview($0)
        }
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createAchievementBadge(title: String, icon: String, color: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = color.withAlphaComponent(0.1)
        container.layer.cornerRadius = 12
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let iconContainer = UIView()
        iconContainer.backgroundColor = color.withAlphaComponent(0.2)
        iconContainer.layer.cornerRadius = 20
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        iconContainer.addSubview(iconView)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = color
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        
        stack.addArrangedSubview(iconContainer)
        stack.addArrangedSubview(titleLabel)
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])
        
        return container
    }
    
    private func createTipView(icon: String, color: UIColor, title: String, message: String) -> UIView {
        let container = UIView()
        container.backgroundColor = color.withAlphaComponent(0.1)
        container.layer.cornerRadius = 12
        
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 12)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(messageLabel)
        
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(textStack)
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        return container
    }
    
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        scrollView.refreshControl = refreshControl
    }
    
    private func animateChartAppearance() {
        UIView.animate(withDuration: animationDuration) {
            self.updateChartIfNeeded()
        }
    }
    
    private func updateChartIfNeeded() {
        guard let container = chartContainer,
              stepsEntries.count > 1 else { return }
        
        // Remove placeholder if it exists
        if let placeholder = container.viewWithTag(100) {
            placeholder.removeFromSuperview()
        }
        
        // Create and add the chart view
        let chartView = StepsChartView(entries: stepsEntries)
            .environment(\.colorScheme, traitCollection.userInterfaceStyle == .dark ? .dark : .light)
        
        let hostingController = UIHostingController(rootView: chartView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        addChild(hostingController)
        container.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        let titleInset: CGFloat = 50 // Account for title
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor, constant: titleInset),
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Data Loading
    private func loadStepsData() {
        dataManager.fetchStepData { [weak self] entries in
            guard let self = self else { return }
            self.stepsEntries = entries
            
            DispatchQueue.main.async {
                self.updateUI()
                self.refreshControl.endRefreshing()
            }
        }
    }
    
    private func updateUI() {
        guard let latestEntry = stepsEntries.last else { return }
        
        // Update today's steps view
        if let todayView = todayStepsView,
           let stackView = todayView.subviews.first as? UIStackView {
            let leftStack = stackView.arrangedSubviews[0] as? UIStackView
            let progressContainer = stackView.arrangedSubviews[1]
            
            // Update step count
            if let stepsLabel = leftStack?.arrangedSubviews[0] as? UILabel {
                stepsLabel.text = NumberFormatter.localizedString(
                    from: NSNumber(value: latestEntry.steps),
                    number: .decimal
                )
            }
            
            // Update progress percentage
            if let progressLabel = leftStack?.arrangedSubviews[2] as? UILabel {
                let progress = min(Double(latestEntry.steps) / Double(latestEntry.goal), 1.0)
                progressLabel.text = String(format: "%.0f%% of daily goal", progress * 100)
            }
            
            // Update progress ring
            if let progressRing = progressContainer.subviews.first as? CircularProgressView {
                UIView.animate(withDuration: 0.5) {
                    progressRing.progress = CGFloat(Double(latestEntry.steps) / Double(latestEntry.goal))
                }
            }
        }
        
        // Update weekly stats
        if let weeklyView = weeklyAverageView,
           let statsStack = weeklyView.subviews.last as? UIStackView {
            // Calculate stats
            let totalSteps = stepsEntries.reduce(0) { $0 + $1.steps }
            let averageSteps = totalSteps / stepsEntries.count
            let bestDay = stepsEntries.max(by: { $0.steps < $1.steps })?.steps ?? 0
            
            // Update average steps
            if let averageView = statsStack.arrangedSubviews[0].subviews.first as? UIStackView,
               let averageLabel = averageView.arrangedSubviews[2] as? UILabel {
                averageLabel.text = NumberFormatter.localizedString(
                    from: NSNumber(value: averageSteps),
                    number: .decimal
                )
            }
            
            // Update total steps
            if let totalView = statsStack.arrangedSubviews[1].subviews.first as? UIStackView,
               let totalLabel = totalView.arrangedSubviews[2] as? UILabel {
                totalLabel.text = NumberFormatter.localizedString(
                    from: NSNumber(value: totalSteps),
                    number: .decimal
                )
            }
            
            // Update best day
            if let bestView = statsStack.arrangedSubviews[2].subviews.first as? UIStackView,
               let bestLabel = bestView.arrangedSubviews[2] as? UILabel {
                bestLabel.text = NumberFormatter.localizedString(
                    from: NSNumber(value: bestDay),
                    number: .decimal
                )
            }
        }
        
        // Update chart
        updateChartIfNeeded()
    }
    
    // MARK: - Action Handlers
    @objc private func refreshData() {
        loadStepsData()
    }
    
    @objc private func showGoalSettings() {
        let alert = UIAlertController(
            title: "Set Daily Step Goal",
            message: "Enter your target steps per day",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.keyboardType = .numberPad
            textField.placeholder = "Daily step goal"
            if let currentGoal = self.stepsEntries.last?.goal {
                textField.text = "\(currentGoal)"
            }
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let text = alert.textFields?.first?.text,
                  let goal = Int(text) else { return }
            
            UserDefaults.standard.set(goal, forKey: "steps_goal")
            self?.loadStepsData()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    @objc private func showAllAchievements() {
        // Implement achievements screen navigation
        let achievementsVC = AchievementsViewController()
        navigationController?.pushViewController(achievementsVC, animated: true)
    }
}

class AchievementsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        title = "Achievements"
        view.backgroundColor = .systemBackground
        
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
        
        setupAchievements()
    }
    
    private func setupAchievements() {
        let achievements = [
            ("7 Day Streak", "flame.fill", "Complete your step goal for 7 consecutive days", UIColor.systemOrange),
            ("10K Steps", "figure.walk", "Walk 10,000 steps in a single day", UIColor.systemGreen),
            ("Early Bird", "sunrise.fill", "Complete 2,000 steps before 9 AM", UIColor.systemPurple),
            ("Marathon", "figure.walk.motion", "Walk 42,195 steps in a single day", UIColor.systemBlue),
            ("Weekend Warrior", "star.fill", "Meet your step goal on Saturday and Sunday", UIColor.systemYellow),
            ("Night Owl", "moon.stars.fill", "Complete 1,000 steps after 9 PM", UIColor.systemIndigo)
        ]
        
        for (title, icon, description, color) in achievements {
            let card = createAchievementCard(title: title, icon: icon, description: description, color: color)
            contentView.addArrangedSubview(card)
        }
    }
    
    private func createAchievementCard(title: String, icon: String, description: String, color: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let iconContainer = UIView()
        iconContainer.backgroundColor = color.withAlphaComponent(0.1)
        iconContainer.layer.cornerRadius = 25
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        iconContainer.addSubview(iconView)
        
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = .systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(descriptionLabel)
        
        stack.addArrangedSubview(iconContainer)
        stack.addArrangedSubview(textStack)
        
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 50),
            iconContainer.heightAnchor.constraint(equalToConstant: 50),
            
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        return card
    }
}