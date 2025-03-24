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
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .tertiarySystemBackground
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let segmentedControl: UISegmentedControl = {
        let items = ["Today", "Week", "Month"]
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    private let dateRangeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
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
        addSubview(containerView)
        containerView.addSubview(segmentedControl)
        containerView.addSubview(dateRangeLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            segmentedControl.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            segmentedControl.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.6),
            
            dateRangeLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            dateRangeLabel.leadingAnchor.constraint(equalTo: segmentedControl.trailingAnchor, constant: 8),
            dateRangeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12)
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