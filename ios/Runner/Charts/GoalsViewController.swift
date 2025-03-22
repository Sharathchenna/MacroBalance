import UIKit
import SwiftUI

class GoalsViewController: UIViewController {
    private var scrollView: UIScrollView!
    private var stackView: UIStackView!
    private let chartFactory = ChartFactory()
    var initialSection: String?
    private var chartViews: [String: UIView] = [:]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadChartData()
        
        // Scroll to initial section if specified
        if let section = initialSection {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.scrollToSection(section)
            }
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Goals"
        
        // Setup scroll view
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Setup stack view
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
    }
    
    private func scrollToSection(_ section: String) {
        guard let targetView = chartViews[section] else { return }
        let frame = targetView.convert(targetView.bounds, to: scrollView)
        scrollView.scrollRectToVisible(frame, animated: true)
    }
    
    private func loadChartData() {
        // Mock data for testing - Replace with actual data fetching
        let today = Date()
        let calendar = Calendar.current
        
        // Weight data
        let weightData = (0..<7).map { days -> [String: Any] in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            return [
                "weight": Double.random(in: 150...155),
                "date": ISO8601DateFormatter().string(from: date)
            ]
        }
        
        // Steps data
        let stepsData = (0..<7).map { days -> [String: Any] in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            return [
                "steps": Int.random(in: 6000...12000),
                "goal": 10000,
                "date": ISO8601DateFormatter().string(from: date)
            ]
        }
        
        // Calories data
        let caloriesData = (0..<7).map { days -> [String: Any] in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            return [
                "calories": Double.random(in: 1800...2500),
                "goal": 2200.0,
                "date": ISO8601DateFormatter().string(from: date)
            ]
        }
        
        // Macros data
        let macrosData = (0..<7).map { days -> [String: Any] in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            return [
                "proteins": Double.random(in: 120...180),
                "carbs": Double.random(in: 200...300),
                "fats": Double.random(in: 50...80),
                "proteinGoal": 150.0,
                "carbGoal": 250.0,
                "fatGoal": 65.0,
                "date": ISO8601DateFormatter().string(from: date)
            ]
        }
        
        // Create and add chart views
        let charts = [
            ("weight", weightData),
            ("steps", stepsData),
            ("calories", caloriesData),
            ("macros", macrosData)
        ]
        
        for (type, data) in charts {
            let chartView = chartFactory.createChart(type: type, data: data, parent: self)
            let containerView = UIView()
            containerView.backgroundColor = .clear
            containerView.layer.cornerRadius = 12
            containerView.clipsToBounds = true
            
            // Add shadow and border
            containerView.layer.shadowColor = UIColor.black.cgColor
            containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
            containerView.layer.shadowRadius = 4
            containerView.layer.shadowOpacity = 0.1
            
            containerView.addSubview(chartView)
            chartView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                chartView.topAnchor.constraint(equalTo: containerView.topAnchor),
                chartView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                chartView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                chartView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                chartView.heightAnchor.constraint(equalToConstant: 300)
            ])
            
            stackView.addArrangedSubview(containerView)
            chartViews[type] = containerView // Store reference to container view
        }
    }
}