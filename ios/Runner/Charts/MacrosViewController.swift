import UIKit
import DGCharts

class MacrosViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let dataManager = StatsDataManager.shared
    private var macroEntries: [MacroEntryModel] = []
    
    // Macro goals
    private var proteinGoal: Double = 150
    private var carbsGoal: Double = 250
    private var fatGoal: Double = 65
    
    // Current macros
    private var currentProtein: Double = 0
    private var currentCarbs: Double = 0
    private var currentFat: Double = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadMacroData()
    }
    
    private func setupUI() {
        title = "Macros"
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
        
        // Add pie chart view
        let pieChartView = createPieChartView()
        pieChartView.tag = 100
        contentView.addArrangedSubview(pieChartView)
        
        // Add macro progress bars
        let progressView = createMacroProgressView()
        contentView.addArrangedSubview(progressView)
        
        // Add daily distribution chart
        let distributionChart = createDistributionChart()
        distributionChart.tag = 104
        contentView.addArrangedSubview(distributionChart)
    }
    
    private func createPieChartView() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        
        let titleLabel = UILabel()
        titleLabel.text = "Macro Distribution"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let chartView = PieChartView()
        chartView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chartView)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 300),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            
            chartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            chartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            chartView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        // Configure pie chart
        setupPieChart(chartView)
        
        return container
    }
    
    private func createMacroProgressView() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        // Add progress bars for each macro
        let proteinProgress = createMacroProgressBar(
            title: "Protein",
            current: currentProtein,
            goal: proteinGoal,
            color: .systemRed
        )
        proteinProgress.tag = 101
        
        let carbsProgress = createMacroProgressBar(
            title: "Carbs",
            current: currentCarbs,
            goal: carbsGoal,
            color: .systemBlue
        )
        carbsProgress.tag = 102
        
        let fatProgress = createMacroProgressBar(
            title: "Fat",
            current: currentFat,
            goal: fatGoal,
            color: .systemYellow
        )
        fatProgress.tag = 103
        
        stackView.addArrangedSubview(proteinProgress)
        stackView.addArrangedSubview(carbsProgress)
        stackView.addArrangedSubview(fatProgress)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 200),
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        return container
    }
    
    private func createMacroProgressBar(title: String, current: Double, goal: Double, color: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let progressView = UIProgressView(progressViewStyle: .bar)
        progressView.trackTintColor = color.withAlphaComponent(0.2)
        progressView.progressTintColor = color
        progressView.progress = Float(current / goal)
        progressView.layer.cornerRadius = 3
        progressView.clipsToBounds = true
        progressView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(progressView)
        
        let valueLabel = UILabel()
        valueLabel.text = "\(Int(current))g / \(Int(goal))g"
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valueLabel.textColor = .secondaryLabel
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 50),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            valueLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            progressView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 6)
        ])
        
        return container
    }
    
    private func createDistributionChart() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        
        let titleLabel = UILabel()
        titleLabel.text = "Weekly Distribution"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let chartView = LineChartView()
        chartView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chartView)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 300),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            
            chartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            chartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            chartView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        setupDistributionChart(chartView)
        
        return container
    }
    
    private func setupPieChart(_ chartView: PieChartView) {
        let totalMacros = currentProtein + currentCarbs + currentFat
        
        let entries = [
            PieChartDataEntry(value: (currentProtein / totalMacros) * 100, label: "Protein"),
            PieChartDataEntry(value: (currentCarbs / totalMacros) * 100, label: "Carbs"),
            PieChartDataEntry(value: (currentFat / totalMacros) * 100, label: "Fat")
        ]
        
        let dataSet = PieChartDataSet(entries: entries)
        dataSet.colors = [.systemRed, .systemBlue, .systemYellow]
        dataSet.valueTextColor = .label
        dataSet.valueFont = .systemFont(ofSize: 12)
        
        chartView.data = PieChartData(dataSet: dataSet)
        chartView.legend.horizontalAlignment = .center
        chartView.legend.verticalAlignment = .bottom
    }
    
    private func setupDistributionChart(_ chartView: LineChartView) {
        // Configure chart appearance
        chartView.rightAxis.enabled = false
        chartView.leftAxis.labelTextColor = .label
        chartView.xAxis.labelTextColor = .label
        chartView.legend.textColor = .label
        
        // Sample weekly data
        let days = 7
        let proteinEntries = (0..<days).map { day -> ChartDataEntry in
            return ChartDataEntry(x: Double(day), y: Double.random(in: 120...180))
        }
        
        let carbsEntries = (0..<days).map { day -> ChartDataEntry in
            return ChartDataEntry(x: Double(day), y: Double.random(in: 200...300))
        }
        
        let fatEntries = (0..<days).map { day -> ChartDataEntry in
            return ChartDataEntry(x: Double(day), y: Double.random(in: 50...80))
        }
        
        let proteinSet = LineChartDataSet(entries: proteinEntries, label: "Protein")
        proteinSet.colors = [.systemRed]
        proteinSet.circleColors = [.systemRed]
        
        let carbsSet = LineChartDataSet(entries: carbsEntries, label: "Carbs")
        carbsSet.colors = [.systemBlue]
        carbsSet.circleColors = [.systemBlue]
        
        let fatSet = LineChartDataSet(entries: fatEntries, label: "Fat")
        fatSet.colors = [.systemYellow]
        fatSet.circleColors = [.systemYellow]
        
        let data = LineChartData(dataSets: [proteinSet, carbsSet, fatSet])
        chartView.data = data
    }
    
    private func loadMacroData() {
        dataManager.fetchMacroData { [weak self] entries in
            self?.macroEntries = entries
            
            DispatchQueue.main.async {
                self?.updateUI()
            }
        }
    }
    
    private func updateUI() {
        guard let latestEntry = macroEntries.first else { return }
        
        // Update pie chart
        if let chartView = view.viewWithTag(100) as? PieChartView {
            let totalMacros = latestEntry.protein + latestEntry.carbs + latestEntry.fat
            
            let entries = [
                PieChartDataEntry(
                    value: (latestEntry.protein / totalMacros) * 100,
                    label: "Protein"
                ),
                PieChartDataEntry(
                    value: (latestEntry.carbs / totalMacros) * 100,
                    label: "Carbs"
                ),
                PieChartDataEntry(
                    value: (latestEntry.fat / totalMacros) * 100,
                    label: "Fat"
                )
            ]
            
            let dataSet = PieChartDataSet(entries: entries)
            dataSet.colors = [.systemRed, .systemBlue, .systemYellow]
            dataSet.valueTextColor = .label
            dataSet.valueFont = .systemFont(ofSize: 12)
            
            chartView.data = PieChartData(dataSet: dataSet)
            chartView.notifyDataSetChanged()
        }
        
        // Update progress bars
        updateProgressBar(
            tag: 101,
            current: latestEntry.protein,
            goal: latestEntry.proteinGoal
        )
        
        updateProgressBar(
            tag: 102,
            current: latestEntry.carbs,
            goal: latestEntry.carbsGoal
        )
        
        updateProgressBar(
            tag: 103,
            current: latestEntry.fat,
            goal: latestEntry.fatGoal
        )
        
        // Update distribution chart
        if let chartView = view.viewWithTag(104) as? LineChartView {
            setupDistributionChart(chartView)
        }
    }
    
    private func updateProgressBar(tag: Int, current: Double, goal: Double) {
        if let progressView = view.viewWithTag(tag) as? UIProgressView {
            progressView.progress = Float(current / goal)
        }
        
        if let valueLabel = view.viewWithTag(tag + 1000) as? UILabel {
            valueLabel.text = "\(Int(current))g / \(Int(goal))g"
        }
    }
}