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
    private var isScrolling = false // Track scrolling state

    // UI Components
    private let scrollView = UIScrollView()
    private let chartContainerView = UIView() // Specific container for the chart
    private let headerView = UIView()
    private let headerTitle = UILabel()
    private let headerSubtitle = UILabel()
    private let segmentedControl = UISegmentedControl(items: ["Week", "Month", "Year"])
    private var emptyStateView: UIView? // To hold the empty state view

    // Time period for data
    private var selectedTimePeriod: TimePeriod = .week {
        didSet {
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
        setupScrollViewDelegate()
        setupScrollingOptimizations()
        loadStepsData() // Load data initially
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !isLoadingData {
             refreshData()
        }
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
        scrollView.refreshControl = refreshControl
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Setup header
        setupHeaderView()

        // Setup segmented control
        setupSegmentedControl()

        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        // Fix scrolling performance issues
        scrollView.decelerationRate = .normal
        scrollView.contentInsetAdjustmentBehavior = .automatic
        view.addSubview(scrollView)

        // Setup chart container view inside scroll view
        chartContainerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(chartContainerView)
        chartContainerView.tag = 99 // Tag to identify the chart container

        NSLayoutConstraint.activate([
            // Header constraints
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Segmented control constraints
            segmentedControl.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 24),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            segmentedControl.heightAnchor.constraint(equalToConstant: 44),

            // ScrollView constraints
            scrollView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // ChartContainerView constraints (inside ScrollView)
            chartContainerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            chartContainerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            chartContainerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            chartContainerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            chartContainerView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor) // Match scroll view width
        ])

        // Setup empty state initially (it will be added/removed from chartContainerView)
        setupEmptyStateView() // Create it but don't add yet
        showEmptyState() // Show it initially
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

        segmentedControl.backgroundColor = .tertiarySystemBackground
        segmentedControl.selectedSegmentTintColor = UIColor(named: "AccentColor") ?? .systemBlue

        let textAttributes = [NSAttributedString.Key.foregroundColor: UIColor.label]
        let selectedTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
        segmentedControl.setTitleTextAttributes(textAttributes, for: .normal)
        segmentedControl.setTitleTextAttributes(selectedTextAttributes, for: .selected)

        view.addSubview(segmentedControl)
    }

    private func setupNavigationBar() {
        navigationItem.backButtonDisplayMode = .minimal
        let goalButton = UIBarButtonItem(
            image: UIImage(systemName: "target"), style: .plain, target: self, action: #selector(showGoalSettings))
        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(shareStats))
        navigationItem.rightBarButtonItems = [goalButton, shareButton]
    }

    private func updateAppearance() {
        if let hc = hostingController {
            // Update the environment for the existing SwiftUI view
            let chartView = StepsChartView(
                entries: entries,
                animateChart: false // No animation on theme change
            )
            .environment(\.colorScheme, traitCollection.userInterfaceStyle == .dark ? .dark : .light)
            hc.rootView = AnyView(chartView)
        }
    }

    // MARK: - SwiftUI Chart Integration

    // Optimized: Update rootView instead of recreating the controller
    private func updateChartView(with entries: [Models.StepsEntry], animated: Bool = true) {
        // Remove empty state view if it exists
        hideEmptyState()

        // Create the SwiftUI chart view content
        let chartView = StepsChartView(
            entries: entries,
            animateChart: animated && selectedTimePeriod == .week // Only animate for week view
        )
        .environment(\.colorScheme, traitCollection.userInterfaceStyle == .dark ? .dark : .light)

        // Check if hosting controller already exists
        if let existingHC = hostingController {
            // Update the existing hosting controller's root view
            existingHC.rootView = AnyView(chartView)
            print("[StepsViewController] Updated existing hosting controller's root view.")
        } else {
            // Create a new hosting controller if it doesn't exist
            let newHostingController = UIHostingController(rootView: AnyView(chartView))
            addChild(newHostingController) // Add as child VC
            newHostingController.view.translatesAutoresizingMaskIntoConstraints = false
            newHostingController.view.backgroundColor = .clear
            
            // Advanced scrolling performance optimizations
            newHostingController.view.isOpaque = true
            newHostingController.view.layer.shouldRasterize = true
            newHostingController.view.layer.rasterizationScale = UIScreen.main.scale
            newHostingController.view.layer.drawsAsynchronously = true
            newHostingController.view.tag = 200 // Tag for identification

            // Add the hosting controller's view to the chartContainerView
            chartContainerView.addSubview(newHostingController.view)
            newHostingController.didMove(toParent: self) // Finalize adding child VC

            // Set constraints for the hosting controller's view within the chartContainerView
            NSLayoutConstraint.activate([
                newHostingController.view.topAnchor.constraint(equalTo: chartContainerView.topAnchor),
                newHostingController.view.leadingAnchor.constraint(equalTo: chartContainerView.leadingAnchor),
                newHostingController.view.trailingAnchor.constraint(equalTo: chartContainerView.trailingAnchor),
                newHostingController.view.bottomAnchor.constraint(equalTo: chartContainerView.bottomAnchor)
                // Let SwiftUI content determine the height within the scroll view
            ])

            self.hostingController = newHostingController // Store reference
            print("[StepsViewController] Created and added new hosting controller.")
        }

        // Ensure the chart container is visible
        chartContainerView.isHidden = false
        
        // Apply rasterization to improve chart scrolling
        chartContainerView.layer.shouldRasterize = true
        chartContainerView.layer.rasterizationScale = UIScreen.main.scale
        chartContainerView.layer.drawsAsynchronously = true

        // Force layout update if needed
        view.layoutIfNeeded()
    }


    // MARK: - Empty State

    private func setupEmptyStateView() {
        // Create the empty state view but don't add it yet
        let emptyContainerView = UIView()
        emptyContainerView.tag = 100 // Tag to identify
        emptyContainerView.isHidden = true // Start hidden
        emptyContainerView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: UIImage(systemName: "figure.walk.circle"))
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = UIColor(named: "AccentColor") ?? .systemBlue
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "No Steps Data"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = "Start moving to track your steps or connect to Apple Health"
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let connectButton = UIButton(type: .system)
        connectButton.setTitle("Connect to Health", for: .normal)
        connectButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        connectButton.backgroundColor = UIColor(named: "AccentColor") ?? .systemBlue
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.layer.cornerRadius = 12
        connectButton.addTarget(self, action: #selector(connectToHealth), for: .touchUpInside)
        connectButton.translatesAutoresizingMaskIntoConstraints = false

        stackView.addArrangedSubview(imageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)
        stackView.addArrangedSubview(connectButton)
        emptyContainerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 100),
            imageView.widthAnchor.constraint(equalToConstant: 100),
            connectButton.heightAnchor.constraint(equalToConstant: 50),
            connectButton.widthAnchor.constraint(equalToConstant: 200),
            stackView.topAnchor.constraint(equalTo: emptyContainerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: emptyContainerView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: emptyContainerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: emptyContainerView.bottomAnchor)
        ])

        self.emptyStateView = emptyContainerView // Store reference
    }

    private func showEmptyState() {
        // Remove existing chart view if present
        if let existingHC = hostingController {
            existingHC.willMove(toParent: nil)
            existingHC.view.removeFromSuperview()
            existingHC.removeFromParent()
            hostingController = nil
            print("[StepsViewController] Removed chart view for empty state.")
        }
        chartContainerView.isHidden = true // Hide the chart container

        // Add and show the empty state view if it exists and isn't already added
        if let esv = emptyStateView, esv.superview == nil {
            chartContainerView.addSubview(esv) // Add to chartContainerView
            NSLayoutConstraint.activate([
                esv.centerXAnchor.constraint(equalTo: chartContainerView.centerXAnchor),
                esv.centerYAnchor.constraint(equalTo: chartContainerView.centerYAnchor, constant: -50), // Adjust vertical position
                esv.widthAnchor.constraint(equalTo: chartContainerView.widthAnchor, multiplier: 0.8)
            ])
            print("[StepsViewController] Added empty state view.")
        }
        emptyStateView?.isHidden = false
    }

    private func hideEmptyState() {
        emptyStateView?.isHidden = true
        // Don't remove from superview here, just hide it.
        // It will be removed implicitly if updateChartView adds the hosting controller.
        print("[StepsViewController] Hid empty state view.")
    }


    // MARK: - Data Loading

    private func loadStepsData(animated: Bool = true) {
        guard !isLoadingData else { return }
        isLoadingData = true
        print("[StepsViewController] Starting loadStepsData (animated: \(animated)) for period: \(selectedTimePeriod)")

        // Show loading indicator only for longer periods or initial load
        if selectedTimePeriod != .week || hostingController == nil {
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
                // Apply data sampling for smoother performance 
                // with very large datasets for monthly/yearly views
                let optimizedEntries: [Models.StepsEntry] = {
                    // For week view, use all entries for accuracy
                    if self.selectedTimePeriod == .week {
                        return entries
                    }
                    
                    // For month/year views, sample data for better performance
                    let maxPoints = self.selectedTimePeriod == .month ? 30 : 52
                    if entries.count <= maxPoints {
                        return entries
                    }
                    
                    // Sample data based on date range
                    let strideSize = max(1, entries.count / maxPoints)
                    var sampled: [Models.StepsEntry] = []
                    for i in stride(from: 0, to: entries.count, by: strideSize) {
                        sampled.append(entries[i])
                    }
                    // Always include the last entry
                    if let last = entries.last, sampled.last?.id != last.id {
                        sampled.append(last)
                    }
                    return sampled
                }()
                
                DispatchQueue.main.async {
                    print("[StepsViewController] Data fetch completed with \(entries.count) entries, optimized to \(optimizedEntries.count).")
                    self.isLoadingData = false
                    self.hideLoadingIndicator()
                    self.refreshControl.endRefreshing() // End refresh control here

                    // Update data
                    self.entries = optimizedEntries

                    if optimizedEntries.isEmpty {
                        // Show empty state if no data
                        print("[StepsViewController] No entries found, showing empty state.")
                        self.showEmptyState()
                    } else {
                        // Update chart with data
                        print("[StepsViewController] Updating chart view.")
                        self.updateChartView(with: optimizedEntries, animated: animated)
                        self.updateTitleForPeriod()
                    }
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
        // Ensure indicator is not already added
        guard view.viewWithTag(300) == nil else { return }

        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        activityIndicator.tag = 300
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false // Use auto layout
        view.addSubview(activityIndicator)

        // Center the indicator below the segmented control
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 80) // Adjust vertical position
        ])
        print("[StepsViewController] Showing loading indicator.")
    }


    private func hideLoadingIndicator() {
        if let indicator = view.viewWithTag(300) as? UIActivityIndicatorView {
            indicator.stopAnimating()
            indicator.removeFromSuperview()
            print("[StepsViewController] Hiding loading indicator.")
        }
    }

    // MARK: - Action Handlers

    @objc private func refreshData() {
        print("[StepsViewController] Refresh triggered.")
        loadStepsData()
    }

    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        print("[StepsViewController] Segment changed to index: \(sender.selectedSegmentIndex)")
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
        // loadStepsData is called by the didSet of selectedTimePeriod
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
            // Load current goal from UserDefaults or a default
            let currentGoal = UserDefaults.standard.integer(forKey: "steps_goal")
            textField.text = currentGoal > 0 ? "\(currentGoal)" : "10000"
        }

        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let text = alert.textFields?.first?.text,
                  let goal = Int(text) else { return }

            UserDefaults.standard.set(goal, forKey: "steps_goal")
            // Reload data to reflect new goal in chart/stats
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
        // Create a snapshot of the relevant view (e.g., the chartContainerView or just the chart)
        guard let viewToShare = hostingController?.view ?? emptyStateView else {
             print("No view available to share.")
             return
        }

        UIGraphicsBeginImageContextWithOptions(viewToShare.bounds.size, false, 0.0)
        viewToShare.drawHierarchy(in: viewToShare.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let shareImage = image else {
             print("Failed to create image for sharing.")
             return
        }

        // Create share text
        let shareText = "Check out my steps data from the MacroTracker app!"

        // Create activity view controller
        let activityVC = UIActivityViewController(
            activityItems: [shareText, shareImage],
            applicationActivities: nil
        )

        // Configure for iPad if necessary
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = self.view // Anchor to the main view
            // Position the popover appropriately, e.g., near the share button
            popoverController.barButtonItem = navigationItem.rightBarButtonItems?.last
        }

        present(activityVC, animated: true)
    }


    @objc private func connectToHealth() {
        dataManager.requestHealthKitPermissions { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.showToast(message: "Connected to Health successfully!")
                    // Reload data immediately after successful connection
                    self?.loadStepsData()
                } else {
                    self?.showToast(message: "Failed to connect to Health", isError: true)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func showToast(message: String, isError: Bool = false) {
        // Ensure toast is shown on top of everything
        guard let window = view.window else { return }

        let toastView = UIView()
        toastView.backgroundColor = isError ? UIColor.systemRed.withAlphaComponent(0.9) : UIColor.systemGreen.withAlphaComponent(0.9)
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
        label.numberOfLines = 0 // Allow multiple lines

        toastView.addSubview(label)
        window.addSubview(toastView) // Add to window

        NSLayoutConstraint.activate([
            toastView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            toastView.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -30), // Adjust position
            toastView.widthAnchor.constraint(lessThanOrEqualTo: window.widthAnchor, multiplier: 0.8),

            label.topAnchor.constraint(equalTo: toastView.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: toastView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: toastView.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: toastView.bottomAnchor, constant: -12)
        ])

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
            toastView.alpha = 1
            toastView.transform = .identity // Ensure it's at final position
        }, completion: { _ in
            UIView.animate(withDuration: 0.4, delay: 2.0, options: .curveEaseIn, animations: {
                toastView.alpha = 0
                toastView.transform = CGAffineTransform(translationX: 0, y: 20) // Animate downwards
            }, completion: { _ in
                toastView.removeFromSuperview()
            })
        })
    }

    private func setupScrollViewDelegate() {
        scrollView.delegate = self
    }

    // Add a new method for advanced scrolling optimizations
    private func setupScrollingOptimizations() {
        // Optimize the scroll view performance
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = UIScrollView.DecelerationRate.fast
        
        // Set content inset adjustment behavior for better scroll performance
        scrollView.contentInsetAdjustmentBehavior = .never
        
        // Pre-layout content for better performance
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
    }
}

// MARK: - UIScrollViewDelegate
extension StepsViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Set scrolling state to true
        isScrolling = true
        
        // Actively reduce rendering quality during scrolling
        if let hostingView = hostingController?.view {
            // More aggressive optimizations during scrolling
            hostingView.layer.shouldRasterize = true
            hostingView.layer.rasterizationScale = UIScreen.main.scale * 0.8 // Slightly reduce resolution
            
            // Reduce memory pressure during scrolling
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hostingView.alpha = 0.95
            CATransaction.commit()
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Improve scroll performance by reducing graphics during scrolling
        isScrolling = true
        
        if let hostingView = hostingController?.view {
            // Apply more aggressive optimization during scrolling
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hostingView.alpha = 0.95
            hostingView.layer.shouldRasterize = true
            hostingView.layer.rasterizationScale = UIScreen.main.scale * 0.8
            CATransaction.commit()
        }
        
        // Also optimize the chart container
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        chartContainerView.layer.shouldRasterize = true
        chartContainerView.layer.rasterizationScale = UIScreen.main.scale * 0.8
        CATransaction.commit()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            isScrolling = false
            resetGraphicQuality()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isScrolling = false
        resetGraphicQuality()
    }
    
    private func resetGraphicQuality() {
        // Only reset if scrolling has truly ended
        guard !isScrolling else { return }
        
        // Restore full graphics quality after scrolling stops
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            UIView.animate(withDuration: 0.2) {
                self.hostingController?.view.alpha = 1.0
                
                // Turn off rasterization for better quality when not scrolling
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.hostingController?.view.layer.shouldRasterize = false
                self.chartContainerView.layer.shouldRasterize = false
                self.hostingController?.view.layer.rasterizationScale = UIScreen.main.scale
                self.chartContainerView.layer.rasterizationScale = UIScreen.main.scale
                CATransaction.commit()
            }
        }
        CATransaction.commit()
    }
}
