import UIKit
import SwiftUI

// MARK: - GoalsViewController Delegate Protocol
protocol GoalsViewControllerDelegate: AnyObject {
    func goalsViewController(_ controller: GoalsViewController, didUpdateMacroGoals macroGoals: (proteinGoal: Double, carbsGoal: Double, fatGoal: Double))
}

class GoalsViewController: UIViewController {
    // MARK: - Properties
    weak var delegate: GoalsViewControllerDelegate?
    
    var macroGoals: (proteinGoal: Double, carbsGoal: Double, fatGoal: Double) = (150, 250, 65)
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let saveButton = UIButton(type: .system)
    
    private var proteinGoalCell: StepperTableViewCell?
    private var carbsGoalCell: StepperTableViewCell?
    private var fatGoalCell: StepperTableViewCell?
    
    private var scrollView: UIScrollView!
    private var stackView: UIStackView!
    private let chartFactory = ChartFactory()
    var initialSection: String?
    private var chartViews: [String: UIView] = [:]
    
    // MARK: - View Lifecycle
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
        
        title = "Nutrition Goals"
        view.backgroundColor = .systemBackground
        
        setupNavigationBar()
        setupTableView()
        setupSaveButton()
    }
    
    // MARK: - UI Setup
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
    
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissController)
        )
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(StepperTableViewCell.self, forCellReuseIdentifier: "StepperCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DefaultCell")
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80)
        ])
    }
    
    private func setupSaveButton() {
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitle("Save Goals", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        saveButton.layer.cornerRadius = 12
        saveButton.addTarget(self, action: #selector(saveGoals), for: .touchUpInside)
        
        view.addSubview(saveButton)
        
        NSLayoutConstraint.activate([
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Actions
    @objc private func dismissController() {
        dismiss(animated: true)
    }
    
    @objc private func saveGoals() {
        var newProteinGoal = macroGoals.proteinGoal
        var newCarbsGoal = macroGoals.carbsGoal
        var newFatGoal = macroGoals.fatGoal
        
        if let proteinCell = proteinGoalCell {
            newProteinGoal = proteinCell.value
        }
        
        if let carbsCell = carbsGoalCell {
            newCarbsGoal = carbsCell.value
        }
        
        if let fatCell = fatGoalCell {
            newFatGoal = fatCell.value
        }
        
        // Update macro goals
        macroGoals = (proteinGoal: newProteinGoal, carbsGoal: newCarbsGoal, fatGoal: newFatGoal)
        
        // Notify delegate
        delegate?.goalsViewController(self, didUpdateMacroGoals: macroGoals)
        
        // Dismiss
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension GoalsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 3 : 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Macro Goals (grams)" : "Nutrition Targets"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "StepperCell", for: indexPath) as! StepperTableViewCell
            
            switch indexPath.row {
            case 0:
                cell.configure(title: "Protein", value: macroGoals.proteinGoal, minValue: 0, maxValue: 300, step: 5)
                proteinGoalCell = cell
            case 1:
                cell.configure(title: "Carbs", value: macroGoals.carbsGoal, minValue: 0, maxValue: 500, step: 5)
                carbsGoalCell = cell
            case 2:
                cell.configure(title: "Fat", value: macroGoals.fatGoal, minValue: 0, maxValue: 200, step: 5)
                fatGoalCell = cell
            default:
                break
            }
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath)
            cell.textLabel?.text = "Additional Nutrition Settings"
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 1 {
            // In a real app, this would navigate to additional nutrition settings
            let alertController = UIAlertController(
                title: "Coming Soon",
                message: "Additional nutrition settings are under development.",
                preferredStyle: .alert
            )
            
            alertController.addAction(UIAlertAction(title: "OK", style: .default))
            present(alertController, animated: true)
        }
    }
}

// MARK: - StepperTableViewCell
class StepperTableViewCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let stepper = UIStepper()
    
    var value: Double {
        return stepper.value
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        selectionStyle = .none
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 16)
        
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        valueLabel.textAlignment = .right
        
        stepper.translatesAutoresizingMaskIntoConstraints = false
        stepper.addTarget(self, action: #selector(stepperValueChanged), for: .valueChanged)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(stepper)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            stepper.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stepper.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            valueLabel.trailingAnchor.constraint(equalTo: stepper.leadingAnchor, constant: -16),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            valueLabel.widthAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    func configure(title: String, value: Double, minValue: Double, maxValue: Double, step: Double) {
        titleLabel.text = title
        stepper.minimumValue = minValue
        stepper.maximumValue = maxValue
        stepper.stepValue = step
        stepper.value = value
        updateValueLabel()
    }
    
    @objc private func stepperValueChanged() {
        updateValueLabel()
    }
    
    private func updateValueLabel() {
        valueLabel.text = String(format: "%.0fg", stepper.value)
    }
}