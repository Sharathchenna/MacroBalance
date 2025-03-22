import UIKit
import SwiftUI
import DGCharts
import Charts

class WeightViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private var weightEntries: [WeightEntry] = []
    private let dataManager = StatsDataManager.shared
    private var weightUnit: String = "kg"
    private let chartView = LineChartView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadWeightData()
        loadWeightUnit()
        setupChartView()
        loadData()
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
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Setup content stack view
        contentView.axis = .vertical
        contentView.spacing = 20
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
        
        // Add weight stats view
        let statsView = createWeightStatsView()
        contentView.addArrangedSubview(statsView)
        
        // Add chart view
        let chartView = createWeightChartView()
        contentView.addArrangedSubview(chartView)
        
        setupChartContainer()
        setupStatsView()
        setupWeightEntryButton()
    }
    
    private func createWeightStatsView() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        
        // Add stats UI elements here
        let startWeight = UILabel()
        startWeight.text = "Starting Weight: --"
        startWeight.tag = 100
        
        let currentWeight = UILabel()
        currentWeight.text = "Current Weight: --"
        currentWeight.tag = 101
        
        let weightChange = UILabel()
        weightChange.text = "Change: --"
        weightChange.tag = 102
        
        let stackView = UIStackView(arrangedSubviews: [startWeight, currentWeight, weightChange])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 120),
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])
        
        return container
    }
    
    private func createWeightChartView() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        
        let chartView = LineChartView()
        chartView.tag = 200
        chartView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chartView)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 300),
            chartView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            chartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            chartView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        setupWeightChart(chartView)
        return container
    }
    
    private func setupWeightChart(_ chartView: LineChartView) {
        // Configure chart appearance
        chartView.rightAxis.enabled = false
        chartView.leftAxis.labelTextColor = .label
        chartView.xAxis.labelTextColor = .label
        chartView.legend.enabled = false
        
        // Data will be updated in updateUI()
    }
    
    private func loadWeightData() {
        dataManager.fetchWeightData { [weak self] entries in
            self?.weightEntries = entries
            DispatchQueue.main.async {
                self?.updateUI()
            }
        }
    }
    
    private func loadWeightUnit() {
        // Load weight unit from UserDefaults
        if let unit = UserDefaults.standard.string(forKey: "weight_unit"),
           (unit == "kg" || unit == "lbs") {
            weightUnit = unit
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
            guard let weightText = alert.textFields?.first?.text,
                  let weight = Double(weightText) else { return }
            
            let entry = WeightEntry(date: Date(), weight: weight)
            self?.dataManager.saveWeightEntry(entry) { success in
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
        // Update stats
        if let startWeight = view.viewWithTag(100) as? UILabel {
            startWeight.text = "Starting Weight: \(weightEntries.first?.weight ?? 0) \(weightUnit)"
        }
        
        if let currentWeight = view.viewWithTag(101) as? UILabel {
            currentWeight.text = "Current Weight: \(weightEntries.last?.weight ?? 0) \(weightUnit)"
        }
        
        if let weightChange = view.viewWithTag(102) as? UILabel {
            let change = (weightEntries.last?.weight ?? 0) - (weightEntries.first?.weight ?? 0)
            weightChange.text = "Change: \(String(format: "%.1f", change)) \(weightUnit)"
        }
        
        // Update chart
        if let chartView = view.viewWithTag(200) as? LineChartView {
            let entries = weightEntries.enumerated().map { index, entry in
                ChartDataEntry(x: Double(index), y: entry.weight)
            }
            
            let dataSet = LineChartDataSet(entries: entries, label: "Weight")
            dataSet.mode = .cubicBezier
            dataSet.drawCirclesEnabled = true
            dataSet.circleRadius = 4
            dataSet.circleColors = [.systemBlue]
            dataSet.colors = [.systemBlue]
            dataSet.drawFilledEnabled = true
            dataSet.fillColor = .systemBlue
            dataSet.fillAlpha = 0.1
            
            chartView.data = LineChartData(dataSet: dataSet)
            chartView.animate(xAxisDuration: 0.5)
        }
    }
    
    private func setupChartContainer() {
        let chartContainer = UIView()
        chartContainer.backgroundColor = .secondarySystemBackground
        chartContainer.layer.cornerRadius = 12
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
    
    private func setupStatsView() {
        let statsContainer = UIStackView()
        statsContainer.axis = .horizontal
        statsContainer.distribution = .fillEqually
        statsContainer.spacing = 16
        
        // Add stat cards
        statsContainer.addArrangedSubview(createStatCard(title: "Current", value: "75.5 kg", change: nil))
        statsContainer.addArrangedSubview(createStatCard(title: "Change", value: "-2.3 kg", change: .negative))
        statsContainer.addArrangedSubview(createStatCard(title: "Goal", value: "70.0 kg", change: nil))
        
        contentView.addArrangedSubview(statsContainer)
    }
    
    private func createStatCard(title: String, value: String, change: Change?) -> UIView {
        let card = UIView()
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
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 18, weight: .bold)
        valueLabel.textColor = change?.color ?? .label
        
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(valueLabel)
        
        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 80),
            stack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
        
        return card
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
        chartView.rightAxis.enabled = false
        chartView.legend.enabled = false
        
        let xAxis = chartView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = false
        
        let leftAxis = chartView.leftAxis
        leftAxis.axisMinimum = 0
        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridLineDashLengths = [4, 4]
    }
    
    private func loadData() {
        // Mock data - Replace with real data source
        let entries = (0..<7).map { i -> ChartDataEntry in
            return ChartDataEntry(x: Double(i), y: Double.random(in: 70...80))
        }
        
        let dataSet = LineChartDataSet(entries: entries)
        dataSet.setColor(.systemBlue)
        dataSet.lineWidth = 2
        dataSet.circleRadius = 4
        dataSet.circleColors = [.systemBlue]
        dataSet.mode = .cubicBezier
        
        chartView.data = LineChartData(dataSet: dataSet)
    }
    
    @objc private func showWeightEntry() {
        let alert = UIAlertController(title: "Log Weight", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Weight in kg"
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
        // Save weight to data source
        print("Weight logged: \(weight)")
    }
}

enum Change {
    case positive
    case negative
    
    var color: UIColor {
        switch self {
        case .positive:
            return .systemGreen
        case .negative:
            return .systemRed
        }
    }
}