import UIKit
import SwiftUI
import Charts // Keep Charts import if MacrosChartView uses it, otherwise remove. DGCharts is used elsewhere.

class MacrosViewController: UIViewController, UIScrollViewDelegate { // Add UIScrollViewDelegate conformance
    // MARK: - Properties
    private let scrollView = UIScrollView()
    // Change contentView to UIStackView
    private let contentView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24 // Use the defined spacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // Main stats views
    private let headerView = UIView() // Keep as UIView for now, maybe replace later
    private let macrosSummaryView = MacrosSummaryView()
    private let dateFilterControl = DateFilterControl() // Keep as separate view
    private let macrosChartContainer = UIView() // Keep container for SwiftUI chart
    private let macrosTrendChart = MacrosTrendChartView() // Keep custom view
    private let mealBreakdownView = MealBreakdownView() // Keep custom view
    private let goalProgressView = GoalProgressView() // Keep custom view
    private let refreshControl = UIRefreshControl()

    // New components
    private let nutritionInsightsView = NutritionInsightsView() // Keep custom view
    private let weeklyOverviewChart = WeeklyOverviewChartView() // Keep custom view
    private let macroBalanceView = MacroBalanceView() // Keep custom view
    
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
        scrollView.contentInsetAdjustmentBehavior = .automatic // Change to automatic or handle safe area manually
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self // Ensure delegate is set

        // contentView is already configured as UIStackView
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // Header section - Keep setup, but it will be added to stack view later
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .clear

        // Date filter control - Keep setup, but it will be added to stack view later
        dateFilterControl.translatesAutoresizingMaskIntoConstraints = false
        dateFilterControl.delegate = self
        // Remove cornerRadius/clipsToBounds from control itself, apply to a container if needed
        // dateFilterControl.layer.cornerRadius = 22
        // dateFilterControl.clipsToBounds = true

        // Configure the chart container - Keep setup, but it will be added to stack view later
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

        // Add subviews to the UIStackView (contentView)
        [headerView, dateFilterControl, macrosSummaryView, macrosChartContainer,
         macrosTrendChart, weeklyOverviewChart, mealBreakdownView,
         macroBalanceView, nutritionInsightsView, goalProgressView].forEach { subview in
            // Add horizontal padding if needed, or handle it in constraints
            contentView.addArrangedSubview(subview)
        }
    }

    private func setupConstraints() {
        let sideMargin: CGFloat = 20

        NSLayoutConstraint.activate([
            // ScrollView constraints
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // ContentView (UIStackView) constraints
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24), // Add top padding
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: sideMargin),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -sideMargin),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32), // Add bottom padding
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * sideMargin), // Constrain width relative to scroll view frame

            // --- Remove individual vertical constraints ---
            // The UIStackView handles vertical layout and spacing.

            // --- Keep necessary height constraints (or let intrinsic size work) ---
            // Keep fixed heights for header and date control for now.
            headerView.heightAnchor.constraint(equalToConstant: 50),
            dateFilterControl.heightAnchor.constraint(equalToConstant: 44),
            // Remove fixed heights for the content cards to allow dynamic sizing.
            // Ensure these views have proper internal constraints or intrinsicContentSize.
            // macrosSummaryView.heightAnchor.constraint(equalToConstant: 160),
            // macrosChartContainer.heightAnchor.constraint(equalToConstant: 380), // Remove height constraint for SwiftUI container too.
            // weeklyOverviewChart.heightAnchor.constraint(equalToConstant: 280),
            // macrosTrendChart.heightAnchor.constraint(equalToConstant: 320),
            // macroBalanceView.heightAnchor.constraint(equalToConstant: 260),
            // mealBreakdownView.heightAnchor.constraint(equalToConstant: 320),
            // nutritionInsightsView.heightAnchor.constraint(equalToConstant: 240),
            // goalProgressView.heightAnchor.constraint(equalToConstant: 240),

            // --- Keep horizontal constraints if needed (though stack view might handle this if alignment is .fill) ---
            // Example: If headerView shouldn't fill width:
            // headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            // headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            // (Repeat for other views if they don't fill width by default)
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
    // Comment out parallax for now to isolate layout issues
    /*
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Parallax effect for chart views
        let offset = scrollView.contentOffset.y

        macrosChartContainer.transform = CGAffineTransform(translationX: 0, y: offset * 0.05)
        macrosTrendChart.transform = CGAffineTransform(translationX: 0, y: offset * 0.03)
    }
    */

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
