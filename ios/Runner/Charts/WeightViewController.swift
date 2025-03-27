import UIKit
import SwiftUI
import DGCharts
import Charts

// MARK: - Weight View Controller
final class WeightViewController: UIViewController {
    // MARK: - Private Properties
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private var entries: [Models.WeightEntry] = []
    private let dataManager = StatsDataManager.shared
    private var weightUnit: String = "kg"
    private lazy var chartView = LineChartView()
    private var goalWeight: Double = 0
    private var timeSegmentControl: UISegmentedControl!
    private let dateFormatter = DateFormatter()
    
    // Cache values to avoid recalculations
    private var lastChartPeriod: ChartPeriod = .week
    private var cachedTrendLineEntries: [ChartDataEntry]?
    
    // Define chart period options
    private enum ChartPeriod: Int {
        case week = 0
        case month = 1
        case threeMonths = 2
        case year = 3
    }
    
    private var currentPeriod: ChartPeriod = .week
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        configureDefaults()
        setupUI()
        loadWeightData()
    }
    
    // MARK: - Private Methods
    
    private func configureDefaults() {
        loadWeightUnit()
        loadGoalWeight()
        
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
    }
    
    private func setupUI() {
        title = "Weight"
        view.backgroundColor = .systemBackground
        
        // Add button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addWeightEntry)
        )
        
        setupScrollView()
        setupContentView()
        setupTimeSegmentControl()
        setupStatsView()
        setupChartContainer()
        setupChartView()
        setupInsightsView()
        setupWeightEntryButton()
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupContentView() {
        contentView.axis = .vertical
        contentView.spacing = 20
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }
    
    private func setupTimeSegmentControl() {
        timeSegmentControl = UISegmentedControl(items: ["Week", "Month", "3 Months", "Year"])
        timeSegmentControl.selectedSegmentIndex = 0
        timeSegmentControl.addTarget(self, action: #selector(timeSegmentChanged), for: .valueChanged)
        
        contentView.addArrangedSubview(timeSegmentControl)
    }
    
    private func setupStatsView() {
        let statsContainer = UIStackView()
        statsContainer.axis = .horizontal
        statsContainer.distribution = .fillEqually
        statsContainer.spacing = 12
        
        // Add stat cards - these will be updated when data loads
        statsContainer.addArrangedSubview(createStatCard(title: "Current", value: "--", change: nil, tag: 201))
        statsContainer.addArrangedSubview(createStatCard(title: "Change", value: "--", change: nil, tag: 202))
        statsContainer.addArrangedSubview(createStatCard(title: "Goal", value: "--", change: nil, tag: 203))
        
        contentView.addArrangedSubview(statsContainer)
    }
    
    private func createStatCard(title: String, value: String, change: Change?, tag: Int) -> UIView {
        let card = UIView()
        card.tag = tag
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        
        let valueLabel = UILabel()
        valueLabel.tag = tag + 1000 // Tag to reference later
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 18, weight: .bold)
        valueLabel.textColor = change?.color ?? .label
        
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(valueLabel)
        
        if let change = change {
            let directionImage = UIImageView()
            directionImage.image = UIImage(systemName: change == .positive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
            directionImage.tintColor = change.color
            directionImage.contentMode = .scaleAspectFit
            directionImage.heightAnchor.constraint(equalToConstant: 16).isActive = true
            directionImage.widthAnchor.constraint(equalToConstant: 16).isActive = true
            
            let directionStack = UIStackView()
            directionStack.axis = .horizontal
            directionStack.spacing = 4
            directionStack.alignment = .center
            directionStack.addArrangedSubview(directionImage)
            directionStack.addArrangedSubview(valueLabel)
            
            stack.addArrangedSubview(titleLabel)
            stack.addArrangedSubview(directionStack)
        } else {
            stack.addArrangedSubview(titleLabel)
            stack.addArrangedSubview(valueLabel)
        }
        
        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 80),
            stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        
        return card
    }
    
    private func setupChartContainer() {
        let chartContainer = UIView()
        chartContainer.backgroundColor = .secondarySystemBackground
        chartContainer.layer.cornerRadius = 16
        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        
        chartView.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(chartView)
        
        contentView.addArrangedSubview(chartContainer)
        
        // Add chart title
        let titleLabel = UILabel()
        titleLabel.text = "Weight Tracking"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            chartContainer.heightAnchor.constraint(equalToConstant: 340),
            titleLabel.topAnchor.constraint(equalTo: chartContainer.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: 16),
            
            chartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            chartView.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor, constant: -16),
            chartView.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupInsightsView() {
        let insightsContainer = UIView()
        insightsContainer.backgroundColor = .secondarySystemBackground
        insightsContainer.layer.cornerRadius = 16
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Insights"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        
        // Weekly trend
        let trendView = createInsightRow(icon: "chart.line.uptrend.xyaxis", 
                                         title: "Trend", 
                                         value: "Calculating...",
                                         tag: 301)
        
        // Average weekly change
        let avgChangeView = createInsightRow(icon: "arrow.up.arrow.down", 
                                            title: "Weekly avg", 
                                            value: "Calculating...",
                                            tag: 302)
        
        // Projected timeline
        let projectionView = createInsightRow(icon: "calendar", 
                                             title: "Goal projection", 
                                             value: "Calculating...",
                                             tag: 303)
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(trendView)
        stackView.addArrangedSubview(avgChangeView)
        stackView.addArrangedSubview(projectionView)
        
        insightsContainer.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: insightsContainer.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: insightsContainer.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: insightsContainer.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: insightsContainer.bottomAnchor, constant: -16)
        ])
        
        contentView.addArrangedSubview(insightsContainer)
    }
    
    private func createInsightRow(icon: String, title: String, value: String, tag: Int) -> UIView {
        let container = UIView()
        
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let valueLabel = UILabel()
        valueLabel.tag = tag // Tag for updating later
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 15, weight: .medium)
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(iconView)
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 32),
            
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12)
        ])
        
        return container
    }
    
    private func setupWeightEntryButton() {
        let button = UIButton(type: .system)
        button.setTitle("Log Weight", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        
        contentView.addArrangedSubview(button)
        
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        button.addTarget(self, action: #selector(showWeightEntry), for: .touchUpInside)
    }
    
    private func setupChartView() {
        // Configure base chart settings
        chartView.noDataText = "Loading..."
        chartView.drawGridBackgroundEnabled = false
        chartView.chartDescription.enabled = false
        
        // Optimize chart rendering
        chartView.dragEnabled = true
        chartView.setScaleEnabled(true)
        chartView.pinchZoomEnabled = true
        chartView.doubleTapToZoomEnabled = false  // Disable to prevent unnecessary redraws
        chartView.highlightPerTapEnabled = true   // Only highlight on tap, not drag
        chartView.highlightPerDragEnabled = false // Disable drag highlighting for better performance
        
        // Reduce memory usage with viewport limiting
        chartView.maxVisibleCount = 60
        chartView.autoScaleMinMaxEnabled = true // Automatically adjust Y axis
        
        // Use hardware acceleration for better performance
        chartView.layer.shouldRasterize = true
        chartView.layer.rasterizationScale = UIScreen.main.scale
        
        // Configure axes
        configureChartAxes()
        
        // Enable marker for data point details on tap
        let marker = BalloonMarker(color: .systemBlue,
                                  font: .systemFont(ofSize: 12),
                                  textColor: .white,
                                  insets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
        marker.chartView = chartView
        marker.minimumSize = CGSize(width: 80, height: 40)
        chartView.marker = marker
    }
    
    private func configureChartAxes() {
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = false
        xAxis.labelFont = .systemFont(ofSize: 10)
        xAxis.labelTextColor = .secondaryLabel
        xAxis.granularity = 1
        xAxis.valueFormatter = DateValueFormatter()
        
        let leftAxis = chartView.leftAxis
        leftAxis.labelFont = .systemFont(ofSize: 10)
        leftAxis.labelTextColor = .secondaryLabel
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridLineDashLengths = [4, 4]
        leftAxis.axisLineColor = .tertiaryLabel
        leftAxis.granularity = 1
        
        // Disable right axis for better performance
        chartView.rightAxis.enabled = false
    }
    
    @objc private func timeSegmentChanged() {
        let newPeriod = ChartPeriod(rawValue: timeSegmentControl.selectedSegmentIndex) ?? .week
        if currentPeriod != newPeriod {
            // Only reload if the period actually changed
            currentPeriod = newPeriod
            
            // Clear cache when period changes
            cachedTrendLineEntries = nil
            
            // Reload data with new period
            loadWeightData()
        }
    }
    
    private func loadWeightData() {
        // Move data fetching to background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.dataManager.fetchWeightData { [weak self] entries in
                guard let self = self else { return }
                
                // Process data in background
                var sortedEntries = entries.sorted { $0.date < $1.date }
                
                // If no entries exist, check if we have onboarding weight data
                if sortedEntries.isEmpty {
                    if let onboardingEntry = self.getOnboardingWeightEntry() {
                        sortedEntries.append(onboardingEntry)
                        
                        // Save this entry for future use
                        self.dataManager.saveWeightEntry(onboardingEntry) { success in
                            print("Onboarding weight saved: \(success)")
                        }
                    }
                }
                
                // Filter entries based on time period
                let filteredEntries = self.filterEntriesByPeriod(sortedEntries, period: self.currentPeriod)
                
                // Update UI on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.entries = filteredEntries
                    self.updateUI()
                    self.updateInsights()
                }
            }
        }
    }
    
    private func filterEntriesByPeriod(_ entries: [Models.WeightEntry], period: ChartPeriod) -> [Models.WeightEntry] {
        guard !entries.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch period {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .threeMonths:
            startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        return entries.filter { $0.date >= startDate }
    }
    
    private func getOnboardingWeightEntry() -> Models.WeightEntry? {
        // Try to get the weight from onboarding results saved in UserDefaults
        guard let resultsData = UserDefaults.standard.string(forKey: "macro_results"),
              let data = resultsData.data(using: .utf8) else {
            return nil
        }
        
        do {
            guard let results = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let weightKg = results["weight_kg"] as? Double else {
                return nil
            }
            
            // Create a weight entry with the onboarding weight
            // Use current date as we're creating a starting point
            return Models.WeightEntry(
                date: Date(),
                weight: weightKg,
                unit: weightUnit
            )
        } catch {
            print("Error parsing onboarding data: \(error)")
            return nil
        }
    }
    
    private func loadWeightUnit() {
        // Load weight unit from UserDefaults
        if let unit = UserDefaults.standard.string(forKey: "weight_unit"),
           (unit == "kg" || unit == "lbs") {
            weightUnit = unit
        }
    }
    
    private func loadGoalWeight() {
        // Try to load goal weight from UserDefaults
        goalWeight = UserDefaults.standard.double(forKey: "goal_weight")
        if goalWeight == 0 {
            // Try to get goal weight from onboarding data
            if let goalWeightFromOnboarding = getGoalWeightFromOnboarding() {
                goalWeight = goalWeightFromOnboarding
                UserDefaults.standard.set(goalWeight, forKey: "goal_weight")
            }
            // If still no goal weight, set a default based on current weight if available
            else if let lastWeight = entries.last?.weight {
                // Default goal is 10% less than current weight
                goalWeight = lastWeight * 0.9
                UserDefaults.standard.set(goalWeight, forKey: "goal_weight")
            }
        }
    }
    
    private func getGoalWeightFromOnboarding() -> Double? {
        // Try to get the goal weight from onboarding results
        guard let resultsData = UserDefaults.standard.string(forKey: "macro_results"),
              let data = resultsData.data(using: .utf8) else {
            return nil
        }
        
        do {
            guard let results = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let goalWeightKg = results["goal_weight_kg"] as? Double else {
                return nil
            }
            
            return goalWeightKg
        } catch {
            print("Error parsing onboarding data: \(error)")
            return nil
        }
    }
    
    @objc private func addWeightEntry() {
        let alert = UIAlertController(
            title: "Add Weight",
            message: "Enter your weight in \(weightUnit)",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.keyboardType = .decimalPad
            textField.placeholder = "Weight in \(self.weightUnit)"
        }
        
        let addAction = UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self,
                  let weightText = alert.textFields?.first?.text,
                  let weight = Double(weightText) else { return }
            
            let entry = Models.WeightEntry(date: Date(), weight: weight, unit: self.weightUnit)
            self.dataManager.saveWeightEntry(entry) { [weak self] success in
                if success {
                    self?.loadWeightData()
                }
            }
        }
        
        alert.addAction(addAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func updateUI() {
        guard !entries.isEmpty else { return }
        
        // Batch all UI updates together
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        updateStats()
        updateChart(with: entries)
        
        CATransaction.commit()
    }
    
    private func updateStats() {
        guard !entries.isEmpty else { return }
        
        // Sort entries by date
        let sortedEntries = entries.sorted { $0.date < $1.date }
        
        // Update stats
        let firstWeight = sortedEntries.first?.weight ?? 0
        let currentWeight = sortedEntries.last?.weight ?? 0
        let change = currentWeight - firstWeight
        let changeType: Change = change < 0 ? .negative : .positive
        
        // Update stat cards using a utility method to avoid code duplication
        updateStatCardLabel(tag: 1201, text: "\(String(format: "%.1f", currentWeight)) \(weightUnit)")
        
        // Format change with sign and color
        let prefix = change < 0 ? "" : "+"
        let changeText = "\(prefix)\(String(format: "%.1f", change)) \(weightUnit)"
        updateStatCardLabel(tag: 1202, text: changeText, color: change < 0 ? .systemGreen : .systemRed)
        
        // Goal weight
        updateStatCardLabel(tag: 1203, text: "\(String(format: "%.1f", goalWeight)) \(weightUnit)")
    }
    
    private func updateStatCardLabel(tag: Int, text: String, color: UIColor? = nil) {
        if let label = view.viewWithTag(tag) as? UILabel {
            label.text = text
            if let color = color {
                label.textColor = color
            }
        }
    }
    
    private func updateChart(with entries: [Models.WeightEntry]) {
        // Avoid unnecessary chart updates
        guard !entries.isEmpty else {
            chartView.data = nil
            chartView.notifyDataSetChanged()
            return
        }
        
        // Process chart data in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Convert entries to chart data points
            let dataPoints = entries.map { entry -> ChartDataEntry in
                ChartDataEntry(x: entry.date.timeIntervalSince1970, y: entry.weight)
            }
            
            // Create and configure weight dataset
            let weightDataSet = LineChartDataSet(entries: dataPoints, label: "Weight")
            self.configureDataSet(weightDataSet, color: .systemBlue, fillColor: UIColor.systemBlue.withAlphaComponent(0.2))
            
            var dataSets: [ChartDataSetProtocol] = [weightDataSet]
            
            // Add goal line if needed
            if self.goalWeight > 0 {
                let goalEntries = entries.map { entry -> ChartDataEntry in
                    ChartDataEntry(x: entry.date.timeIntervalSince1970, y: self.goalWeight)
                }
                let goalDataSet = LineChartDataSet(entries: goalEntries, label: "Goal")
                self.configureGoalDataSet(goalDataSet)
                dataSets.append(goalDataSet)
            }
            
            // Calculate trend line in background or use cached values
            if entries.count >= 3 {
                let trendEntries: [ChartDataEntry]
                
                // Check if we can use cached trend line data
                if let cached = self.cachedTrendLineEntries, 
                   self.lastChartPeriod == self.currentPeriod {
                    trendEntries = cached
                } else {
                    trendEntries = self.calculateTrendLine(for: entries)
                    self.cachedTrendLineEntries = trendEntries
                    self.lastChartPeriod = self.currentPeriod
                }
                
                let trendDataSet = LineChartDataSet(entries: trendEntries, label: "Trend")
                self.configureDataSet(trendDataSet, color: .systemGreen, fillColor: .clear, lineStyle: [[8.0, 4.0]])
                dataSets.append(trendDataSet)
            }
            
            // Update chart on main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let chartData = LineChartData(dataSets: dataSets)
                chartData.setDrawValues(false) // Disable value drawing for better performance
                
                // Batch update chart and animations
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.3)
                
                self.chartView.data = chartData
                self.chartView.notifyDataSetChanged()
                
                CATransaction.commit()
            }
        }
    }
    
    private func configureDataSet(_ dataSet: LineChartDataSet, color: UIColor, fillColor: UIColor, lineStyle: [[CGFloat]] = []) {
        // Basic configuration
        dataSet.mode = .cubicBezier
        dataSet.drawCirclesEnabled = true
        dataSet.circleRadius = 4
        dataSet.circleColors = [color]
        dataSet.circleHoleColor = .systemBackground
        dataSet.colors = [color]
        
        // Performance optimizations
        dataSet.drawValuesEnabled = false
        
        if !lineStyle.isEmpty {
            dataSet.lineDashLengths = lineStyle[0]
            dataSet.lineWidth = 1.5
            dataSet.drawCirclesEnabled = false
        } else {
            dataSet.lineWidth = 2.5
        }
        
        if fillColor != .clear {
            dataSet.drawFilledEnabled = true
            dataSet.fillColor = fillColor
            dataSet.fillAlpha = 0.7
            
            let gradientColors = [color.cgColor, UIColor.clear.cgColor] as CFArray
            let colorLocations: [CGFloat] = [1.0, 0.0]
            
            if let gradient = CGGradient(colorsSpace: nil, colors: gradientColors, locations: colorLocations) {
                dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
            }
        }
    }
    
    private func configureGoalDataSet(_ dataSet: LineChartDataSet) {
        dataSet.mode = .linear
        dataSet.drawCirclesEnabled = false
        dataSet.colors = [.systemOrange]
        dataSet.lineWidth = 1.5
        dataSet.lineDashLengths = [4, 4]
        dataSet.drawValuesEnabled = false
        dataSet.highlightEnabled = false
    }
    
    private func calculateTrendLine(for entries: [Models.WeightEntry]) -> [ChartDataEntry] {
        // Early return if not enough data
        guard entries.count >= 3 else { return [] }
        
        // Simple linear regression calculation
        let count = Double(entries.count)
        
        // X values will be days since first entry for simplicity
        let startDate = entries.first!.date
        let xValues = entries.map { $0.date.timeIntervalSince(startDate) / (60 * 60 * 24) }
        let yValues = entries.map { $0.weight }
        
        // Pre-allocate variables to avoid repeated allocation
        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumX2: Double = 0
        
        // Calculate in a single pass
        for i in 0..<entries.count {
            let x = xValues[i]
            let y = yValues[i]
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }
        
        // Calculate slope and y-intercept for line equation: y = mx + b
        let denominator = count * sumX2 - sumX * sumX
        // Avoid division by zero
        guard denominator != 0 else { return [] }
        
        let slope = (count * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / count
        
        // Create trend line data points
        // Optimize by only creating points for first, last, and a few points in between
        // This reduces the number of objects created while still showing an accurate trend line
        let resultCount = min(entries.count, 10) // Use at most 10 points for the trend line
        let step = max(1, entries.count / resultCount)
        
        var result: [ChartDataEntry] = []
        result.reserveCapacity(resultCount)
        
        for i in stride(from: 0, to: entries.count, by: step) {
            let entry = entries[i]
            let days = entry.date.timeIntervalSince(startDate) / (60 * 60 * 24)
            let trendValue = slope * days + intercept
            result.append(ChartDataEntry(x: entry.date.timeIntervalSince1970, y: trendValue))
        }
        
        // Ensure the last point is always included
        if let lastEntry = entries.last, 
           (result.isEmpty || result.last?.x != lastEntry.date.timeIntervalSince1970) {
            let days = lastEntry.date.timeIntervalSince(startDate) / (60 * 60 * 24)
            let trendValue = slope * days + intercept
            result.append(ChartDataEntry(x: lastEntry.date.timeIntervalSince1970, y: trendValue))
        }
        
        return result
    }
    
    private func updateInsights() {
        // Move calculations to background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, self.entries.count >= 2 else {
                DispatchQueue.main.async {
                    self?.updateInsightLabels(trend: "Not enough data", 
                                          weeklyChange: "Need more entries", 
                                          projection: "Add more data")
                }
                return
            }
            
            // Sort entries by date
            let sortedEntries = self.entries.sorted { $0.date < $1.date }
            
            // Calculate trend direction
            let firstWeight = sortedEntries.first!.weight
            let currentWeight = sortedEntries.last!.weight
            let totalChange = currentWeight - firstWeight
            
            // Calculate weekly average change
            let firstDate = sortedEntries.first!.date
            let lastDate = sortedEntries.last!.date
            let totalDays = max(1.0, lastDate.timeIntervalSince(firstDate) / (60 * 60 * 24))
            let weeklyChange = (totalChange / totalDays) * 7
            
            // Determine trend text
            let trendText: String
            if abs(totalChange) < 0.5 {
                trendText = "Maintaining"
            } else if totalChange < 0 {
                trendText = "Losing weight"
            } else {
                trendText = "Gaining weight"
            }
            
            // Format weekly change text
            let weeklyChangeText = String(format: "%.1f %@/week", abs(weeklyChange), self.weightUnit)
            
            // Calculate goal projection
            let projectionText: String
            if self.goalWeight > 0 && abs(weeklyChange) > 0.1 {
                let remainingChange = self.goalWeight - currentWeight
                
                // Only show projection if moving toward goal
                if (remainingChange < 0 && weeklyChange < 0) || (remainingChange > 0 && weeklyChange > 0) {
                    let weeksToGoal = abs(remainingChange / weeklyChange)
                    let goalDate = Date().addingTimeInterval(weeksToGoal * 7 * 24 * 60 * 60)
                    projectionText = self.dateFormatter.string(from: goalDate)
                } else {
                    projectionText = "Moving away from goal"
                }
            } else {
                projectionText = "Set a goal weight"
            }
            
            // Update insight labels on main thread
            DispatchQueue.main.async {
                self.updateInsightLabels(trend: trendText, weeklyChange: weeklyChangeText, projection: projectionText)
            }
        }
    }
    
    private func updateInsightLabels(trend: String, weeklyChange: String, projection: String) {
        updateLabelText(tag: 301, text: trend)
        updateLabelText(tag: 302, text: weeklyChange)
        updateLabelText(tag: 303, text: projection)
    }
    
    private func updateLabelText(tag: Int, text: String) {
        if let label = view.viewWithTag(tag) as? UILabel {
            label.text = text
        }
    }
    
    @objc private func showWeightEntry() {
        let alert = UIAlertController(title: "Log Weight", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Weight in \(self.weightUnit)"
            textField.keyboardType = .decimalPad
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            if let text = alert.textFields?.first?.text,
               let weight = Double(text) {
                // Save weight
                self?.handleWeightEntry(weight)
            }
        })
        
        present(alert, animated: true)
    }
    
    private func handleWeightEntry(_ weight: Double) {
        // Create a new weight entry and save it
        let entry = Models.WeightEntry(date: Date(), weight: weight, unit: weightUnit)
        
        // Show activity indicator while saving
        let loadingView = UIActivityIndicatorView(style: .medium)
        loadingView.startAnimating()
        loadingView.center = view.center
        view.addSubview(loadingView)
        
        dataManager.saveWeightEntry(entry) { [weak self, weak loadingView] success in
            DispatchQueue.main.async {
                loadingView?.removeFromSuperview()
                
                if success {
                    self?.loadWeightData()
                    
                    // Show a success toast
                    self?.showToast(message: "Weight saved successfully")
                } else {
                    // Show error toast
                    self?.showToast(message: "Failed to save weight")
                }
            }
        }
    }
    
    private func showToast(message: String) {
        // Reuse existing toast if possible
        if let existingToast = view.viewWithTag(999) as? UILabel {
            existingToast.text = message
            
            // Reset any ongoing animations
            existingToast.layer.removeAllAnimations()
            existingToast.alpha = 0
            
            // Animate again
            animateToast(existingToast)
            return
        }
        
        // Create new toast if none exists
        let toastLabel = UILabel()
        toastLabel.tag = 999 // Tag for reuse
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toastLabel.textColor = .white
        toastLabel.font = .systemFont(ofSize: 14)
        toastLabel.textAlignment = .center
        toastLabel.text = message
        toastLabel.alpha = 0
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toastLabel)
        
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            toastLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            toastLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        animateToast(toastLabel)
    }
    
    private func animateToast(_ toastLabel: UILabel) {
        UIView.animate(withDuration: 0.3, animations: {
            toastLabel.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: {
                toastLabel.alpha = 0
            }, completion: nil)
        })
    }
}

// MARK: - Supporting Types

/// Represents the direction of weight change
enum Change {
    case positive
    case negative
    
    var color: UIColor {
        switch self {
        case .positive:
            return .systemRed       // Weight gain (typically shown in red)
        case .negative:
            return .systemGreen     // Weight loss (typically shown in green)
        }
    }
}

/// Formats chart x-axis values as dates
final class DateValueFormatter: NSObject, AxisValueFormatter {
    private let dateFormatter = DateFormatter()
    
    override init() {
        super.init()
        dateFormatter.dateFormat = "MMM d"
    }
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let date = Date(timeIntervalSince1970: value)
        return dateFormatter.string(from: date)
    }
}

/// Custom marker view for displaying chart data points
final class BalloonMarker: MarkerImage {
    // MARK: - Properties
    var color: UIColor
    var font: UIFont
    var textColor: UIColor
    var insets: UIEdgeInsets
    var minimumSize = CGSize()
    
    private var label: String?
    private var _labelSize: CGSize = CGSize()
    
    // MARK: - Initialization
    init(color: UIColor, font: UIFont, textColor: UIColor, insets: UIEdgeInsets) {
        self.color = color
        self.font = font
        self.textColor = textColor
        self.insets = insets
        super.init()
    }
    
    // MARK: - Drawing
    override func offsetForDrawing(atPoint point: CGPoint) -> CGPoint {
        var offset = CGPoint(x: -size.width / 2.0, y: -size.height)
        offset.x = max(offset.x, 0)
        offset.y = max(offset.y, 0)
        return offset
    }
    
    override func draw(context: CGContext, point: CGPoint) {
        guard let label = label else { return }
        
        // Draw the marker background
        let rect = CGRect(
            x: point.x + offset.x,
            y: point.y + offset.y,
            width: size.width,
            height: size.height
        )
        
        context.setFillColor(color.cgColor)
        
        // More efficient path drawing
        context.saveGState()
        
        // Create rounded rect path
        let path = CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil)
        context.addPath(path)
        context.closePath()
        context.fillPath()
        
        context.restoreGState()
        
        // Draw text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        label.draw(
            in: CGRect(
                x: rect.origin.x + insets.left,
                y: rect.origin.y + insets.top,
                width: _labelSize.width,
                height: _labelSize.height
            ),
            withAttributes: attributes
        )
    }
    
    override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        // Format the display text
        let date = Date(timeIntervalSince1970: entry.x)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        
        label = "\(dateFormatter.string(from: date))\n\(String(format: "%.1f", entry.y))"
        _labelSize = label?.size(withAttributes: [.font: font]) ?? CGSize.zero
        _labelSize.width += insets.left + insets.right
        _labelSize.height += insets.top + insets.bottom
        _labelSize.width = max(minimumSize.width, _labelSize.width)
        _labelSize.height = max(minimumSize.height, _labelSize.height)
        
        size = _labelSize
    }
}