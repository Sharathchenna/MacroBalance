import UIKit
import DGCharts
import HealthKit

class StepsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let dataManager = StatsDataManager.shared
    private var stepEntries: [StepEntryModel] = []
    private let healthStore = HKHealthStore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        requestHealthKitPermission()
    }
    
    private func setupUI() {
        title = "Steps"
        view.backgroundColor = .systemBackground
        
        // Setup scroll view and content stack
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView.axis = .vertical
        contentView.spacing = 20
        contentView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        contentView.isLayoutMarginsRelativeArrangement = true
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
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
        
        // Add main progress ring
        let progressView = createProgressRing()
        contentView.addArrangedSubview(progressView)
        
        // Add step stats
        let statsView = createStatsView()
        contentView.addArrangedSubview(statsView)
        
        // Add activity chart
        let activityChart = createActivityChart()
        contentView.addArrangedSubview(activityChart)
    }
    
    private func createProgressRing() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        
        let ringView = CircularProgressView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        ringView.tag = 100
        ringView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(ringView)
        
        let stepsLabel = UILabel()
        stepsLabel.tag = 101
        stepsLabel.text = "0"
        stepsLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        stepsLabel.textAlignment = .center
        stepsLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stepsLabel)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "steps today"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 250),
            
            ringView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            ringView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ringView.widthAnchor.constraint(equalToConstant: 200),
            ringView.heightAnchor.constraint(equalToConstant: 200),
            
            stepsLabel.centerXAnchor.constraint(equalTo: ringView.centerXAnchor),
            stepsLabel.centerYAnchor.constraint(equalTo: ringView.centerYAnchor, constant: -10),
            
            subtitleLabel.centerXAnchor.constraint(equalTo: ringView.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: stepsLabel.bottomAnchor, constant: 4)
        ])
        
        return container
    }
    
    private func createStatsView() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        // Create stat sections
        let distanceSection = createStatSection(title: "Distance", value: "0.0", unit: "km", tag: 102)
        let caloriesSection = createStatSection(title: "Calories", value: "0", unit: "kcal", tag: 103)
        let timeSection = createStatSection(title: "Active Time", value: "0", unit: "min", tag: 104)
        
        stackView.addArrangedSubview(distanceSection)
        stackView.addArrangedSubview(caloriesSection)
        stackView.addArrangedSubview(timeSection)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 100),
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        return container
    }
    
    private func createStatSection(title: String, value: String, unit: String, tag: Int) -> UIView {
        let container = UIView()
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        let valueStack = UIStackView()
        valueStack.axis = .horizontal
        valueStack.spacing = 2
        valueStack.alignment = .firstBaseline
        
        let valueLabel = UILabel()
        valueLabel.tag = tag
        valueLabel.text = value
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        valueLabel.textColor = .label
        
        let unitLabel = UILabel()
        unitLabel.text = unit
        unitLabel.font = .systemFont(ofSize: 12, weight: .regular)
        unitLabel.textColor = .secondaryLabel
        
        valueStack.addArrangedSubview(valueLabel)
        valueStack.addArrangedSubview(unitLabel)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        
        stackView.addArrangedSubview(valueStack)
        stackView.addArrangedSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createActivityChart() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        
        let titleLabel = UILabel()
        titleLabel.text = "Today's Activity"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let chartView = BarChartView()
        chartView.tag = 105
        chartView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chartView)
        
        setupHourlyChart(chartView)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 300),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            
            chartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            chartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            chartView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        return container
    }
    
    private func setupHourlyChart(_ chartView: BarChartView) {
        chartView.rightAxis.enabled = false
        chartView.leftAxis.labelTextColor = .label
        chartView.xAxis.labelTextColor = .label
        chartView.legend.enabled = false
        
        // Sample hourly data
        let entries = (0..<24).map { hour -> BarChartDataEntry in
            return BarChartDataEntry(x: Double(hour), y: Double.random(in: 100...1000))
        }
        
        let dataSet = BarChartDataSet(entries: entries)
        dataSet.colors = [.systemBlue]
        dataSet.valueTextColor = .clear // Hide values for cleaner look
        
        chartView.data = BarChartData(dataSet: dataSet)
        
        // Configure axis
        chartView.xAxis.valueFormatter = HourAxisValueFormatter()
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.setLabelCount(6, force: true)
    }
    
    private func requestHealthKitPermission() {
        guard HKHealthStore.isHealthDataAvailable() else {
            showHealthKitError()
            return
        }
        
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        healthStore.requestAuthorization(toShare: [], read: [stepType, distanceType, activeEnergyType]) { [weak self] success, error in
            if success {
                self?.loadHealthData()
            } else {
                DispatchQueue.main.async {
                    self?.showHealthKitError()
                }
            }
        }
    }
    
    private func loadHealthData() {
        dataManager.fetchStepData { [weak self] entries in
            self?.stepEntries = entries
            DispatchQueue.main.async {
                self?.updateUI()
            }
        }
    }
    
    private func showHealthKitError() {
        let alert = UIAlertController(
            title: "Health Data Access Required",
            message: "This app needs access to your health data to track steps and activity.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func updateUI() {
        guard let latestEntry = stepEntries.first else { return }
        
        // Update progress ring
        if let ringView = view.viewWithTag(100) as? CircularProgressView {
            let progress = Float(latestEntry.steps) / Float(latestEntry.goal)
            ringView.setProgress(progress, animated: true)
        }
        
        // Update step count label
        if let stepsLabel = view.viewWithTag(101) as? UILabel {
            stepsLabel.text = "\(latestEntry.steps)"
        }
        
        // Update stats
        if let distanceLabel = view.viewWithTag(102) as? UILabel {
            distanceLabel.text = String(format: "%.1f", latestEntry.distance)
        }
        
        if let caloriesLabel = view.viewWithTag(103) as? UILabel {
            caloriesLabel.text = "\(Int(latestEntry.calories))"
        }
        
        if let timeLabel = view.viewWithTag(104) as? UILabel {
            timeLabel.text = "\(latestEntry.activeMinutes)"
        }
        
        // Update activity chart
        if let chartView = view.viewWithTag(105) as? BarChartView {
            setupHourlyChart(chartView)
        }
    }
}

class HourAxisValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let hour = Int(value) % 24
        return "\(hour):00"
    }
}