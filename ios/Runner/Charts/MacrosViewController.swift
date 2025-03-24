import UIKit
import SwiftUI
import Charts

class MacrosViewController: UIViewController {
    // MARK: - Properties
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Main stats views
    private let macrosSummaryView = MacrosSummaryView()
    private let macrosDistributionChart = MacrosDistributionChartView()
    private let macrosTrendChart = MacrosTrendChartView()
    private let mealBreakdownView = MealBreakdownView()
    private let goalProgressView = GoalProgressView()
    
    // Data
    private var macrosEntries: [Models.MacrosEntry] = []
    private var currentGoalType: GoalType = .maintenance
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupNavigationBar()
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
        
        // Add subviews to content view
        [macrosSummaryView, macrosDistributionChart, macrosTrendChart, 
         mealBreakdownView, goalProgressView].forEach { subview in
            subview.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(subview)
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view constraints
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view constraints
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Subview constraints
            macrosSummaryView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            macrosSummaryView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            macrosSummaryView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            macrosSummaryView.heightAnchor.constraint(equalToConstant: 120),
            
            macrosDistributionChart.topAnchor.constraint(equalTo: macrosSummaryView.bottomAnchor, constant: 16),
            macrosDistributionChart.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            macrosDistributionChart.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            macrosDistributionChart.heightAnchor.constraint(equalToConstant: 200),
            
            macrosTrendChart.topAnchor.constraint(equalTo: macrosDistributionChart.bottomAnchor, constant: 16),
            macrosTrendChart.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            macrosTrendChart.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            macrosTrendChart.heightAnchor.constraint(equalToConstant: 200),
            
            mealBreakdownView.topAnchor.constraint(equalTo: macrosTrendChart.bottomAnchor, constant: 16),
            mealBreakdownView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mealBreakdownView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mealBreakdownView.heightAnchor.constraint(equalToConstant: 250),
            
            goalProgressView.topAnchor.constraint(equalTo: mealBreakdownView.bottomAnchor, constant: 16),
            goalProgressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            goalProgressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            goalProgressView.heightAnchor.constraint(equalToConstant: 150),
            goalProgressView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupNavigationBar() {
        navigationItem.title = "Macros"
        
        let goalButton = UIBarButtonItem(image: UIImage(systemName: "target"), 
                                       style: .plain, 
                                       target: self, 
                                       action: #selector(showGoalSelector))
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gear"), 
                                           style: .plain, 
                                           target: self, 
                                           action: #selector(showSettings))
        navigationItem.rightBarButtonItems = [settingsButton, goalButton]
    }
    
    // MARK: - Data Loading
    private func loadData() {
        StatsDataManager.shared.fetchMacrosData { [weak self] entries in
            self?.macrosEntries = entries
            self?.updateUI()
        }
    }
    
    private func updateUI() {
        let todayEntry = macrosEntries.last
        macrosSummaryView.configure(with: todayEntry)
        macrosDistributionChart.configure(with: todayEntry)
        macrosTrendChart.configure(with: macrosEntries)
        mealBreakdownView.configure(with: todayEntry?.meals ?? [])
        goalProgressView.configure(with: todayEntry, goalType: currentGoalType)
    }
    
    // MARK: - Actions
    @objc private func showGoalSelector() {
        let alert = UIAlertController(title: "Select Goal", 
                                    message: "Choose your nutrition goal", 
                                    preferredStyle: .actionSheet)
        
        GoalType.allCases.forEach { goalType in
            alert.addAction(UIAlertAction(title: goalType.displayName, 
                                        style: .default) { [weak self] _ in
                self?.updateGoalType(goalType)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func updateGoalType(_ goalType: GoalType) {
        currentGoalType = goalType
        // Update macro recommendations based on goal
        let recommendations = MacroRecommendationService.getRecommendations(for: goalType)
        goalProgressView.updateRecommendations(recommendations)
    }
    
    @objc private func showSettings() {
        let settingsVC = MacrosSettingsViewController()
        settingsVC.delegate = self
        let nav = UINavigationController(rootViewController: settingsVC)
        present(nav, animated: true)
    }
}

// MARK: - MacrosSettingsDelegate
extension MacrosViewController: MacrosSettingsDelegate {
    func settingsDidUpdate() {
        loadData()
    }
}

// MARK: - Supporting Types
enum GoalType: CaseIterable {
    case cutting
    case maintenance
    case bulking
    
    var displayName: String {
        switch self {
        case .cutting: return "Weight Loss"
        case .maintenance: return "Maintenance"
        case .bulking: return "Muscle Gain"
        }
    }
}