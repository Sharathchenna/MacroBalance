import UIKit
import SwiftUI
import DGCharts

class WeightViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private var weightEntries: [WeightEntryModel] = []
    private let dataManager = StatsDataManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadWeightData()
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
        
        // Add chart view
        let chartView = createChartView()
        contentView.addArrangedSubview(chartView)
        
        // Add stats view
        let statsView = createStatsView()
        contentView.addArrangedSubview(statsView)
        
        // Add history table
        let historyView = createHistoryView()
        contentView.addArrangedSubview(historyView)
    }
    
    private func createChartView() -> UIView {
        let chartContainer = UIView()
        chartContainer.backgroundColor = .secondarySystemBackground
        chartContainer.layer.cornerRadius = 12
        chartContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup chart view
        let chartView = LineChartView()
        chartView.tag = 100
        chartView.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(chartView)
        
        NSLayoutConstraint.activate([
            chartContainer.heightAnchor.constraint(equalToConstant: 300),
            chartView.topAnchor.constraint(equalTo: chartContainer.topAnchor, constant: 16),
            chartView.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: 16),
            chartView.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor, constant: -16),
            chartView.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: -16)
        ])
        
        // Configure chart
        chartView.rightAxis.enabled = false
        chartView.leftAxis.labelTextColor = .label
        chartView.xAxis.labelTextColor = .label
        chartView.legend.enabled = false
        chartView.pinchZoomEnabled = false
        chartView.doubleTapToZoomEnabled = false
        
        return chartContainer
    }
    
    private func createStatsView() -> UIView {
        let statsContainer = UIView()
        statsContainer.backgroundColor = .secondarySystemBackground
        statsContainer.layer.cornerRadius = 12
        
        // Add stats labels and values
        let titleLabel = UILabel()
        titleLabel.text = "Statistics"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        
        // Create and configure stats grid here
        
        return statsContainer
    }
    
    private func createHistoryView() -> UIView {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "WeightCell")
        tableView.isScrollEnabled = false
        
        // Calculate height based on number of entries (limited to last 10)
        let numberOfEntries = min(weightEntries.count, 10)
        let height = CGFloat(numberOfEntries * 44) // 44 is the default cell height
        
        tableView.heightAnchor.constraint(equalToConstant: height).isActive = true
        
        return tableView
    }
    
    @objc private func addWeightEntry() {
        let alert = UIAlertController(
            title: "Add Weight Entry",
            message: "Enter your current weight",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.keyboardType = .decimalPad
            textField.placeholder = "Weight in kg"
        }
        
        let addAction = UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let weightText = alert.textFields?.first?.text,
                  let weight = Double(weightText) else { return }
            
            let entry = WeightEntryModel(date: Date(), weight: weight)
            self?.weightEntries.append(entry)
            self?.updateUI()
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(addAction)
        
        present(alert, animated: true)
    }
    
    private func loadWeightData() {
        dataManager.fetchWeightData { [weak self] entries in
            self?.weightEntries = entries
            DispatchQueue.main.async {
                self?.updateUI()
            }
        }
    }
    
    private func updateUI() {
        // Update chart data
        if let chartView = view.viewWithTag(100) as? LineChartView {
            let entries = weightEntries.enumerated().map { index, entry -> ChartDataEntry in
                return ChartDataEntry(x: Double(index), y: entry.weight)
            }
            
            let dataSet = LineChartDataSet(entries: entries, label: "Weight")
            dataSet.colors = [.systemBlue]
            dataSet.circleColors = [.systemBlue]
            dataSet.circleRadius = 4
            dataSet.lineWidth = 2
            
            chartView.data = LineChartData(dataSet: dataSet)
            chartView.notifyDataSetChanged()
        }
    }
}