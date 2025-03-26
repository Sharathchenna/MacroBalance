import UIKit

protocol MacrosSettingsDelegate: AnyObject {
    func settingsDidUpdate()
}

class MacrosSettingsViewController: UIViewController, UITextFieldDelegate { // Add UITextFieldDelegate conformance
    // MARK: - Properties
    weak var delegate: MacrosSettingsDelegate?
    private var activeTextField: UITextField?

    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // Goal Settings
    private let goalSettingsView = SettingsSectionView(title: "Goal Settings")
    private let weightField = SettingsTextField(title: "Weight (kg)")
    private let heightField = SettingsTextField(title: "Height (cm)")
    private let activityLevelSegment = SettingsSegmentedControl(
        title: "Activity Level",
        options: ["Sedentary", "Light", "Moderate", "Active", "Very Active"]
    )
    
    // Macro Goals
    private let macroGoalsView = SettingsSectionView(title: "Macro Goals")
    private let proteinField = SettingsTextField(title: "Protein (g)")
    private let carbsField = SettingsTextField(title: "Carbs (g)")
    private let fatField = SettingsTextField(title: "Fat (g)")
    
    // Meal Settings
    private let mealSettingsView = SettingsSectionView(title: "Meal Settings")
    private let mealCountSegment = SettingsSegmentedControl(
        title: "Daily Meals",
        options: ["3", "4", "5", "6"]
    )
    private let mealTimingSwitch = SettingsSwitch(
        title: "Enable Meal Timing Reminders"
    )
    
    // Notification Settings
    private let notificationSettingsView = SettingsSectionView(title: "Notifications")
    private let dailyReminderSwitch = SettingsSwitch(
        title: "Daily Logging Reminder"
    )
    private let weeklyReportSwitch = SettingsSwitch(
        title: "Weekly Progress Report"
    )
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Settings"
        
        // Navigation bar setup with consistent spacing
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveSettings)
        )
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(dismissSettings)
        )
        
        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        
        // Configure content view and stack
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        // Add sections to stack view with consistent spacing
        [goalSettingsView, macroGoalsView, mealSettingsView, notificationSettingsView].forEach {
            stackView.addArrangedSubview($0)
        }
        
        // Add fields to sections
        goalSettingsView.addFields([weightField, heightField, activityLevelSegment])
        macroGoalsView.addFields([proteinField, carbsField, fatField])
        mealSettingsView.addFields([mealCountSegment, mealTimingSwitch])
        notificationSettingsView.addFields([dailyReminderSwitch, weeklyReportSwitch])
        
        NSLayoutConstraint.activate([
            // ScrollView constraints
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView constraints - pin to scroll view edges
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // StackView constraints with proper margins
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
        
        // Setup keyboard handling
        setupKeyboardHandling()
    }
    
    private func setupKeyboardHandling() {
        // Register for keyboard notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        // Setup text field delegates
        setupTextFieldDelegates()
    }
    
    private func setupTextFieldDelegates() {
        [weightField, heightField, proteinField, carbsField, fatField].forEach {
            $0.textField.delegate = self
        }
    }
    
    // MARK: - Data Management
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        // Load personal stats
        weightField.textField.text = String(defaults.double(forKey: "weight"))
        heightField.textField.text = String(defaults.double(forKey: "height"))
        activityLevelSegment.segmentedControl.selectedSegmentIndex = defaults.integer(forKey: "activity_level")
        
        // Load macro goals
        proteinField.textField.text = String(defaults.double(forKey: "protein_goal"))
        carbsField.textField.text = String(defaults.double(forKey: "carbs_goal"))
        fatField.textField.text = String(defaults.double(forKey: "fat_goal"))
        
        // Load meal settings
        mealCountSegment.segmentedControl.selectedSegmentIndex = defaults.integer(forKey: "meal_count")
        mealTimingSwitch.toggle.isOn = defaults.bool(forKey: "meal_timing_enabled")
        
        // Load notification settings
        dailyReminderSwitch.toggle.isOn = defaults.bool(forKey: "daily_reminder_enabled")
        weeklyReportSwitch.toggle.isOn = defaults.bool(forKey: "weekly_report_enabled")
    }
    
    @objc private func saveSettings() {
        let defaults = UserDefaults.standard
        
        // Save personal stats
        defaults.set(Double(weightField.textField.text ?? "0") ?? 0, forKey: "weight")
        defaults.set(Double(heightField.textField.text ?? "0") ?? 0, forKey: "height")
        defaults.set(activityLevelSegment.segmentedControl.selectedSegmentIndex, forKey: "activity_level")
        
        // Save macro goals
        defaults.set(Double(proteinField.textField.text ?? "0") ?? 0, forKey: "protein_goal")
        defaults.set(Double(carbsField.textField.text ?? "0") ?? 0, forKey: "carbs_goal")
        defaults.set(Double(fatField.textField.text ?? "0") ?? 0, forKey: "fat_goal")
        
        // Save meal settings
        defaults.set(mealCountSegment.segmentedControl.selectedSegmentIndex, forKey: "meal_count")
        defaults.set(mealTimingSwitch.toggle.isOn, forKey: "meal_timing_enabled")
        
        // Save notification settings
        defaults.set(dailyReminderSwitch.toggle.isOn, forKey: "daily_reminder_enabled")
        defaults.set(weeklyReportSwitch.toggle.isOn, forKey: "weekly_report_enabled")
        
        // Update notification settings if needed
        updateNotificationSettings()
        
        // Notify delegate
        delegate?.settingsDidUpdate()
        
        // Dismiss settings
        dismiss(animated: true)
    }
    
    @objc private func dismissSettings() {
        dismiss(animated: true)
    }
    
    private func updateNotificationSettings() {
        // Request notification permissions if needed
        if dailyReminderSwitch.toggle.isOn || weeklyReportSwitch.toggle.isOn {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                if granted {
                    DispatchQueue.main.async {
                        self.scheduleNotifications()
                    }
                }
            }
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
    
    private func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        
        // Schedule daily reminder
        if dailyReminderSwitch.toggle.isOn {
            let content = UNMutableNotificationContent()
            content.title = "Log Your Macros"
            content.body = "Don't forget to log your meals for today!"
            content.sound = .default
            
            var components = DateComponents()
            components.hour = 20 // 8 PM
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
            
            center.add(request)
        }
        
        // Schedule weekly report
        if weeklyReportSwitch.toggle.isOn {
            let content = UNMutableNotificationContent()
            content.title = "Weekly Progress Report"
            content.body = "Check out your macro tracking progress for the week!"
            content.sound = .default
            
            var components = DateComponents()
            components.weekday = 1 // Sunday
            components.hour = 10 // 10 AM
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "weekly_report", content: content, trigger: trigger)
            
            center.add(request)
        }
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        // Adjust scroll view content inset
        scrollView.contentInset.bottom = keyboardHeight
        scrollView.scrollIndicatorInsets.bottom = keyboardHeight
        
        // If a text field is being edited, scroll to make it visible
        if let activeField = activeTextField {
            let frame = activeField.convert(activeField.bounds, to: scrollView)
            let adjustedFrame = frame.insetBy(dx: 0, dy: -20) // Add some padding
            scrollView.scrollRectToVisible(adjustedFrame, animated: true)
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        // Reset scroll view content inset
        scrollView.contentInset.bottom = 0
        scrollView.scrollIndicatorInsets.bottom = 0
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    deinit {
        // Remove keyboard observers
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UITextFieldDelegate
    func textFieldDidBeginEditing(_ textField: UITextField) {
        activeTextField = textField // Track the active text field
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        activeTextField = nil // Clear active text field when editing ends
    }
}

// MARK: - Settings Views
private class SettingsSectionView: UIView {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(titleLabel)
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func addFields(_ fields: [UIView]) {
        fields.forEach { stackView.addArrangedSubview($0) }
    }
}

private class SettingsTextField: UIView {
    let textField: UITextField = {
        let field = UITextField()
        field.borderStyle = .roundedRect
        field.keyboardType = .decimalPad
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(titleLabel)
        addSubview(textField)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            
            textField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

private class SettingsSegmentedControl: UIView {
    let segmentedControl: UISegmentedControl
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init(title: String, options: [String]) {
        self.segmentedControl = UISegmentedControl(items: options)
        super.init(frame: .zero)
        titleLabel.text = title
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegmentIndex = 0
        
        addSubview(titleLabel)
        addSubview(segmentedControl)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            
            segmentedControl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

private class SettingsSwitch: UIView {
    let toggle: UISwitch = {
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        return toggle
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init(title: String) {
        super.init(frame: .zero)
        titleLabel.text = title
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(titleLabel)
        addSubview(toggle)
        
        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            heightAnchor.constraint(equalToConstant: 44)
        ])
    }
}
