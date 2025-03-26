import UIKit

// Protocol for date range selection
protocol DateFilterControlDelegate: AnyObject {
    func dateRangeChanged(to range: DateRange)
}

class DateFilterControl: UIView {
    
    // MARK: - Properties
    weak var delegate: DateFilterControlDelegate?
    private var selectedRange: DateRange = .today
    
    // MARK: - UI Components
    private let segmentedControl: UISegmentedControl = {
        let items = ["Today", "7D", "30D"] // Shorter labels
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        
        // Apply theme to segmented control
        if #available(iOS 13.0, *) {
            control.selectedSegmentTintColor = ThemeManager.shared.accentPrimary
            control.setTitleTextAttributes([
                .foregroundColor: ThemeManager.shared.textPrimary,
                .font: ThemeManager.shared.fontBody2()
            ], for: .normal)
            control.setTitleTextAttributes([
                .foregroundColor: UIColor.white,
                .font: ThemeManager.shared.fontBody2()
            ], for: .selected)
        } else {
            control.tintColor = ThemeManager.shared.accentPrimary
        }
        
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let dateRangeLabel: UILabel = {
        let label = UILabel()
        // Apply theme fonts and colors
        label.font = ThemeManager.shared.fontCaption()
        label.textColor = ThemeManager.shared.textSecondary
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .horizontal) // Prevent label from being compressed
        return label
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupActions()
        updateDateLabel()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupActions()
        updateDateLabel()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = ThemeManager.shared.dateNavigatorBackground
        layer.cornerRadius = 22
        
        addSubview(segmentedControl)
        addSubview(dateRangeLabel)
        
        NSLayoutConstraint.activate([
            // Segmented Control constraints
            segmentedControl.topAnchor.constraint(equalTo: topAnchor, constant: 4), // Add padding
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            // Removed fixed width multiplier
            
            // Date Range Label constraints
            dateRangeLabel.centerYAnchor.constraint(equalTo: segmentedControl.centerYAnchor),
            dateRangeLabel.leadingAnchor.constraint(equalTo: segmentedControl.trailingAnchor, constant: 12), // More spacing
            dateRangeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        ])
    }
    
    private func setupActions() {
        segmentedControl.addTarget(self, action: #selector(segmentValueChanged), for: .valueChanged)
    }
    
    // MARK: - Actions
    @objc private func segmentValueChanged() {
        let selectedIndex = segmentedControl.selectedSegmentIndex
        
        switch selectedIndex {
        case 0:
            selectedRange = .today
        case 1:
            selectedRange = .week
        case 2:
            selectedRange = .month
        default:
            selectedRange = .today
        }
        
        updateDateLabel()
        delegate?.dateRangeChanged(to: selectedRange)
        
        // Add haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // MARK: - Helper Methods
    private func updateDateLabel() {
        let today = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        switch selectedRange {
        case .today:
            dateRangeLabel.text = formatter.string(from: today)
        case .week:
            let startOfWeek = calendar.date(byAdding: .day, value: -7, to: today) ?? today
            dateRangeLabel.text = "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: today))"
        case .month:
            let startOfMonth = calendar.date(byAdding: .month, value: -1, to: today) ?? today
            dateRangeLabel.text = "\(formatter.string(from: startOfMonth)) - \(formatter.string(from: today))"
        }
    }
}
