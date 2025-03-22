import UIKit
import DGCharts

class CaloriesViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let chartView = LineChartView()
    private let dataManager = StatsDataManager.shared
    private var calorieEntries: [CaloriesEntry] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupChartView()
        loadCalorieData()
    }
    
    private func setupUI() {
        title = "Calories"
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
        
        setupCaloriesSummary()
        setupChartContainer()
        setupBreakdown()
    }
    
    private func setupCaloriesSummary() {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let caloriesLabel = UILabel()
        caloriesLabel.text = "1,850"
        caloriesLabel.font = .systemFont(ofSize: 36, weight: .bold)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "calories consumed"
        subtitleLabel.font = .systemFont(ofSize: 16)
        subtitleLabel.textColor = .secondaryLabel
        
        let progressStack = UIStackView()
        progressStack.axis = .horizontal
        progressStack.spacing = 8
        progressStack.alignment = .center
        
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progress = 0.75
        progressView.progressTintColor = .systemGreen
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        let percentageLabel = UILabel()
        percentageLabel.text = "75%"
        percentageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        percentageLabel.textColor = .systemGreen
        
        progressStack.addArrangedSubview(progressView)
        progressStack.addArrangedSubview(percentageLabel)
        
        let goalLabel = UILabel()
        goalLabel.text = "Daily Goal: 2,500 calories"
        goalLabel.font = .systemFont(ofSize: 14)
        goalLabel.textColor = .secondaryLabel
        
        [caloriesLabel, subtitleLabel, progressStack, goalLabel].forEach {
            stackView.addArrangedSubview($0)
        }
        
        card.addSubview(stackView)
        contentView.addArrangedSubview(card)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 160),
            progressView.widthAnchor.constraint(equalToConstant: 200),
            progressView.heightAnchor.constraint(equalToConstant: 8),
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupChartContainer() {
        let chartContainer = UIView()
        chartContainer.backgroundColor = .secondarySystemBackground
        chartContainer.layer.cornerRadius = 16
        
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
    
    private func setupBreakdown() {
        let breakdownCard = UIView()
        breakdownCard.backgroundColor = .secondarySystemBackground
        breakdownCard.layer.cornerRadius = 16
        
        let titleLabel = UILabel()
        titleLabel.text = "Meal Breakdown"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        breakdownCard.addSubview(titleLabel)
        breakdownCard.addSubview(stackView)
        
        contentView.addArrangedSubview(breakdownCard)
        
        // Add meal rows
        let meals = [
            ("Breakfast", 450),
            ("Lunch", 650),
            ("Dinner", 550),
            ("Snacks", 200)
        ]
        
        meals.forEach { meal, calories in
            stackView.addArrangedSubview(createMealRow(name: meal, calories: calories))
        }
        
        NSLayoutConstraint.activate([
            breakdownCard.heightAnchor.constraint(equalToConstant: 250),
            titleLabel.topAnchor.constraint(equalTo: breakdownCard.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: breakdownCard.leadingAnchor, constant: 16),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: breakdownCard.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: breakdownCard.trailingAnchor, constant: -16)
        ])
    }
    
    private func createMealRow(name: String, calories: Int) -> UIView {
        let container = UIView()
        
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 16)
        
        let caloriesLabel = UILabel()
        caloriesLabel.text = "\(calories) cal"
        caloriesLabel.font = .systemFont(ofSize: 16)
        caloriesLabel.textColor = .secondaryLabel
        
        [nameLabel, caloriesLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 44),
            
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            caloriesLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            caloriesLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
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
        
        loadCalorieData()
    }
    
    private func loadCalorieData() {
        dataManager.fetchCalorieData { [weak self] entries in
            self?.calorieEntries = entries
            DispatchQueue.main.async {
                self?.updateChartData()
            }
        }
    }
    
    private func updateChartData() {
        let entries = calorieEntries.enumerated().map { index, entry in
            ChartDataEntry(x: Double(index), y: entry.calories)
        }
        
        let dataSet = LineChartDataSet(entries: entries, label: "Calories")
        dataSet.mode = .cubicBezier
        dataSet.drawCirclesEnabled = true
        dataSet.circleRadius = 4
        dataSet.circleColors = [.systemGreen]
        dataSet.colors = [.systemGreen]
        dataSet.drawFilledEnabled = true
        dataSet.fillColor = .systemGreen
        dataSet.fillAlpha = 0.1
        
        chartView.data = LineChartData(dataSet: dataSet)
        chartView.animate(xAxisDuration: 0.5)
    }
}