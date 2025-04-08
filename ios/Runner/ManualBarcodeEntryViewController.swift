import UIKit

// Delegate protocol to send results back
protocol ManualBarcodeEntryDelegate: AnyObject {
    func manualBarcodeEntryDidFinish(with barcode: String)
    func manualBarcodeEntryDidCancel()
}

class ManualBarcodeEntryViewController: UIViewController, UITextFieldDelegate {

    weak var delegate: ManualBarcodeEntryDelegate?

    private let barcodeTextField = UITextField()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let contentView = UIView() // Added container for premium card-like appearance
    private let titleLabel = UILabel() // Added for better typography
    private let subtitleLabel = UILabel() // Added for instructions
    private let barcodeIconView = UIImageView() // Added for visual enhancement
    
    // Premium UI Colors
    private let accentColor = UIColor(red: 0.28, green: 0.72, blue: 0.82, alpha: 1.0) // Sky blue accent
    private let darkOverlayColor = UIColor.black.withAlphaComponent(0.4) // Translucent overlay

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        barcodeTextField.becomeFirstResponder() // Show keyboard immediately
    }

    private func setupUI() {
        // Setup background with subtle gradient
        view.backgroundColor = .systemBackground
        
        // Add subtle gradient
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemBackground.cgColor,
            UIColor.systemGray6.cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = view.bounds
        view.layer.insertSublayer(gradientLayer, at: 0)
        
        // Setup navigation bar with premium look
        title = "Enter Barcode"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // Customize navigation bar appearance for a premium look
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        
        // Navigation Bar Items
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = accentColor
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "checkmark"),
            style: .plain,
            target: self,
            action: #selector(submitButtonTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = accentColor
        navigationItem.rightBarButtonItem?.isEnabled = false // Disabled initially
        
        // Content view (card-like container)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 4)
        contentView.layer.shadowOpacity = 0.1
        contentView.layer.shadowRadius = 8
        view.addSubview(contentView)
        
        // Barcode icon for visual enhancement
        barcodeIconView.translatesAutoresizingMaskIntoConstraints = false
        barcodeIconView.contentMode = .scaleAspectFit
        barcodeIconView.image = UIImage(systemName: "barcode.viewfinder")
        barcodeIconView.tintColor = accentColor
        contentView.addSubview(barcodeIconView)
        
        // Title label with better typography
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Manual Barcode Entry"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        contentView.addSubview(titleLabel)
        
        // Subtitle/instruction label
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Enter the barcode number below"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        contentView.addSubview(subtitleLabel)

        // Configure TextField with premium styling
        barcodeTextField.translatesAutoresizingMaskIntoConstraints = false
        barcodeTextField.placeholder = "Enter barcode number"
        barcodeTextField.font = UIFont.monospacedSystemFont(ofSize: 24, weight: .medium)
        barcodeTextField.textAlignment = .center
        barcodeTextField.keyboardType = .numberPad
        barcodeTextField.clearButtonMode = .whileEditing
        barcodeTextField.delegate = self
        barcodeTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        barcodeTextField.layer.cornerRadius = 12
        barcodeTextField.layer.borderWidth = 1
        barcodeTextField.layer.borderColor = UIColor.systemGray4.cgColor
        barcodeTextField.backgroundColor = .systemBackground
        
        // Add padding to text field
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: 1))
        barcodeTextField.leftView = paddingView
        barcodeTextField.leftViewMode = .always
        barcodeTextField.rightView = paddingView
        barcodeTextField.rightViewMode = .always
        
        contentView.addSubview(barcodeTextField)

        // Loading Indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = accentColor
        view.addSubview(loadingIndicator)

        // Layout everything with attractive spacing
        NSLayoutConstraint.activate([
            // Content view constraints
            contentView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            // Barcode icon constraints
            barcodeIconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            barcodeIconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            barcodeIconView.widthAnchor.constraint(equalToConstant: 60),
            barcodeIconView.heightAnchor.constraint(equalToConstant: 60),
            
            // Title label constraints
            titleLabel.topAnchor.constraint(equalTo: barcodeIconView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Subtitle label constraints
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Text field constraints
            barcodeTextField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            barcodeTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            barcodeTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            barcodeTextField.heightAnchor.constraint(equalToConstant: 60),
            barcodeTextField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            // Loading indicator
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func textFieldDidChange(_ textField: UITextField) {
        // Enable Done button only if text field is not empty
        navigationItem.rightBarButtonItem?.isEnabled = !(textField.text?.isEmpty ?? true)
    }

    // Handle return key on keyboard (optional)
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if !(textField.text?.isEmpty ?? true) {
            submitButtonTapped()
            return true
        }
        return false
    }

    @objc private func submitButtonTapped() {
        guard let barcode = barcodeTextField.text, !barcode.isEmpty else {
            print("DEBUG: Submit button tapped but barcode is empty")
            // Optionally show an alert if needed, though button should be disabled
            return
        }

        print("DEBUG: Submit button tapped with barcode: \(barcode)")
        
        // Immediately disable the navigation bar buttons to prevent multiple submissions
        navigationItem.leftBarButtonItem?.isEnabled = false
        navigationItem.rightBarButtonItem?.isEnabled = false
        view.endEditing(true) // Dismiss keyboard
        
        // Animate transition to loading state
        UIView.animate(withDuration: 0.3) {
            self.contentView.alpha = 0
            self.loadingIndicator.startAnimating()
            self.loadingIndicator.alpha = 1.0  // Ensure loading indicator is fully visible
            print("DEBUG: Loading indicator started animating")
        }
        
        print("DEBUG: About to call delegate.manualBarcodeEntryDidFinish")
        // Call delegate but DO NOT dismiss here
        delegate?.manualBarcodeEntryDidFinish(with: barcode)
        print("DEBUG: Delegate method called - waiting for NativeCameraViewController to handle it")
        // Dismissal will be handled by the NativeCameraViewController
    }

    @objc private func cancelButtonTapped() {
        delegate?.manualBarcodeEntryDidCancel()
        dismiss(animated: true, completion: nil) // Dismiss the modal NavController
    }
}
