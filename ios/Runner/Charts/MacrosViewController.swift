import UIKit

class MacrosViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let pieChartView = PieChartView()
    private let dataManager = StatsDataManager.shared
    private var macroEntries: [MacrosEntry] = []
    
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
        setupChartView()
        loadMacroData()
    }
    
    private func setupUI() {
        title = "Macros"
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
        
        setupMacroDistribution()
        setupPieChartContainer()
        setupMacroBreakdown()
    }
    
    private func setupMacroDistribution() {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Today's Macros"
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        
        let distributonStack = UIStackView()
        distributonStack.axis = .horizontal
        distributonStack.spacing = 24
        distributonStack.distribution = .fillEqually
        
        let macros = [
            ("Protein", "65g", UIColor.systemRed),
            ("Carbs", "200g", UIColor.systemBlue),
            ("Fat", "55g", UIColor.systemYellow)
        ]
        
        macros.forEach { name, value, color in
            distributonStack.addArrangedSubview(createMacroItem(name: name, value: value, color: color))
        }
        
        [titleLabel, distributonStack].forEach {
            stackView.addArrangedSubview($0)
        }
        
        card.addSubview(stackView)
        contentView.addArrangedSubview(card)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 120),
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
    }
    
    private func createMacroItem(name: String, value: String, color: UIColor) -> UIView {
        let container = UIView()
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let colorIndicator = UIView()
        colorIndicator.backgroundColor = color
        colorIndicator.layer.cornerRadius = 4
        colorIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 14)
        nameLabel.textColor = .secondaryLabel
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        
        [colorIndicator, nameLabel, valueLabel].forEach {
            stack.addArrangedSubview($0)
        }
        
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            colorIndicator.widthAnchor.constraint(equalToConstant: 16),
            colorIndicator.heightAnchor.constraint(equalToConstant: 8),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func setupPieChartContainer() {
        let chartContainer = UIView()
        chartContainer.backgroundColor = .secondarySystemBackground
        chartContainer.layer.cornerRadius = 16
        
        pieChartView.translatesAutoresizingMaskIntoConstraints = false
        chartContainer.addSubview(pieChartView)
        
        contentView.addArrangedSubview(chartContainer)
        
        NSLayoutConstraint.activate([
            chartContainer.heightAnchor.constraint(equalToConstant: 300),
            pieChartView.topAnchor.constraint(equalTo: chartContainer.topAnchor, constant: 16),
            pieChartView.leadingAnchor.constraint(equalTo: chartContainer.leadingAnchor, constant: 16),
            pieChartView.trailingAnchor.constraint(equalTo: chartContainer.trailingAnchor, constant: -16),
            pieChartView.bottomAnchor.constraint(equalTo: chartContainer.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupMacroBreakdown() {
        let breakdownCard = UIView()
        breakdownCard.backgroundColor = .secondarySystemBackground
        breakdownCard.layer.cornerRadius = 16
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Macro Breakdown"
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        
        stackView.addArrangedSubview(titleLabel)
        
        let macros = [
            ("Protein", 65, 75, UIColor.systemRed),
            ("Carbs", 200, 250, UIColor.systemBlue),
            ("Fat", 55, 65, UIColor.systemYellow)
        ]
        
        macros.forEach { name, current, goal, color in
            stackView.addArrangedSubview(createProgressRow(
                name: name,
                current: current,
                goal: goal,
                color: color
            ))
        }
        
        breakdownCard.addSubview(stackView)
        contentView.addArrangedSubview(breakdownCard)
        
        NSLayoutConstraint.activate([
            breakdownCard.heightAnchor.constraint(equalToConstant: 220),
            stackView.topAnchor.constraint(equalTo: breakdownCard.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: breakdownCard.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: breakdownCard.trailingAnchor, constant: -16)
        ])
    }
    
    private func createProgressRow(name: String, current: Int, goal: Int, color: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 16)
        
        let progressView = UIProgressView(progressViewStyle: .bar)
        progressView.progress = Float(current) / Float(goal)
        progressView.progressTintColor = color
        
        let valueLabel = UILabel()
        valueLabel.text = "\(current)/\(goal)g"
        valueLabel.font = .systemFont(ofSize: 14)
        valueLabel.textColor = .secondaryLabel
        
        [nameLabel, progressView, valueLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 44),
            
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            nameLabel.widthAnchor.constraint(equalToConstant: 80),
            
            progressView.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 16),
            progressView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 8),
            
            valueLabel.leadingAnchor.constraint(equalTo: progressView.trailingAnchor, constant: 16),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
    }
    
    private func setupChartView() {
        loadMacroData()
    }
    
    private func loadMacroData() {
        dataManager.fetchMacroData { [weak self] entries in
            DispatchQueue.main.async {
                self?.updateChartData(with: entries)
            }
        }
    }
    
    private func updateChartData(with entries: [MacrosEntry]) {
        guard let entry = entries.last else { return }
        let total = entry.proteins + entry.carbs + entry.fats
        let data = [
            (value: entry.proteins, color: UIColor.systemRed),
            (value: entry.carbs, color: UIColor.systemBlue),
            (value: entry.fats, color: UIColor.systemYellow)
        ]
        (pieChartView as? PieChartView)?.updateChart(with: data, total: total)
    }
}