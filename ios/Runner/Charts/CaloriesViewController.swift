import UIKit
import SwiftUI // Import SwiftUI
// Remove DGCharts import if no longer needed elsewhere in this file
// import DGCharts 

class CaloriesViewController: UIViewController {
    // MARK: - Properties
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    // Remove DGCharts chartView
    // private let chartView = LineChartView() 
    private let dataManager = StatsDataManager.shared
    // Change to store MacrosEntry
    private var macrosEntries: [Models.MacrosEntry] = [] 
    private var hostingController: UIHostingController<AnyView>? // Change type to AnyView

    // Time range selection
    private let timeRangeSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Day", "Week", "Month", "Year"])
        control.selectedSegmentIndex = 1 // Default to week
        control.backgroundColor = .tertiarySystemBackground
        control.selectedSegmentTintColor = .systemGreen
        return control
    }()
    
    // Progress Ring
    private let progressRing: CircularProgressView = {
        let view = CircularProgressView()
        view.progressColor = .systemGreen
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Trend Analysis Card
    private let trendCard = UIView()
    private let trendLabel = UILabel()
    private let trendIcon = UIImageView()
    
    // Stats Cards
    private let statsContainer = UIStackView()
    private let averageCard = UIView()
    private let deficitCard = UIView()
    private let streakCard = UIView()
    
    // Progress View
    private let progressView: CircularProgressView = {
        let view = CircularProgressView()
        view.progressColor = .systemGreen
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        // Remove setupChartView call
        // setupChartView() 
        setupGestures()
        loadData() // Renamed from loadCalorieData
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
        setupChartContainer() // Keep the container setup
        setupBreakdown()
        setupComparisonSection()
        
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
        chartContainer.clipsToBounds = true // Ensure SwiftUI view is clipped
        
        // Don't add the old chartView here
        // chartView.translatesAutoresizingMaskIntoConstraints = false
        // chartContainer.addSubview(chartView)
        
        contentView.addArrangedSubview(chartContainer)
        
        NSLayoutConstraint.activate([
            chartContainer.heightAnchor.constraint(equalToConstant: 400) // Match SwiftUI view height
            // Constraints for the hostingController's view will be added when data loads
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
        
        // Add meal rows with interactive elements
        let meals = [
            ("Breakfast", 450),
            ("Lunch", 650),
            ("Dinner", 550),
            ("Snacks", 200)
        ]
        
        meals.forEach { meal, calories in
            let mealRow = createMealRow(name: meal, calories: calories)
            stackView.addArrangedSubview(mealRow)
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(mealRowTapped(_:)))
            mealRow.isUserInteractionEnabled = true
            mealRow.addGestureRecognizer(tapGesture)
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
    
    @objc private func mealRowTapped(_ sender: UITapGestureRecognizer) {
        guard let mealRow = sender.view else { return }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        animateCardTap(mealRow)
        
        // Get meal name from the first label in the view
        if let nameLabel = mealRow.subviews.first(where: { $0 is UILabel }) as? UILabel,
           let mealName = nameLabel.text {
            showMealDetails(for: mealName)
        }
    }
    
    private func showMealDetails(for mealName: String) {
        // This would show detailed breakdown of the meal
        let alertController = UIAlertController(
            title: "\(mealName) Details",
            message: "Would you like to see nutritional breakdown or edit this meal?",
            preferredStyle: .actionSheet
        )
        
        alertController.addAction(UIAlertAction(title: "View Nutrition", style: .default) { _ in
            // Here you would navigate to a detailed nutrition view
            print("Show nutrition for \(mealName)")
        })
        
        alertController.addAction(UIAlertAction(title: "Edit Meal", style: .default) { _ in
            // Here you would open a meal editor
            print("Edit \(mealName)")
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alertController, animated: true)
    }
    
    private func setupComparisonSection() {
        let comparisonCard = createCard()
        
        let titleLabel = UILabel()
        titleLabel.text = "Calorie Comparison"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let comparisonView = UIView()
        comparisonView.translatesAutoresizingMaskIntoConstraints = false
        
        // Previous day comparison
        let previousDayStack = UIStackView()
        previousDayStack.axis = .vertical
        previousDayStack.spacing = 8
        previousDayStack.alignment = .center
        previousDayStack.translatesAutoresizingMaskIntoConstraints = false
        
        let yesterdayLabel = UILabel()
        yesterdayLabel.text = "Yesterday"
        yesterdayLabel.font = .systemFont(ofSize: 14)
        yesterdayLabel.textColor = .secondaryLabel
        
        let yesterdayValue = UILabel()
        yesterdayValue.text = "1,950"
        yesterdayValue.font = .systemFont(ofSize: 20, weight: .bold)
        
        [yesterdayLabel, yesterdayValue].forEach { previousDayStack.addArrangedSubview($0) }
        
        // VS label
        let vsLabel = UILabel()
        vsLabel.text = "vs"
        vsLabel.font = .systemFont(ofSize: 14, weight: .medium)
        vsLabel.textColor = .secondaryLabel
        vsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Current day
        let currentDayStack = UIStackView()
        currentDayStack.axis = .vertical
        currentDayStack.spacing = 8
        currentDayStack.alignment = .center
        currentDayStack.translatesAutoresizingMaskIntoConstraints = false
        
        let todayLabel = UILabel()
        todayLabel.text = "Today"
        todayLabel.font = .systemFont(ofSize: 14)
        todayLabel.textColor = .secondaryLabel
        
        let todayValue = UILabel()
        todayValue.text = "1,850"
        todayValue.font = .systemFont(ofSize: 20, weight: .bold)
        
        [todayLabel, todayValue].forEach { currentDayStack.addArrangedSubview($0) }
        
        // Difference indicator
        let differenceStack = UIStackView()
        differenceStack.axis = .horizontal
        differenceStack.spacing = 4
        differenceStack.alignment = .center
        differenceStack.translatesAutoresizingMaskIntoConstraints = false
        
        let arrowIcon = UIImageView(image: UIImage(systemName: "arrow.down"))
        arrowIcon.tintColor = .systemGreen
        arrowIcon.contentMode = .scaleAspectFit
        arrowIcon.translatesAutoresizingMaskIntoConstraints = false
        
        let differenceLabel = UILabel()
        differenceLabel.text = "100 calories (5.1%)"
        differenceLabel.font = .systemFont(ofSize: 14)
        differenceLabel.textColor = .systemGreen
        
        [arrowIcon, differenceLabel].forEach { differenceStack.addArrangedSubview($0) }
        
        // Add to comparison view
        [previousDayStack, vsLabel, currentDayStack].forEach { comparisonView.addSubview($0) }
        comparisonView.addSubview(differenceStack)
        
        comparisonCard.addSubview(titleLabel)
        comparisonCard.addSubview(comparisonView)
        
        contentView.addArrangedSubview(comparisonCard)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            comparisonCard.heightAnchor.constraint(equalToConstant: 150),
            
            titleLabel.topAnchor.constraint(equalTo: comparisonCard.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: comparisonCard.leadingAnchor, constant: 16),
            
            comparisonView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            comparisonView.leadingAnchor.constraint(equalTo: comparisonCard.leadingAnchor, constant: 16),
            comparisonView.trailingAnchor.constraint(equalTo: comparisonCard.trailingAnchor, constant: -16),
            comparisonView.bottomAnchor.constraint(equalTo: comparisonCard.bottomAnchor, constant: -16),
            
            previousDayStack.leadingAnchor.constraint(equalTo: comparisonView.leadingAnchor, constant: 24),
            previousDayStack.centerYAnchor.constraint(equalTo: comparisonView.centerYAnchor),
            
            vsLabel.centerXAnchor.constraint(equalTo: comparisonView.centerXAnchor),
            vsLabel.centerYAnchor.constraint(equalTo: comparisonView.centerYAnchor),
            
            currentDayStack.trailingAnchor.constraint(equalTo: comparisonView.trailingAnchor, constant: -24),
            currentDayStack.centerYAnchor.constraint(equalTo: comparisonView.centerYAnchor),
            
            differenceStack.centerXAnchor.constraint(equalTo: comparisonView.centerXAnchor),
            differenceStack.bottomAnchor.constraint(equalTo: comparisonView.bottomAnchor),
            
            arrowIcon.widthAnchor.constraint(equalToConstant: 14),
            arrowIcon.heightAnchor.constraint(equalToConstant: 14)
        ])
        
        // Add tap gesture to comparison card
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(comparisonCardTapped))
        comparisonCard.addGestureRecognizer(tapGesture)
        comparisonCard.isUserInteractionEnabled = true
    }
    
    @objc private func comparisonCardTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let alertController = UIAlertController(
            title: "Choose Comparison",
            message: "Select time period to compare with current day",
            preferredStyle: .actionSheet
        )
        
        let options = ["Yesterday", "Last Week (Average)", "Last Month (Average)", "Same Day Last Week"]
        
        options.forEach { option in
            alertController.addAction(UIAlertAction(title: option, style: .default) { _ in
                print("Compare with \(option)")
                // Here you would update the comparison view with the selected option
            })
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alertController, animated: true)
    }
    
    // Renamed from loadCalorieData
    private func loadData() { 
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
            timeRange = 7 * 24 * 60 * 60 // Default to 7 days
        }
        
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-timeRange)
        
        // Fetch MacrosEntry data instead
        dataManager.fetchMacroData(from: startDate, to: endDate) { [weak self] entries in
            guard let self = self else { return }
            self.macrosEntries = entries
            DispatchQueue.main.async {
                self.updateChartView() // New method to update SwiftUI chart
                self.updateStats()
                // Remove updateWeeklyProgress call
                // self.updateWeeklyProgress() 
            }
        }
    }

    // New method to update the SwiftUI Chart
    private func updateChartView() {
        // Map MacrosEntry to CaloriesEntry for the SwiftUI chart
        let calorieEntriesForChart = macrosEntries.map { macroEntry -> Models.CaloriesEntry in
            return Models.CaloriesEntry(
                date: macroEntry.date,
                calories: macroEntry.calories,
                goal: macroEntry.calorieGoal,
                // Assuming consumed = calories for simplicity, adjust if needed
                consumed: macroEntry.calories, 
                // Pass burned calories if available in MacrosEntry, otherwise 0
                burned: 0 // Placeholder - update if burned calories are in MacrosEntry
            )
        }

        // Pass both calorie and macro entries to the SwiftUI view
        let chartView = CaloriesChartView(calorieEntries: calorieEntriesForChart, macroEntries: macrosEntries)
            .environment(\.colorScheme, self.traitCollection.userInterfaceStyle == .dark ? .dark : .light)
        // Removed unnecessary .eraseToAnyView()

        // Remove existing hosting controller if it exists
        if let existingHC = self.hostingController {
            existingHC.willMove(toParent: nil)
            existingHC.view.removeFromSuperview()
            existingHC.removeFromParent()
            self.hostingController = nil
        }

        // Create and add a new hosting controller
        // Wrap the chartView in AnyView directly during initialization
        let newHostingController = UIHostingController(rootView: AnyView(chartView)) 
        newHostingController.view.backgroundColor = UIColor.clear // Specify UIColor
        addChild(newHostingController)
        
        // Find the chartContainer added in setupUI
        // Ensure chartContainer is accessible or find it reliably
        guard let chartContainer = contentView.arrangedSubviews.first(where: { $0.layer.cornerRadius == 16 && $0.backgroundColor == .secondarySystemBackground }) else {
             print("Error: Chart container not found in updateChartView")
             return
        }
        
        // Clear container before adding new view
        chartContainer.subviews.forEach { $0.removeFromSuperview() } 
        
        chartContainer.addSubview(newHostingController.view)
        newHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            newHostingController.view.topAnchor.constraint(equalTo: chartContainer.topAnchor),
            newHostingController.view.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor),
            newHostingController.view.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor),
            newHostingController.view.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor)
        ])
        newHostingController.didMove(toParent: self)
        self.hostingController = newHostingController // Store the new controller
    }

    private func updateStats() {
        // Use macrosEntries now
        guard !macrosEntries.isEmpty else { return }
        
        // Calculate average calories from macrosEntries
        let average = macrosEntries.map { $0.calories }.reduce(0, +) / Double(macrosEntries.count)
        
        // Calculate deficit/surplus using calorieGoal from macrosEntries
        let lastEntry = macrosEntries.last!
        let deficit = lastEntry.calorieGoal - lastEntry.calories
        
        // Calculate streak based on calorieGoal
        var streak = 0
        for entry in macrosEntries.reversed() {
            if entry.calories <= entry.calorieGoal {
                streak += 1
            } else {
                break
            }
        }
        
        // Update UI with animations (find labels by structure or add identifiers)
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
            
            // Update summary card labels (calories, goal)
            // Use self.contentView inside closure
            if let summaryCard = self.contentView.arrangedSubviews.first(where: { $0.accessibilityIdentifier == "caloriesSummaryCard" }) { // Add identifier if needed
                 if let caloriesLabel = summaryCard.viewWithTagSafe(1) as? UILabel { // Use tags or identifiers
                     caloriesLabel.text = "\(Int(lastEntry.calories))"
                 }
                 if let goalLabel = summaryCard.viewWithTagSafe(3) as? UILabel { // Use tags or identifiers
                     goalLabel.text = "Daily Goal: \(Int(lastEntry.calorieGoal)) calories"
                 }
                 // Update progress ring
                 if let progressRing = summaryCard.viewWithTagSafe(2) as? CircularProgressView { // Use tags or identifiers
                     let progress = lastEntry.calorieGoal > 0 ? CGFloat(lastEntry.calories / lastEntry.calorieGoal) : 0
                     progressRing.progress = progress
                 }
                 if let goalLabel = summaryCard.viewWithTag(3) as? UILabel { // Use tags or identifiers
                     goalLabel.text = "Daily Goal: \(Int(lastEntry.calorieGoal)) calories"
                 }
                 // Update progress ring
                 if let progressRing = summaryCard.viewWithTag(2) as? CircularProgressView { // Use tags or identifiers
                     let progress = lastEntry.calorieGoal > 0 ? CGFloat(lastEntry.calories / lastEntry.calorieGoal) : 0
                     progressRing.progress = progress
                 }
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
        loadData() // Call renamed method
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
} // Add missing closing brace for CaloriesViewController class

// Helper extension to safely access viewWithTag
extension UIView {
    func viewWithTagSafe(_ tag: Int) -> UIView? {
        return self.viewWithTag(tag)
    }
}
