import Foundation
#if canImport(UIKit)
import UIKit
#endif
import DGCharts

class MacrosDistributionChartView: UIView, ChartViewDelegate { // Add ChartViewDelegate
    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Macronutrient Distribution"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Tap a segment for details"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let pieChartView: DGCharts.PieChartView = {
        let chart = MacrosChartFactory.createPieChart()
        chart.translatesAutoresizingMaskIntoConstraints = false
        // chart.delegate = self // Delegate will be set in setupUI
        return chart
    }()
    
    private let valueLabelsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let proteinLabel = MacroValueLabel(title: "Protein", color: .proteinColor)
    private let carbsLabel = MacroValueLabel(title: "Carbs", color: .carbColor)
    private let fatsLabel = MacroValueLabel(title: "Fat", color: .fatColor)
    
    // MARK: - Properties
    private var currentEntry: Models.MacrosEntry?
    private var centerTextLabel: UILabel?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .secondarySystemGroupedBackground // Apply card background
        layer.cornerRadius = 18 // Consistent corner radius
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 6
        layer.shadowOpacity = 0.08
        layer.masksToBounds = false
        
        // Add subviews directly
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(pieChartView)
        
        pieChartView.delegate = self // Set delegate
        
        // Create center text label
        centerTextLabel = UILabel()
        centerTextLabel?.textAlignment = .center
        centerTextLabel?.numberOfLines = 0
        centerTextLabel?.font = .systemFont(ofSize: 14, weight: .regular) // Default font
        centerTextLabel?.textColor = .secondaryLabel
        centerTextLabel?.text = "No Data"
        centerTextLabel?.translatesAutoresizingMaskIntoConstraints = false
        
        if let centerTextLabel = centerTextLabel {
            // Add to the main view, not the chart, to avoid clipping issues
            addSubview(centerTextLabel)
            
            NSLayoutConstraint.activate([
                centerTextLabel.centerXAnchor.constraint(equalTo: pieChartView.centerXAnchor), // Center within chart bounds
                centerTextLabel.centerYAnchor.constraint(equalTo: pieChartView.centerYAnchor),
                centerTextLabel.widthAnchor.constraint(lessThanOrEqualTo: pieChartView.widthAnchor, multiplier: 0.55), // Slightly smaller max width
                centerTextLabel.heightAnchor.constraint(lessThanOrEqualTo: pieChartView.heightAnchor, multiplier: 0.55)
            ])
        }
        
        // Add value labels stack view
        addSubview(valueLabelsStackView)
        [proteinLabel, carbsLabel, fatsLabel].forEach {
            valueLabelsStackView.addArrangedSubview($0)
        }
        
        NSLayoutConstraint.activate([
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            // Subtitle constraints
            subtitleLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            
            // Pie Chart constraints
            pieChartView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12), // More space
            pieChartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            pieChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            pieChartView.heightAnchor.constraint(equalTo: pieChartView.widthAnchor, multiplier: 0.75), // Adjust ratio slightly
            
            // Value Labels Stack constraints
            valueLabelsStackView.topAnchor.constraint(equalTo: pieChartView.bottomAnchor, constant: 12), // More space
            valueLabelsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            valueLabelsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            valueLabelsStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Configuration
    func configure(with entry: Models.MacrosEntry?) {
        currentEntry = entry
        
        guard let entry = entry else {
            resetChart()
            return
        }
        
        // Calculate total and percentages
        let total = entry.proteins + entry.carbs + entry.fats
        guard total > 0 else {
            resetChart()
            return
        }
        
        let proteinPercent = (entry.proteins / total) * 100
        let carbsPercent = (entry.carbs / total) * 100
        let fatsPercent = (entry.fats / total) * 100
        
        // Update value labels
        proteinLabel.updateValue(entry.proteins, percent: proteinPercent)
        carbsLabel.updateValue(entry.carbs, percent: carbsPercent)
        fatsLabel.updateValue(entry.fats, percent: fatsPercent)
        
        // Create data entries
        let entries: [PieChartDataEntry] = [
            PieChartDataEntry(value: Double(entry.proteins), label: "Protein"),
            PieChartDataEntry(value: Double(entry.carbs), label: "Carbs"),
            PieChartDataEntry(value: Double(entry.fats), label: "Fat")
        ]
        
        // Create dataset
        let dataSet = PieChartDataSet(entries: entries)
        
        // Configure dataset appearance
        let colors: [UIColor] = [.proteinColor, .carbColor, .fatColor]
        dataSet.colors = colors
        dataSet.sliceSpace = 3 // Slightly more space
        dataSet.selectionShift = 6 // Slightly less shift
        dataSet.valueFont = .systemFont(ofSize: 13, weight: .semibold) // Adjust font
        dataSet.valueTextColor = .secondaryLabel // Less prominent color
        dataSet.valueFormatter = MacroPercentValueFormatter() // Assuming this exists and works
        dataSet.valueLineWidth = 1.0 // Thinner line
        dataSet.valueLinePart1Length = 0.4 // Adjust line lengths
        dataSet.valueLinePart2Length = 0.3
        dataSet.valueLineColor = .tertiaryLabel // Match axis colors
        dataSet.xValuePosition = .outsideSlice
        dataSet.yValuePosition = .outsideSlice
        
        // Create chart data
        let chartData = PieChartData(dataSet: dataSet)
        pieChartView.data = chartData
        
        // Set center text
        updateCenterText(for: nil)
    }
    
    private func updateCenterText(for index: Int?, animated: Bool = true) { // Add animated flag
        guard let entry = currentEntry, let centerLabel = centerTextLabel else { return }
        
        let newText: NSAttributedString
        
        if let index = index {
            // Show specific macro details when segment is selected
            let macroName = ["Protein", "Carbs", "Fat"][index]
            let macroValue = [entry.proteins, entry.carbs, entry.fats][index]
            // let macroGoal = [entry.proteinGoal, entry.carbGoal, entry.fatGoal][index] // Goal not used here currently
            
            // let percentText = macroGoal > 0 ? " (\(Int((macroValue / macroGoal) * 100))%)" : "" // Goal % not shown on tap
            newText = createAttributedString(
                mainText: "\(Int(macroValue))g",
                secondaryText: macroName // Just show name on tap
            )
        } else {
            // Show overall macro ratio P/C/F
            let total = entry.proteins + entry.carbs + entry.fats
            
            let proteinPercent = total > 0 ? Int((entry.proteins / total) * 100) : 0
            let carbsPercent = total > 0 ? Int((entry.carbs / total) * 100) : 0
            let fatsPercent = total > 0 ? Int((entry.fats / total) * 100) : 0
            
            newText = createAttributedString(
                mainText: "\(proteinPercent)/\(carbsPercent)/\(fatsPercent)",
                secondaryText: "P / C / F" // Add spacing
            )
        }
        
        // Animate the text change
        if animated {
            UIView.transition(with: centerLabel, duration: 0.25, options: .transitionCrossDissolve, animations: {
                centerLabel.attributedText = newText
            }, completion: nil)
        } else {
            centerLabel.attributedText = newText
        }
    }
    
    private func createAttributedString(mainText: String, secondaryText: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // Secondary text (e.g., "P/C/F" or "Protein")
        if !secondaryText.isEmpty {
            result.append(NSAttributedString(
                string: "\(secondaryText)\n",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 15, weight: .semibold), // Adjusted size/weight
                    .foregroundColor: UIColor.secondaryLabel
                ]
            ))
        }
        
        // Main text (e.g., "40/40/20" or "120g")
        result.append(NSAttributedString(
            string: mainText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold), // Adjusted size/weight
                .foregroundColor: UIColor.label
            ]
        ))
        
        return result
    }
    
    private func resetChart() {
        pieChartView.data = nil
        centerTextLabel?.text = "No Data"
        
        proteinLabel.updateValue(0, percent: 0)
        carbsLabel.updateValue(0, percent: 0)
        fatsLabel.updateValue(0, percent: 0)
    }
    
    // MARK: - ChartViewDelegate
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        updateCenterText(for: Int(highlight.x), animated: true)
    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        updateCenterText(for: nil, animated: true)
    }
    
    // MARK: - System Overrides
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Colors will update automatically through system colors
        }
    }
}

// MARK: - MacroValueLabel
private class MacroValueLabel: UIView {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let percentLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let colorIndicator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 4
        return view
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    init(title: String, color: UIColor) {
        super.init(frame: .zero)
        
        titleLabel.text = title
        colorIndicator.backgroundColor = color
        valueLabel.textColor = color.adjustBrightness(by: -0.1)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        let titleStack = UIStackView()
        titleStack.spacing = 4
        titleStack.alignment = .center
        titleStack.addArrangedSubview(colorIndicator)
        titleStack.addArrangedSubview(titleLabel)
        
        stackView.addArrangedSubview(titleStack)
        stackView.addArrangedSubview(valueLabel)
        stackView.addArrangedSubview(percentLabel)
        
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            colorIndicator.widthAnchor.constraint(equalToConstant: 8),
            colorIndicator.heightAnchor.constraint(equalToConstant: 8)
        ])
    }
    
    func updateValue(_ value: Double, percent: Double) {
        valueLabel.text = "\(Int(value))g"
        percentLabel.text = "(\(Int(percent))%)"
    }
}
