import UIKit
import DGCharts

class CaloriesViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    private let dataManager = StatsDataManager.shared
    private var calorieEntries: [CalorieEntryModel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadCalorieData()
    }
    
    private func setupUI() {
        title = "Calories"
        view.backgroundColor = .systemBackground
        
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Setup content stack view
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
        
        // Add circular progress view
        let progressView = createProgressView()
        contentView.addArrangedSubview(progressView)
        
        // Add calorie breakdown
        let breakdownView = createBreakdownView()
        contentView.addArrangedSubview(breakdownView)
        
        // Add weekly chart
        let chartView = createWeeklyChartView()
        contentView.addArrangedSubview(chartView)
    }
    
    private func createProgressView() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        
        // Create circular progress view
        let circleView = CircularProgressView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        circleView.tag = 100
        circleView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(circleView)
        
        // Add labels for remaining calories
        let remainingLabel = UILabel()
        remainingLabel.tag = 101
        remainingLabel.font = .systemFont(ofSize: 32, weight: .bold)
        remainingLabel.textAlignment = .center
        remainingLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(remainingLabel)
        
        let remainingTextLabel = UILabel()
        remainingTextLabel.text = "calories remaining"
        remainingTextLabel.font = .systemFont(ofSize: 14, weight: .regular)
        remainingTextLabel.textColor = .secondaryLabel
        remainingTextLabel.textAlignment = .center
        remainingTextLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(remainingTextLabel)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 250),
            
            circleView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            circleView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            circleView.widthAnchor.constraint(equalToConstant: 200),
            circleView.heightAnchor.constraint(equalToConstant: 200),
            
            remainingLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            remainingLabel.centerYAnchor.constraint(equalTo: circleView.centerYAnchor, constant: -10),
            
            remainingTextLabel.centerXAnchor.constraint(equalTo: circleView.centerXAnchor),
            remainingTextLabel.topAnchor.constraint(equalTo: remainingLabel.bottomAnchor, constant: 4)
        ])
        
        return container
    }
    
    private func createBreakdownView() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        // Add goal, consumed, and burned sections
        let goalSection = createInfoSection(title: "Goal", tag: 101, color: .systemGreen)
        let consumedSection = createInfoSection(title: "Consumed", tag: 102, color: .systemOrange)
        let burnedSection = createInfoSection(title: "Burned", tag: 103, color: .systemBlue)
        
        stackView.addArrangedSubview(goalSection)
        stackView.addArrangedSubview(consumedSection)
        stackView.addArrangedSubview(burnedSection)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 100),
            stackView.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])
        
        return container
    }
    
    private func createInfoSection(title: String, tag: Int, color: UIColor) -> UIView {
        let container = UIView()
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stackView)
        
        let valueLabel = UILabel()
        valueLabel.tag = tag
        valueLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        valueLabel.textColor = color
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = .secondaryLabel
        
        stackView.addArrangedSubview(valueLabel)
        stackView.addArrangedSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func createWeeklyChartView() -> UIView {
        let container = UIView()
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 16
        
        let titleLabel = UILabel()
        titleLabel.text = "This Week"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        let chartView = BarChartView()
        chartView.tag = 104
        chartView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(chartView)
        
        // Configure chart
        setupWeeklyChart(chartView)
        
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
    
    private func setupWeeklyChart(_ chartView: BarChartView) {
        // Configure chart appearance and data
        chartView.rightAxis.enabled = false
        chartView.leftAxis.labelTextColor = .label
        chartView.xAxis.labelTextColor = .label
        chartView.legend.enabled = false
    }
    
    private func loadCalorieData() {
        dataManager.fetchCalorieData { [weak self] entries in
            self?.calorieEntries = entries
            
            DispatchQueue.main.async {
                self?.updateUI()
            }
        }
    }
    
    private func updateUI() {
        guard let latestEntry = calorieEntries.first else { return }
        
        // Update circular progress
        if let progressView = view.viewWithTag(100) as? CircularProgressView {
            let progress = Float(latestEntry.consumed / latestEntry.goal)
            progressView.setProgress(progress, animated: true)
        }
        
        // Update stats labels
        if let goalLabel = view.viewWithTag(101) as? UILabel {
            goalLabel.text = "\(Int(latestEntry.goal))"
        }
        if let consumedLabel = view.viewWithTag(102) as? UILabel {
            consumedLabel.text = "\(Int(latestEntry.consumed))"
        }
        if let burnedLabel = view.viewWithTag(103) as? UILabel {
            burnedLabel.text = "\(Int(latestEntry.burned))"
        }
        
        // Update chart
        if let chartView = view.viewWithTag(104) as? BarChartView {
            let entries = calorieEntries.enumerated().map { index, entry -> BarChartDataEntry in
                return BarChartDataEntry(x: Double(index), y: entry.consumed)
            }
            
            let dataSet = BarChartDataSet(entries: entries, label: "Calories")
            dataSet.colors = [.systemBlue]
            dataSet.valueTextColor = .label
            
            chartView.data = BarChartData(dataSet: dataSet)
            chartView.notifyDataSetChanged()
        }
    }
}

// Custom circular progress view
class CircularProgressView: UIView {
    private var progressLayer = CAShapeLayer()
    private var trackLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        createCircularPath()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        createCircularPath()
    }
    
    private func createCircularPath() {
        let circularPath = UIBezierPath(arcCenter: CGPoint(x: frame.size.width/2, y: frame.size.height/2),
                                      radius: frame.size.width/2 - 15,
                                      startAngle: -(.pi/2),
                                      endAngle: .pi * 3/2,
                                      clockwise: true)
        
        trackLayer.path = circularPath.cgPath
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.systemGray5.cgColor
        trackLayer.lineWidth = 15
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)
        
        progressLayer.path = circularPath.cgPath
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.systemBlue.cgColor
        progressLayer.lineWidth = 15
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        layer.addSublayer(progressLayer)
    }
    
    func setProgress(_ value: Float, animated: Bool = true) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.duration = animated ? 1 : 0
        animation.fromValue = progressLayer.strokeEnd
        animation.toValue = CGFloat(value)
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        progressLayer.strokeEnd = CGFloat(value)
        progressLayer.add(animation, forKey: "animateProgress")
    }
}