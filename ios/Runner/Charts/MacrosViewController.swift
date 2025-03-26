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
    // Removed macrosSummaryView
    private let dateFilterControl = DateFilterControl() // Keep as separate view
    private let macrosChartContainer = UIView() // Keep container for SwiftUI chart
    private let macrosTrendChart = MacrosTrendChartView() // Keep custom view
    // Removed mealBreakdownView
    // Removed goalProgressView
    private let refreshControl = UIRefreshControl()

    // New components
    private let nutritionInsightsView = NutritionInsightsView() // Keep custom view
    private let weeklyOverviewChart = WeeklyOverviewChartView() // Keep custom view
    // Removed macroBalanceView
    
    // Animation properties
    private var cardViews: [UIView] = []
    private var isFirstLoad = true
    
    // Data
    private var macrosEntries: [Models.MacrosEntry] = [] // For the main selected range/latest entry
    private var weeklyMacrosEntries: [Models.MacrosEntry] = [] // For WeeklyOverviewChart
    private var monthlyMacrosEntries: [Models.MacrosEntry] = [] // For MacrosTrendChart (up to 30 days)
    private var currentGoalType: GoalType = .maintenance
    private var selectedDateRange: DateRange = .today
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupNavigationBar()
        setupRefreshControl()
        setupNotificationObserver() // Add observer setup
        loadData()
    }

    deinit {
        // Remove observer when the view controller is deallocated
        NotificationCenter.default.removeObserver(self, name: .macrosDataDidChange, object: nil)
        print("[MacrosViewController] Notification observer removed.")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // --- Logging ---
        print("[MacrosViewController] viewWillAppear called. Triggering loadData().")
        // --- End Logging ---
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
        // Removed macrosSummaryView, mealBreakdownView, goalProgressView, macroBalanceView from this list
        [macrosChartContainer, macrosTrendChart,
         nutritionInsightsView, weeklyOverviewChart].forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            view.layer.cornerRadius = 20
            view.backgroundColor = .secondarySystemBackground
            view.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
            view.layer.shadowOffset = CGSize(width: 0, height: 6)
            view.layer.shadowRadius = 16
            view.layer.shadowOpacity = 1
            cardViews.append(view)
        }

        // Add subviews to the UIStackView (contentView) in the desired order
        // Moved dateFilterControl above weeklyOverviewChart
        // Removed macrosSummaryView, mealBreakdownView, goalProgressView, macroBalanceView
        [headerView, macrosChartContainer, macrosTrendChart,
         dateFilterControl, weeklyOverviewChart,
         nutritionInsightsView].forEach { subview in
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

        // Create refresh button
        let refreshButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshData) // Use existing refreshData action
        )
        
        navigationItem.rightBarButtonItems = [settingsButton, shareButton, refreshButton] // Add refresh button
        
        // Apply large title
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
    }
    
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        refreshControl.tintColor = .systemIndigo
        scrollView.refreshControl = refreshControl
    }

    // MARK: - Notification Handling
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMacrosDataChanged),
            name: .macrosDataDidChange,
            object: nil
        )
        print("[MacrosViewController] Notification observer added.")
    }

    @objc private func handleMacrosDataChanged() {
        print("[MacrosViewController] Received macrosDataDidChange notification. Reloading data.")
        // Ensure data loading happens on the main thread if called from a background notification
        DispatchQueue.main.async {
            self.loadData()
        }
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
        // Use a DispatchGroup to coordinate multiple async fetches
        let group = DispatchGroup()

        // Start loading animation only if not already refreshing
        // This prevents starting multiple refreshes if called rapidly (e.g., viewWillAppear + manual refresh)
        if !refreshControl.isRefreshing {
             print("[MacrosViewController] Starting refresh control animation.")
             refreshControl.beginRefreshing()
        } else {
             print("[MacrosViewController] Refresh already in progress, skipping beginRefreshing.")
        }

        let calendar = Calendar.current
        let today = Date()

        // --- Fetch 1: Data for the selected date range (for main chart/latest entry) ---
        group.enter()
        let selectedEndDate = today
        let selectedStartDate: Date
        switch selectedDateRange {
        case .today:
            selectedStartDate = calendar.startOfDay(for: selectedEndDate)
        case .week:
            selectedStartDate = calendar.date(byAdding: .day, value: -7, to: selectedEndDate) ?? selectedEndDate
        case .month:
            selectedStartDate = calendar.date(byAdding: .month, value: -1, to: selectedEndDate) ?? selectedEndDate
        }
        print("[MacrosViewController] Fetching main data from \(selectedStartDate) to \(selectedEndDate)")
        StatsDataManager.shared.fetchMacroData(from: selectedStartDate, to: selectedEndDate) { [weak self] fetchedEntries in
            self?.macrosEntries = fetchedEntries
            print("[MacrosViewController] Fetched main data: \(fetchedEntries.count) entries")
            group.leave()
        }

        // --- Fetch 2: Data for the last 7 days (for Weekly Overview) ---
        group.enter()
        let weeklyStartDate = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        print("[MacrosViewController] Fetching weekly data from \(weeklyStartDate) to \(today)")
        StatsDataManager.shared.fetchMacroData(from: weeklyStartDate, to: today) { [weak self] fetchedEntries in
            self?.weeklyMacrosEntries = fetchedEntries
            print("[MacrosViewController] Fetched weekly data: \(fetchedEntries.count) entries")
            group.leave()
        }

        // --- Fetch 3: Data for the last 30 days (for Trend Chart) ---
        group.enter()
        let monthlyStartDate = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        print("[MacrosViewController] Fetching monthly data from \(monthlyStartDate) to \(today)")
        StatsDataManager.shared.fetchMacroData(from: monthlyStartDate, to: today) { [weak self] fetchedEntries in
            self?.monthlyMacrosEntries = fetchedEntries
            print("[MacrosViewController] Fetched monthly data: \(fetchedEntries.count) entries")
            group.leave()
        }

        // --- Update UI after all fetches complete ---
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            // Ensure refresh control stops *after* all data is fetched and UI is updated
            defer {
                print("[MacrosViewController] Ending refresh control animation after all fetches.")
                self.refreshControl.endRefreshing()
            }

            print("[MacrosViewController] All data fetches complete. Updating UI.")
            self.updateUI()
        }

        // Removed the old single fetch and DispatchQueue.main.asyncAfter block
        /* DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Sample data - Replace with actual data fetching
            self.macrosEntries = self.createSampleData(from: startDate, to: endDate)
            
            // Update UI components
            self.updateUI()
        } */
    }

    private func updateUI() {
        // --- Logging ---
        print("[MacrosViewController] updateUI called. Entries count: \(macrosEntries.count)")
        if let latest = macrosEntries.last {
            print("[MacrosViewController] Latest entry date: \(latest.date), P: \(latest.proteins), C: \(latest.carbs), F: \(latest.fats), PG: \(latest.proteinGoal), CG: \(latest.carbGoal), FG: \(latest.fatGoal)")
        } else {
            print("[MacrosViewController] updateUI called but macrosEntries is empty.")
            // Consider showing an empty state for all components if needed
        }
        // --- End Logging ---

        // Use the main macrosEntries for the latest entry data if needed,
        // but use the specific weekly/monthly data for the charts.
        guard let latestEntry = macrosEntries.last else {
             // If no entries for the selected range, still try to configure charts with their data
             print("[MacrosViewController] No latest entry found for selected range. Configuring charts with fetched weekly/monthly data.")
             updateMacrosChart(with: macrosEntries) // Main chart uses selected range data
             weeklyOverviewChart.configure(with: weeklyMacrosEntries) // Use weekly data
             macrosTrendChart.configure(with: monthlyMacrosEntries) // Use monthly data
             // and skip configuration for views requiring a single latest entry.
             print("[MacrosViewController] No latest entry found. Configuring with empty data where possible.")
             // Skip: macrosSummaryView.configure requires a non-nil entry
             updateMacrosChart(with: [])
             weeklyOverviewChart.configure(with: [])
             macrosTrendChart.configure(with: [])
             // Skip: macroBalanceView.configure - View Removed
             // mealBreakdownView.configure - View Removed
             nutritionInsightsView.configure(with: macrosEntries) // Configure insights with selected range data
             // Skip: goalProgressView.configure - View Removed
             // Skip: macrosSummaryView.configure - View Removed
            // updateMacrosChart(with: []) // Already called above
            // weeklyOverviewChart.configure(with: []) // Already called above
            // macrosTrendChart.configure(with: []) // Already called above
            // Skip: macroBalanceView.configure - View Removed
            // mealBreakdownView.configure - View Removed
            // nutritionInsightsView.configure(with: []) // Already called above
            // Skip: goalProgressView.configure likely requires a non-nil entry
            return
        }

        // Update macros summary view with haptic feedback - Removed macrosSummaryView update
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // macrosSummaryView.configure(with: latestEntry) // Removed
        
        // Update macros chart view (main chart uses selected range data)
        updateMacrosChart(with: macrosEntries)
        
        // Update weekly overview (use dedicated weekly data)
        weeklyOverviewChart.configure(with: weeklyMacrosEntries)
        
        // Update trend chart (use dedicated monthly data)
        macrosTrendChart.configure(with: monthlyMacrosEntries)
        
        // Update macro balance - View Removed
        // macroBalanceView.configure(with: latestEntry)
        
        // Update meal breakdown - Removed mealBreakdownView update
        // if let meals = latestEntry.meals, !meals.isEmpty {
        //     mealBreakdownView.configure(with: meals)
        // } else {
        //     mealBreakdownView.showEmptyState()
        // }
        
        // Update nutrition insights
        nutritionInsightsView.configure(with: macrosEntries)
        
        // Update goal progress - Removed goalProgressView update
        // goalProgressView.configure(with: latestEntry, goalType: currentGoalType)
    }

    private func updateMacrosChart(with entries: [Models.MacrosEntry]) {
        // --- Logging ---
        print("[MacrosViewController] updateMacrosChart called with \(entries.count) entries.")
        // --- End Logging ---

        // Clear existing content
        for subview in macrosChartContainer.subviews {
             // If the subview belongs to a UIHostingController that is a child of this VC, remove the child VC first
             if let hostingController = children.first(where: { $0.view == subview }) as? UIHostingController<MacrosChartView> {
                 hostingController.willMove(toParent: nil)
                 hostingController.view.removeFromSuperview()
                 hostingController.removeFromParent()
             } else {
                 // Otherwise, just remove the subview
                 subview.removeFromSuperview()
             }
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
        
        // Create a snapshot of the macros summary view - TODO: Update this if summary snapshot is needed
        // let renderer = UIGraphicsImageRenderer(bounds: macrosSummaryView.bounds) // Removed reference
        // let image = renderer.image { ctx in
        //     macrosSummaryView.drawHierarchy(in: macrosSummaryView.bounds, afterScreenUpdates: true) // Removed reference
        // }
        let image = UIImage() // Placeholder image
        
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
