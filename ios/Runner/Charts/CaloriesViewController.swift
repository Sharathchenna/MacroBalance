import UIKit
import DGCharts

class CaloriesViewController: UIViewController {
    // MARK: - Properties
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let chartView = LineChartView()
    private let dataManager = StatsDataManager.shared
    private var calorieEntries: [CaloriesEntry] = []
    
    // Time range selection
    private let timeRangeSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Day", "Week", "Month", "Year"])
        control.selectedSegmentIndex = 1 // Default to week
        control.backgroundColor = .tertiarySystemBackground
        control.selectedSegmentTintColor = .systemGreen
        return control
    }()
    
    // Progress Ring
    private let progressRing = MacroCircularProgressView(progress: 0.75, color: .systemGreen)
    
    // Trend Analysis Card
    private let trendCard = UIView()
    private let trendLabel = UILabel()
    private let trendIcon = UIImageView()
    
    // Stats Cards
    private let statsContainer = UIStackView()
    private let averageCard = UIView()
    private let deficitCard = UIView()
    private let streakCard = UIView()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupChartView()
        setupGestures()
        loadCalorieData()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "Calories"
        view.backgroundColor = .systemBackground
        
        setupScrollView()
        setupTimeRangeControl()
        setupCaloriesSummary()
        setupTrendAnalysis()
        setupStatsCards()
        setupChartContainer()
        
        // Add subtle animations
        animateContentIn()
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.axis = .vertical
        contentView.spacing = 20
        contentView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
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
    }
    
    private func setupTimeRangeControl() {
        timeRangeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        timeRangeSegmentedControl.addTarget(self, action: #selector(timeRangeChanged), for: .valueChanged)
        
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 12
        container.addSubview(timeRangeSegmentedControl)
        
        NSLayoutConstraint.activate([
            timeRangeSegmentedControl.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            timeRangeSegmentedControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            timeRangeSegmentedControl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            timeRangeSegmentedControl.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        
        contentView.addArrangedSubview(container)
    }
    
    private func setupCaloriesSummary() {
        let card = createCard()
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Calories Display
        let caloriesLabel = UILabel()
        caloriesLabel.text = "1,850"
        caloriesLabel.font = .systemFont(ofSize: 48, weight: .bold)
        caloriesLabel.textColor = .label
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "calories consumed today"
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = .secondaryLabel
        
        // Progress Ring
        let progressContainer = UIView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.addSubview(progressRing)
        
        NSLayoutConstraint.activate([
            progressRing.widthAnchor.constraint(equalToConstant: 120),
            progressRing.heightAnchor.constraint(equalToConstant: 120),
            progressRing.centerXAnchor.constraint(equalTo: progressContainer.centerXAnchor),
            progressRing.centerYAnchor.constraint(equalTo: progressContainer.centerYAnchor)
        ])
        
        let goalLabel = UILabel()
        goalLabel.text = "Daily Goal: 2,500 calories"
        goalLabel.font = .systemFont(ofSize: 14, weight: .medium)
        goalLabel.textColor = .secondaryLabel
        
        [caloriesLabel, subtitleLabel, progressContainer, goalLabel].forEach {
            stackView.addArrangedSubview($0)
        }
        
        card.addSubview(stackView)
        contentView.addArrangedSubview(card)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 280),
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24)
        ])
    }
    
    private func setupTrendAnalysis() {
        let card = createCard()
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Trend Analysis"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        
        trendLabel.text = "You're trending 5% below your weekly average"
        trendLabel.font = .systemFont(ofSize: 16)
        trendLabel.textColor = .systemGreen
        
        trendIcon.image = UIImage(systemName: "arrow.down.right.circle.fill")
        trendIcon.tintColor = .systemGreen
        
        let trendStack = UIStackView()
        trendStack.axis = .horizontal
        trendStack.spacing = 8
        trendStack.alignment = .center
        [trendIcon, trendLabel].forEach { trendStack.addArrangedSubview($0) }
        
        [titleLabel, trendStack].forEach { stackView.addArrangedSubview($0) }
        
        card.addSubview(stackView)
        contentView.addArrangedSubview(card)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 100),
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            trendIcon.widthAnchor.constraint(equalToConstant: 24),
            trendIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func setupStatsCards() {
        statsContainer.axis = .horizontal
        statsContainer.distribution = .fillEqually
        statsContainer.spacing = 12
        
        let cards = [
            (averageCard, "Average", "2,150", "cal/day"),
            (deficitCard, "Deficit", "-350", "cal/day"),
            (streakCard, "Streak", "5", "days")
        ]
        
        cards.forEach { card, title, value, unit in
            let statsCard = createStatsCard(title: title, value: value, unit: unit)
            statsContainer.addArrangedSubview(statsCard)
        }
        
        contentView.addArrangedSubview(statsContainer)
    }
    
    private func setupChartContainer() {
        let chartContainer = UIView()
        chartContainer.backgroundColor = .secondarySystemBackground
        chartContainer.layer.cornerRadius = 16
        
        chartView.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(chartView)
        
        contentView.addArrangedSubview(chartContainer)
        
        NSLayoutConstraint.activate([
            chartContainer.heightAnchor.constraint(equalToConstant: 300),
            chartView.topAnchor.constraint(equalTo: chartContainer.topAnchor, constant: 16),
            chartView.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor, constant: -16),
            chartView.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupBreakdown() {
        let breakdownCard = UIView()
        breakdownCard.backgroundColor = .secondarySystemBackground
        breakdownCard.layer.cornerRadius = 16
        
        let titleLabel = UILabel()
        titleLabel.text = "Meal Breakdown"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        breakdownCard.addSubview(titleLabel)
        breakdownCard.addSubview(stackView)
        
        contentView.addArrangedSubview(breakdownCard)
        
        // Add meal rows
        let meals = [
            ("Breakfast", 450),
            ("Lunch", 650),
            ("Dinner", 550),
            ("Snacks", 200)
        ]
        
        meals.forEach { meal, calories in
            stackView.addArrangedSubview(createMealRow(name: meal, calories: calories))
        }
        
        NSLayoutConstraint.activate([
            breakdownCard.heightAnchor.constraint(equalToConstant: 250),
            titleLabel.topAnchor.constraint(equalTo: breakdownCard.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: breakdownCard.leadingAnchor, constant: 16),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: breakdownCard.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: breakdownCard.trailingAnchor, constant: -16)
        ])
    }
    
    private func createMealRow(name: String, calories: Int) -> UIView {
        let container = UIView()
        
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 16)
        
        let caloriesLabel = UILabel()
        caloriesLabel.text = "\(calories) cal"
        caloriesLabel.font = .systemFont(ofSize: 16)
        caloriesLabel.textColor = .secondaryLabel
        
        [nameLabel, caloriesLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 44),
            
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            caloriesLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            caloriesLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
    }
    
    private func setupChartView() {
        chartView.rightAxis.enabled = false
        chartView.legend.enabled = false
        
        chartView.drawGridBackgroundEnabled = false
        chartView.drawBordersEnabled = false
        
        // Style X-axis
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = false
        xAxis.labelTextColor = .secondaryLabel
        xAxis.labelFont = .systemFont(ofSize: 12)
        xAxis.granularity = 1
        
        // Style left axis
        let leftAxis = chartView.leftAxis
        leftAxis.axisMinimum = 0
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridLineDashLengths = [4, 4]
        leftAxis.gridColor = .systemGray4
        leftAxis.labelTextColor = .secondaryLabel
        leftAxis.labelFont = .systemFont(ofSize: 12)
        
        // Add gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemGreen.withAlphaComponent(0.2).cgColor,
            UIColor.systemGreen.withAlphaComponent(0.05).cgColor
        ]
        gradientLayer.locations = [0, 1]
        chartView.layer.insertSublayer(gradientLayer, at: 0)
        
        loadCalorieData()
    }
    
    private func loadCalorieData() {
        let timeRange: TimeInterval
        switch timeRangeSegmentedControl.selectedSegmentIndex {
        case 0: // Day
            timeRange = 24 * 60 * 60
        case 1: // Week
            timeRange = 7 * 24 * 60 * 60
        case 2: // Month
            timeRange = 30 * 24 * 60 * 60
        case 3: // Year
            timeRange = 365 * 24 * 60 * 60
        default:
            timeRange = 7 * 24 * 60 * 60
        }
        
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-timeRange)
        
        dataManager.fetchCalorieData(from: startDate, to: endDate) { [weak self] entries in
            self?.calorieEntries = entries
            DispatchQueue.main.async {
                self?.updateChartData()
                self?.updateStats()
            }
        }
    }
    
    private func updateChartData() {
        let entries = calorieEntries.enumerated().map { index, entry in
            ChartDataEntry(x: Double(index), y: entry.calories)
        }
        
        let dataSet = LineChartDataSet(entries: entries, label: "Calories")
        
        // Style the line
        dataSet.mode = .cubicBezier
        dataSet.drawCirclesEnabled = true
        dataSet.circleRadius = 4
        dataSet.circleColors = [.systemGreen]
        dataSet.circleHoleColor = .secondarySystemBackground
        dataSet.colors = [.systemGreen]
        dataSet.lineWidth = 2
        
        // Style the fill
        dataSet.drawFilledEnabled = true
        dataSet.fillColor = .systemGreen
        dataSet.fillAlpha = 0.1
        
        // Add value labels
        dataSet.drawValuesEnabled = true
        dataSet.valueFont = .systemFont(ofSize: 10)
        dataSet.valueTextColor = .secondaryLabel
        dataSet.valueFormatter = DefaultValueFormatter(decimals: 0)
        
        chartView.data = LineChartData(dataSet: dataSet)
        
        // Animate
        chartView.animate(xAxisDuration: 0.5, yAxisDuration: 0.5, easingOption: .easeInOutQuart)
    }

    private func updateStats() {
        guard !calorieEntries.isEmpty else { return }
        
        // Calculate average
        let average = calorieEntries.map { $0.calories }.reduce(0, +) / Double(calorieEntries.count)
        
        // Calculate deficit/surplus
        let lastEntry = calorieEntries.last!
        let deficit = lastEntry.goal - lastEntry.calories
        
        // Calculate streak
        var streak = 0
        for entry in calorieEntries.reversed() {
            if entry.calories <= entry.goal {
                streak += 1
            } else {
                break
            }
        }
        
        // Update UI with animations
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseInOut], animations: {
            // Update stats cards
            if let averageLabel = self.averageCard.subviews.first?.subviews[1] as? UILabel {
                averageLabel.text = String(format: "%.0f", average)
            }
            
            if let deficitLabel = self.deficitCard.subviews.first?.subviews[1] as? UILabel {
                deficitLabel.text = String(format: "%.0f", abs(deficit))
                deficitLabel.textColor = deficit >= 0 ? .systemGreen : .systemRed
            }
            
            if let streakLabel = self.streakCard.subviews.first?.subviews[1] as? UILabel {
                streakLabel.text = "\(streak)"
            }
        }, completion: nil)
    }

    // MARK: - Helper Functions
    private func createCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 6
        card.layer.shadowOpacity = 0.1
        return card
    }

    private func createStatsCard(title: String, value: String, unit: String) -> UIView {
        let card = createCard()
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 24, weight: .bold)
        
        let unitLabel = UILabel()
        unitLabel.text = unit
        unitLabel.font = .systemFont(ofSize: 12)
        unitLabel.textColor = .secondaryLabel
        
        [titleLabel, valueLabel, unitLabel].forEach { stackView.addArrangedSubview($0) }
        
        card.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 100),
            stackView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        
        return card
    }

    // MARK: - Animations
    private func animateContentIn() {
        contentView.alpha = 0
        contentView.transform = CGAffineTransform(translationX: 0, y: 20)
        
        UIView.animate(withDuration: 0.5, delay: 0.1, options: [.curveEaseOut], animations: {
            self.contentView.alpha = 1
            self.contentView.transform = .identity
        }, completion: nil)
    }

    // MARK: - Actions
    @objc private func timeRangeChanged() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        loadCalorieData()
    }

    // MARK: - Gestures
    private func setupGestures() {
        let cardTapGesture = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        trendCard.addGestureRecognizer(cardTapGesture)
        trendCard.isUserInteractionEnabled = true
    }
    
    @objc private func cardTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        animateCardTap(trendCard)
    }
    
    private func animateCardTap(_ card: UIView) {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.allowUserInteraction, .curveEaseInOut], animations: {
            card.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: {
                card.transform = .identity
            }, completion: nil)
        }
    }
}