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
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Header section
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = .clear
        
        // Date filter control
        dateFilterControl.translatesAutoresizingMaskIntoConstraints = false
        dateFilterControl.delegate = self
        
        // Configure the chart container
        macrosChartContainer.translatesAutoresizingMaskIntoConstraints = false
        macrosChartContainer.backgroundColor = .clear
        macrosChartContainer.layer.cornerRadius = 16
        
        // Add subviews to content view
        [headerView, macrosSummaryView, dateFilterControl, macrosChartContainer, 
         macrosTrendChart, mealBreakdownView, goalProgressView].forEach { subview in
            subview.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(subview)
        }
        
        // Apply card style to main views
        [macrosSummaryView, macrosTrendChart, mealBreakdownView, goalProgressView].forEach { view in
            view.layer.cornerRadius = 16
            view.backgroundColor = .secondarySystemBackground
        }
    }
    
    private func setupConstraints() {
        let spacing: CGFloat = 16
        
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
            macrosSummaryView.heightAnchor.constraint(equalToConstant: 140),
            
            // Macros chart container - our beautiful new chart
            macrosChartContainer.topAnchor.constraint(equalTo: macrosSummaryView.bottomAnchor, constant: spacing),
            macrosChartContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            macrosChartContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            macrosChartContainer.heightAnchor.constraint(equalToConstant: 420),
            
            // Macros trend chart
            macrosTrendChart.topAnchor.constraint(equalTo: macrosChartContainer.bottomAnchor, constant: spacing),
            macrosTrendChart.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            macrosTrendChart.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            macrosTrendChart.heightAnchor.constraint(equalToConstant: 280),
            
            // Meal breakdown view
            mealBreakdownView.topAnchor.constraint(equalTo: macrosTrendChart.bottomAnchor, constant: spacing),
            mealBreakdownView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            mealBreakdownView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            mealBreakdownView.heightAnchor.constraint(equalToConstant: 240),
            
            // Goal progress view
            goalProgressView.topAnchor.constraint(equalTo: mealBreakdownView.bottomAnchor, constant: spacing),
            goalProgressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: spacing),
            goalProgressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -spacing),
            goalProgressView.heightAnchor.constraint(equalToConstant: 180),
            goalProgressView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -spacing)
        ])
    }
    
    private func setupNavigationBar() {
        title = "Nutrition"
        
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )
        navigationItem.rightBarButtonItem = settingsButton
    }
    
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        scrollView.refreshControl = refreshControl
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
        
        // Update macros summary view
        macrosSummaryView.configure(with: latestEntry)
        
        // Update macros chart view with our beautiful new implementation
        updateMacrosChart(with: macrosEntries)
        
        // Update trend chart
        macrosTrendChart.configure(with: macrosEntries)
        
        // Update meal breakdown
        if let meals = latestEntry.meals, !meals.isEmpty {
            mealBreakdownView.configure(with: meals)
        } else {
            mealBreakdownView.showEmptyState()
        }
        
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
        present(navController, animated: true)
    }
    
    // MARK: - Sample Data
    private func createSampleData(from startDate: Date, to endDate: Date) -> [Models.MacrosEntry] {
        let calendar = Calendar.current
        let numberOfDays = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        
        var entries: [Models.MacrosEntry] = []
        
        for day in 0...numberOfDays {
            let date = calendar.date(byAdding: .day, value: day, to: startDate) ?? Date()
            
            // Simulate some variance in data
            let proteins = Double.random(in: 100...150)
            let carbs = Double.random(in: 180...250)
            let fats = Double.random(in: 50...80)
            
            // Create some sample meals
            var meals: [Models.Meal] = []
            if calendar.isDateInToday(date) {
                meals = [
                    Models.Meal(
                        id: UUID(),
                        name: "Breakfast",
                        time: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? date,
                        proteins: 30,
                        carbs: 40,
                        fats: 15
                    ),
                    Models.Meal(
                        id: UUID(),
                        name: "Lunch",
                        time: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: date) ?? date,
                        proteins: 45,
                        carbs: 60,
                        fats: 20
                    ),
                    Models.Meal(
                        id: UUID(),
                        name: "Dinner",
                        time: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: date) ?? date,
                        proteins: 40,
                        carbs: 50,
                        fats: 25
                    )
                ]
            }
            
            let entry = Models.MacrosEntry(
                id: UUID(),
                date: date,
                proteins: proteins,
                carbs: carbs,
                fats: fats,
                proteinGoal: 150,
                carbGoal: 250,
                fatGoal: 65,
                micronutrients: [],
                water: Double.random(in: 1500...2500),
                waterGoal: 2500,
                meals: meals
            )
            
            entries.append(entry)
        }
        
        return entries.sorted { $0.date < $1.date }
    }
}

// MARK: - DateFilterControlDelegate
extension MacrosViewController: DateFilterControlDelegate {
    func dateRangeChanged(to range: DateRange) {
        selectedDateRange = range
        loadData()
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