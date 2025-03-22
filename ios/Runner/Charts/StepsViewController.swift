import UIKit
import DGCharts
import HealthKit
import Charts

class StepsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let dataManager = StatsDataManager.shared
    private var stepEntries: [StepsEntry] = []
    private let healthStore = HKHealthStore()
    private let chartView = BarChartView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupChartView()
        requestHealthKitAuthorization()
    }
    
    private func setupUI() {
        title = "Steps"
        view.backgroundColor = .systemBackground
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.axis = .vertical
        contentView.spacing = 16
        contentView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
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
        
        setupProgressCard()
        setupChartContainer()
        setupWeeklyProgress()
    }
    
    private func setupProgressCard() {
        let cardView = UIView()
        cardView.backgroundColor = .secondarySystemBackground
        cardView.layer.cornerRadius = 16
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let stepsLabel = UILabel()
        stepsLabel.text = "8,234"
        stepsLabel.font = .systemFont(ofSize: 32, weight: .bold)
        stepsLabel.textColor = .systemBlue
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "steps today"
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = .secondaryLabel
        
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progress = 0.7
        progressView.progressTintColor = .systemBlue
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        let goalLabel = UILabel()
        goalLabel.text = "Goal: 10,000 steps"
        goalLabel.font = .systemFont(ofSize: 14)
        goalLabel.textColor = .secondaryLabel
        
        stackView.addArrangedSubview(stepsLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(progressView)
        stackView.addArrangedSubview(goalLabel)
        
        cardView.addSubview(stackView)
        
        contentView.addArrangedSubview(cardView)
        
        NSLayoutConstraint.activate([
            cardView.heightAnchor.constraint(equalToConstant: 150),
            progressView.widthAnchor.constraint(equalTo: stackView.widthAnchor, multiplier: 0.8),
            stackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupChartContainer() {
        let chartContainer = UIView()
        chartContainer.backgroundColor = .secondarySystemBackground
        chartContainer.layer.cornerRadius = 16
        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        
        chartView.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(chartView)
        
        contentView.addArrangedSubview(chartContainer)
        
        NSLayoutConstraint.activate([
            chartContainer.heightAnchor.constraint(equalToConstant: 300),
            chartView.topAnchor.constraint(equalTo: chartContainer.topAnchor, constant: 16),
            chartView.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor, constant: -16),
            chartView.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupWeeklyProgress() {
        let weeklyContainer = UIView()
        weeklyContainer.backgroundColor = .secondarySystemBackground
        weeklyContainer.layer.cornerRadius = 16
        
        let titleLabel = UILabel()
        titleLabel.text = "Weekly Progress"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        weeklyContainer.addSubview(titleLabel)
        contentView.addArrangedSubview(weeklyContainer)
        
        NSLayoutConstraint.activate([
            weeklyContainer.heightAnchor.constraint(equalToConstant: 200),
            titleLabel.topAnchor.constraint(equalTo: weeklyContainer.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: weeklyContainer.leadingAnchor, constant: 16)
        ])
        
        // Add daily progress bars here
        setupDailyProgressBars(in: weeklyContainer)
    }
    
    private func setupDailyProgressBars(in container: UIView) {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 50),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        // Add progress bars for each day
        let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        days.forEach { day in
            let progress = Float.random(in: 0...1)
            stackView.addArrangedSubview(createDailyProgressBar(day: day, progress: progress))
        }
    }
    
    private func createDailyProgressBar(day: String, progress: Float) -> UIView {
        let container = UIView()
        
        let dayLabel = UILabel()
        dayLabel.text = day
        dayLabel.font = .systemFont(ofSize: 14)
        dayLabel.textColor = .secondaryLabel
        
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progress = progress
        progressView.progressTintColor = .systemBlue
        
        let stepsLabel = UILabel()
        stepsLabel.text = "\(Int(progress * 10000))"
        stepsLabel.font = .systemFont(ofSize: 14)
        stepsLabel.textColor = .secondaryLabel
        
        [dayLabel, progressView, stepsLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            dayLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dayLabel.widthAnchor.constraint(equalToConstant: 40),
            
            progressView.leadingAnchor.constraint(equalTo: dayLabel.trailingAnchor, constant: 8),
            progressView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 6),
            
            stepsLabel.leadingAnchor.constraint(equalTo: progressView.trailingAnchor, constant: 8),
            stepsLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stepsLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        return container
    }
    
    private func setupChartView() {
        chartView.rightAxis.enabled = false
        chartView.legend.enabled = false
        
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = false
        
        let leftAxis = chartView.leftAxis
        leftAxis.axisMinimum = 0
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridLineDashLengths = [4, 4]
        
        loadChartData()
    }
    
    private func loadChartData() {
        // Mock data - Replace with HealthKit data
        let entries = (0..<7).map { i -> BarChartDataEntry in
            return BarChartDataEntry(x: Double(i), y: Double.random(in: 5000...15000))
        }
        
        let dataSet = BarChartDataSet(entries: entries, label: "Steps")
        dataSet.colors = [.systemBlue]
        dataSet.drawValuesEnabled = false
        
        chartView.data = BarChartData(dataSet: dataSet)
    }
    
    private func requestHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        healthStore.requestAuthorization(toShare: [], read: [stepsType]) { success, error in
            if success {
                self.loadHealthKitData()
            }
        }
    }
    
    private func loadHealthKitData() {
        // Implement HealthKit data loading
    }
}