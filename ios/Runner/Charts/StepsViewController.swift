import UIKit
import SwiftUI
import HealthKit
import Charts

class StepsViewController: UIViewController {
    // MARK: - Properties
    
    private let dataManager = StatsDataManager.shared
    private var entries: [Models.StepsEntry] = []
    private let refreshControl = UIRefreshControl()
    private var hostingController: UIHostingController<AnyView>?
    private var isLoadingData = false
    
    // UI Components
    private let headerView = UIView()
    private let headerTitle = UILabel()
    private let headerSubtitle = UILabel()
    private let segmentedControl = UISegmentedControl(items: ["Week", "Month", "Year"])
    
    // Time period for data
    private var selectedTimePeriod: TimePeriod = .week {
        didSet {
            // Only reload if the period actually changed
            if oldValue != selectedTimePeriod {
                loadStepsData(animated: false)
            }
        }
    }
    
    private enum TimePeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .year: return 365
            }
        }
    }
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupRefreshControl()
        loadStepsData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
        
        // Apply appearance based on current theme
        updateAppearance()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateAppearance()
        }
    }
    
    // MARK: - UI Setup
    
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        refreshControl.tintColor = UIColor(named: "AccentColor") ?? .systemBlue
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup header
        setupHeaderView()
        
        // Setup segmented control
        setupSegmentedControl()
        
        // Setup main container
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Setup empty state initially
        let emptyStateView = createEmptyStateView()
        containerView.addSubview(emptyStateView)
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.8)
        ])
        
        // Tag for identification later
        emptyStateView.tag = 100
    }
    
    private func setupHeaderView() {
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        headerTitle.text = "Steps"
        headerTitle.font = .systemFont(ofSize: 28, weight: .bold)
        headerTitle.translatesAutoresizingMaskIntoConstraints = false
        
        headerSubtitle.text = "Track your daily activity"
        headerSubtitle.font = .systemFont(ofSize: 16, weight: .regular)
        headerSubtitle.textColor = .secondaryLabel
        headerSubtitle.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(headerTitle)
        headerView.addSubview(headerSubtitle)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            headerTitle.topAnchor.constraint(equalTo: headerView.topAnchor),
            headerTitle.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            
            headerSubtitle.topAnchor.constraint(equalTo: headerTitle.bottomAnchor, constant: 4),
            headerSubtitle.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerSubtitle.bottomAnchor.constraint(equalTo: headerView.bottomAnchor)
        ])
    }
    
    private func setupSegmentedControl() {
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        
        // Style the segmented control
        segmentedControl.backgroundColor = .tertiarySystemBackground
        segmentedControl.selectedSegmentTintColor = UIColor(named: "AccentColor") ?? .systemBlue
        
        let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.label]
        let selectedTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        segmentedControl.setTitleTextAttributes(textAttributes, for: .normal)
        segmentedControl.setTitleTextAttributes(selectedTextAttributes, for: .selected)
        
        view.addSubview(segmentedControl)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 24),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            segmentedControl.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupNavigationBar() {
        // Clear the back button text
        navigationItem.backButtonDisplayMode = .minimal
        
        // Add right bar button items
        let goalButton = UIBarButtonItem(
            image: UIImage(systemName: "target"),
            style: .plain,
            target: self,
            action: #selector(showGoalSettings)
        )
        
        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareStats)
        )
        
        navigationItem.rightBarButtonItems = [goalButton, shareButton]
    }
    
    private func updateAppearance() {
        // Update UI elements based on current trait collection (light/dark mode)
        if let mainChartView = view.viewWithTag(200) {
            updateChartView(with: entries)
        }
    }
    
    // MARK: - SwiftUI Chart Integration
    
    private func updateChartView(with entries: [Models.StepsEntry], animated: Bool = true) {
        // Remove existing views
        if let existingHostingController = hostingController {
            existingHostingController.willMove(toParent: nil)
            existingHostingController.view.removeFromSuperview()
            existingHostingController.removeFromParent()
            hostingController = nil
        }
        
        // Remove empty state view if it exists
        if let emptyStateView = view.viewWithTag(100) {
            emptyStateView.removeFromSuperview()
        }
        
        // Create SwiftUI chart view with reduced animation for longer periods
        let chartView = StepsChartView(
            entries: entries,
            animateChart: animated && selectedTimePeriod == .week
        )
        .environment(\.colorScheme, traitCollection.userInterfaceStyle == .dark ? .dark : .light)
        
        // Create hosting controller and add as child
        let hostingVC = UIHostingController(rootView: AnyView(chartView))
        addChild(hostingVC)
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.tag = 200
        
        // Create scroll view
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.refreshControl = refreshControl
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.bounces = true
        scrollView.delaysContentTouches = false
        scrollView.contentInsetAdjustmentBehavior = .always
        
        // Add views to hierarchy
        view.addSubview(scrollView)
        scrollView.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: self)
        
        // Configure constraints
        NSLayoutConstraint.activate([
            // Scroll view fills the available space
            scrollView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Hosting view fills scroll view with padding
            hostingVC.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingVC.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingVC.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        
        // Calculate minimum content height
        let safeAreaHeight = view.bounds.height - view.safeAreaInsets.top - view.safeAreaInsets.bottom
        let minimumContentHeight = safeAreaHeight + 200 // Add extra space for comfortable scrolling
        
        // Set minimum height constraint
        hostingVC.view.heightAnchor.constraint(greaterThanOrEqualToConstant: minimumContentHeight).isActive = true
        
        // Save reference
        self.hostingController = hostingVC
        
        // Force layout update
        view.layoutIfNeeded()
    }
    
    // MARK: - Empty State
    
    private func createEmptyStateView() -> UIView {
        let containerView = UIView()
        
        // Create stack view for content
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create illustration image
        let imageView = UIImageView(image: UIImage(systemName: "figure.walk.circle"))
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor(named: "AccentColor") ?? .systemBlue
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create title
        let titleLabel = UILabel()
        titleLabel.text = "No Steps Data"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        
        // Create message
        let messageLabel = UILabel()
        messageLabel.text = "Start moving to track your steps or connect to Apple Health"
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        
        // Create button
        let connectButton = UIButton(type: .system)
        connectButton.setTitle("Connect to Health", for: .normal)
        connectButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        connectButton.backgroundColor = UIColor(named: "AccentColor") ?? .systemBlue
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.layer.cornerRadius = 12
        connectButton.addTarget(self, action: #selector(connectToHealth), for: .touchUpInside)
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add to stack view
        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)
        stackView.addArrangedSubview(connectButton)
        
        containerView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 100),
            imageView.widthAnchor.constraint(equalToConstant: 100),
            
            connectButton.heightAnchor.constraint(equalToConstant: 50),
            connectButton.widthAnchor.constraint(equalToConstant: 200),
            
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    // MARK: - Data Loading
    
    private func loadStepsData(animated: Bool = true) {
        guard !isLoadingData else { return }
        isLoadingData = true
        
        // Show loading state only for longer periods
        if selectedTimePeriod != .week {
            showLoadingIndicator()
        }
        
        // Get date range based on selected period
        let now = Date()
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -selectedTimePeriod.days, to: now) ?? now
        
        // Use background queue for data processing
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.dataManager.fetchStepData(from: startDate, to: now) { entries in
            DispatchQueue.main.async {
                    self.isLoadingData = false
                    self.hideLoadingIndicator()
                    
                    // Update data
                    self.entries = entries
                    
                    if entries.isEmpty {
                        // Show empty state if no data
                        self.showEmptyState()
                    } else {
                        // Update chart with data
                        self.updateChartView(with: entries, animated: animated)
                        self.updateTitleForPeriod()
                    }
                    
                self.refreshControl.endRefreshing()
                }
            }
        }
    }
    
    private func updateTitleForPeriod() {
        let subtitle: String
        switch selectedTimePeriod {
        case .week:
            subtitle = "Last 7 days"
        case .month:
            subtitle = "Last 30 days"
        case .year:
            subtitle = "Last 365 days"
        }
        
        headerSubtitle.text = subtitle
    }
    
    private func showLoadingIndicator() {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        activityIndicator.tag = 300
        activityIndicator.center = view.center
        view.addSubview(activityIndicator)
    }
    
    private func hideLoadingIndicator() {
        if let indicator = view.viewWithTag(300) as? UIActivityIndicatorView {
            indicator.stopAnimating()
            indicator.removeFromSuperview()
        }
    }
    
    private func showEmptyState() {
        let emptyStateView = createEmptyStateView()
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.tag = 100
        view.addSubview(emptyStateView)
        
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 50),
            emptyStateView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8)
        ])
    }
    
    // MARK: - Action Handlers
    
    @objc private func refreshData() {
        loadStepsData()
    }
    
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            selectedTimePeriod = .week
        case 1:
            selectedTimePeriod = .month
        case 2:
            selectedTimePeriod = .year
        default:
            selectedTimePeriod = .week
        }
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
            if let currentGoal = self.entries.last?.goal {
                textField.text = "\(currentGoal)"
            }
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let text = alert.textFields?.first?.text,
                  let goal = Int(text) else { return }
            
            UserDefaults.standard.set(goal, forKey: "steps_goal")
            self?.loadStepsData()
            
            // Show success feedback
            self?.showToast(message: "Step goal updated!")
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    @objc private func shareStats() {
        // Create a snapshot of the chart view
        guard let chartView = view.viewWithTag(200) else { return }
        
        UIGraphicsBeginImageContextWithOptions(chartView.bounds.size, false, 0.0)
        chartView.drawHierarchy(in: chartView.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let shareImage = image else { return }
        
        // Create share text
        let shareText = "Check out my steps data from the MacroTracker app!"
        
        // Create activity view controller
        let activityVC = UIActivityViewController(
            activityItems: [shareText, shareImage],
            applicationActivities: nil
        )
        
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(activityVC, animated: true)
    }
    
    @objc private func connectToHealth() {
        dataManager.requestHealthKitPermissions { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.showToast(message: "Connected to Health successfully!")
                    self?.loadStepsData()
                } else {
                    self?.showToast(message: "Failed to connect to Health", isError: true)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func showToast(message: String, isError: Bool = false) {
        let toastView = UIView()
        toastView.backgroundColor = isError ? .systemRed : .systemGreen
        toastView.alpha = 0
        toastView.layer.cornerRadius = 16
        toastView.clipsToBounds = true
        toastView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        
        toastView.addSubview(label)
        view.addSubview(toastView)
        
        NSLayoutConstraint.activate([
            toastView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toastView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
            
            label.topAnchor.constraint(equalTo: toastView.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: toastView.bottomAnchor, constant: -12)
        ])
        
        UIView.animate(withDuration: 0.3, animations: {
            toastView.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2, options: [], animations: {
                toastView.alpha = 0
            }, completion: { _ in
                toastView.removeFromSuperview()
            })
        })
    }
    
    func updateData(_ entries: [Models.StepsEntry]) {
        self.entries = entries
        // ... existing code ...
    }
}

