import UIKit
import SwiftUI
import Charts

class MacrosViewController: UIViewController {
    // MARK: - Properties
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Main stats views
    private let headerView = UIView()
    private let macrosSummaryView = MacrosSummaryView()
    private let dateFilterControl = DateFilterControl()
    private let macrosChartContainer = UIView()
    private let macrosTrendChart = MacrosTrendChartView()
    private let mealBreakdownView = MealBreakdownView()
    private let goalProgressView = GoalProgressView()
    private let refreshControl = UIRefreshControl()
    
    // New components
    private let nutritionInsightsView = NutritionInsightsView()
    private let weeklyOverviewChart = WeeklyOverviewChartView()
    private let macroBalanceView = MacroBalanceView()
    
    // Animation properties
    private var cardViews: [UIView] = []
    private var isFirstLoad = true
    
    // Data
    private var macrosEntries: [Models.MacrosEntry] = []
    private var currentGoalType: GoalType = .maintenance
    private var selectedDateRange: DateRange = .today
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupNavigationBar()
        setupRefreshControl()
        loadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh data when view appears
        loadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if isFirstLoad {
            animateCardsIn()
            isFirstLoad = false
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup scroll view with physics
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Header section
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .clear
        
        // Date filter control with improved appearance
        dateFilterControl.translatesAutoresizingMaskIntoConstraints = false
        dateFilterControl.delegate = self
        dateFilterControl.layer.cornerRadius = 22
        dateFilterControl.clipsToBounds = true
        
        // Configure the chart container
        macrosChartContainer.translatesAutoresizingMaskIntoConstraints = false
        macrosChartContainer.backgroundColor = .secondarySystemBackground
        macrosChartContainer.layer.cornerRadius = 20
        
        // Setup shadow for card views
        [macrosSummaryView, macrosChartContainer, macrosTrendChart,
         mealBreakdownView, goalProgressView, nutritionInsightsView,
         weeklyOverviewChart, macroBalanceView].forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            view.layer.cornerRadius = 20
            view.backgroundColor = .secondarySystemBackground
            view.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
            view.layer.shadowOffset = CGSize(width: 0, height: 6)
            view.layer.shadowRadius = 16
            view.layer.shadowOpacity = 1
            cardViews.append(view)
        }
        
        // Add subviews to content view
        [headerView, dateFilterControl, macrosSummaryView, macrosChartContainer, 
         macrosTrendChart, weeklyOverviewChart, mealBreakdownView, 
         macroBalanceView, nutritionInsightsView, goalProgressView].forEach { subview in
            contentView.addSubview(subview)
        }
    }
    
    private func setupConstraints() {
        let spacing: CGFloat = 20
        
        NSLayoutConstraint.activate([
            // ScrollView constraints
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView constraints - make it the same width as scroll view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Header constraints
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: spacing),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            headerView.heightAnchor.constraint(equalToConstant: 50),
            
            // Date filter control
            dateFilterControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            dateFilterControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            dateFilterControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            dateFilterControl.heightAnchor.constraint(equalToConstant: 44),
            
            // Macros summary view
            macrosSummaryView.topAnchor.constraint(equalTo: dateFilterControl.bottomAnchor, constant: spacing),
            macrosSummaryView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            macrosSummaryView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            macrosSummaryView.heightAnchor.constraint(equalToConstant: 150),
            
            // Macros chart container
            macrosChartContainer.topAnchor.constraint(equalTo: macrosSummaryView.bottomAnchor, constant: spacing),
            macrosChartContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            macrosChartContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            macrosChartContainer.heightAnchor.constraint(equalToConstant: 380),
            
            // Weekly overview chart
            weeklyOverviewChart.topAnchor.constraint(equalTo: macrosChartContainer.bottomAnchor, constant: spacing),
            weeklyOverviewChart.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            weeklyOverviewChart.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            weeklyOverviewChart.heightAnchor.constraint(equalToConstant: 260),
            
            // Macros trend chart
            macrosTrendChart.topAnchor.constraint(equalTo: weeklyOverviewChart.bottomAnchor, constant: spacing),
            macrosTrendChart.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            macrosTrendChart.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            macrosTrendChart.heightAnchor.constraint(equalToConstant: 280),
            
            // Macro balance view
            macroBalanceView.topAnchor.constraint(equalTo: macrosTrendChart.bottomAnchor, constant: spacing),
            macroBalanceView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            macroBalanceView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            macroBalanceView.heightAnchor.constraint(equalToConstant: 200),
            
            // Meal breakdown view
            mealBreakdownView.topAnchor.constraint(equalTo: macroBalanceView.bottomAnchor, constant: spacing),
            mealBreakdownView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            mealBreakdownView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            mealBreakdownView.heightAnchor.constraint(equalToConstant: 260),
            
            // Nutrition insights view
            nutritionInsightsView.topAnchor.constraint(equalTo: mealBreakdownView.bottomAnchor, constant: spacing),
            nutritionInsightsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            nutritionInsightsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            nutritionInsightsView.heightAnchor.constraint(equalToConstant: 220),
            
            // Goal progress view
            goalProgressView.topAnchor.constraint(equalTo: nutritionInsightsView.bottomAnchor, constant: spacing),
            goalProgressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            goalProgressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            goalProgressView.heightAnchor.constraint(equalToConstant: 200),
            goalProgressView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -spacing)
        ])
    }
    
    private func setupNavigationBar() {
        title = "Nutrition"
        
        // Create settings button
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape.fill"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )
        
        // Create share button
        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareMacroSummary)
        )
        
        navigationItem.rightBarButtonItems = [settingsButton, shareButton]
        
        // Apply large title
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
    }
    
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        refreshControl.tintColor = .systemIndigo
        scrollView.refreshControl = refreshControl
    }
    
    // MARK: - Animations
    private func animateCardsIn() {
        // Prepare cards for animation
        cardViews.forEach {
            $0.alpha = 0
            $0.transform = CGAffineTransform(translationX: 0, y: 30)
        }
        
        // Animate each card with staggered timing
        for (index, cardView) in cardViews.enumerated() {
            UIView.animate(
                withDuration: 0.5,
                delay: Double(index) * 0.1,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: .curveEaseOut,
                animations: {
                    cardView.alpha = 1
                    cardView.transform = .identity
                }
            )
        }
    }
    
    private func pulseAnimation(for view: UIView) {
        UIView.animate(withDuration: 0.2, animations: {
            view.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2) {
                view.transform = CGAffineTransform.identity
            }
        })
    }
    
    // MARK: - Data Loading
    private func loadData() {
        // Start loading animation
        refreshControl.beginRefreshing()
        
        // Get date range based on selection
        let endDate = Date()
        let startDate: Date
        
        switch selectedDateRange {
        case .today:
            startDate = Calendar.current.startOfDay(for: endDate)
        case .week:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = Calendar.current.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        }
        
        // Here you would fetch data from your data manager
        // For this example, we'll use sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Sample data - Replace with actual data fetching
            self.macrosEntries = self.createSampleData(from: startDate, to: endDate)
            
            // Update UI components
            self.updateUI()
            
            // End refreshing
            self.refreshControl.endRefreshing()
        }
    }
    
    private func updateUI() {
        guard let latestEntry = macrosEntries.last else { return }
        
        // Update macros summary view with haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        macrosSummaryView.configure(with: latestEntry)
        
        // Update macros chart view
        updateMacrosChart(with: macrosEntries)
        
        // Update weekly overview
        weeklyOverviewChart.configure(with: Array(macrosEntries.suffix(7)))
        
        // Update trend chart
        macrosTrendChart.configure(with: macrosEntries)
        
        // Update macro balance
        macroBalanceView.configure(with: latestEntry)
        
        // Update meal breakdown
        if let meals = latestEntry.meals, !meals.isEmpty {
            mealBreakdownView.configure(with: meals)
        } else {
            mealBreakdownView.showEmptyState()
        }
        
        // Update nutrition insights
        nutritionInsightsView.configure(with: macrosEntries)
        
        // Update goal progress
        goalProgressView.configure(with: latestEntry, goalType: currentGoalType)
    }
    
    private func updateMacrosChart(with entries: [Models.MacrosEntry]) {
        // Clear existing content
        for subview in macrosChartContainer.subviews {
            subview.removeFromSuperview()
        }
        
        // Create our new beautiful chart using SwiftUI
        let chartView = MacrosChartView(entries: entries)
            .environment(\.colorScheme, self.traitCollection.userInterfaceStyle == .dark ? .dark : .light)
        
        let hostingController = UIHostingController(rootView: chartView)
        hostingController.view.backgroundColor = .clear
        
        addChild(hostingController)
        macrosChartContainer.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: macrosChartContainer.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: macrosChartContainer.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: macrosChartContainer.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: macrosChartContainer.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func refreshData() {
        loadData()
    }
    
    @objc private func showSettings() {
        let settingsVC = MacrosSettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.modalPresentationStyle = .formSheet
        present(navController, animated: true)
    }
    
    @objc private func shareMacroSummary() {
        guard let latestEntry = macrosEntries.last else { return }
        
        // Create a snapshot of the macros summary view
        let renderer = UIGraphicsImageRenderer(bounds: macrosSummaryView.bounds)
        let image = renderer.image { ctx in
            macrosSummaryView.drawHierarchy(in: macrosSummaryView.bounds, afterScreenUpdates: true)
        }
        
        // Create share text
        let shareText = """
        My Macros for \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)):
        Calories: \(Int(latestEntry.calories))/\(Int(latestEntry.calorieGoal)) kcal
        Protein: \(Int(latestEntry.proteins))/\(Int(latestEntry.proteinGoal)) g
        Carbs: \(Int(latestEntry.carbs))/\(Int(latestEntry.carbGoal)) g
        Fat: \(Int(latestEntry.fats))/\(Int(latestEntry.fatGoal)) g
        
        Tracked with Macrotracker
        """
        
        // Create activity view controller
        let activityVC = UIActivityViewController(activityItems: [shareText, image], applicationActivities: nil)
        present(activityVC, animated: true)
    }
}

// MARK: - DateFilterControlDelegate
extension MacrosViewController: DateFilterControlDelegate {
    func dateRangeChanged(to range: DateRange) {
        selectedDateRange = range
        loadData()
        
        // Add haptic feedback
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - UIScrollViewDelegate
extension MacrosViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Parallax effect for chart views
        let offset = scrollView.contentOffset.y
        
        macrosChartContainer.transform = CGAffineTransform(translationX: 0, y: offset * 0.05)
        macrosTrendChart.transform = CGAffineTransform(translationX: 0, y: offset * 0.03)
    }
}

// MARK: - Sample Data Generator
private extension MacrosViewController {
    func createSampleData(from startDate: Date, to endDate: Date) -> [Models.MacrosEntry] {
        // This is a placeholder for sample data generation
        // In a real app, this would come from your data source
        return Models.MacrosEntry.generateSampleData(from: startDate, to: endDate)
    }
}

// MARK: - Enums
enum GoalType {
    case deficit
    case maintenance
    case surplus
}

enum DateRange {
    case today
    case week
    case month
}