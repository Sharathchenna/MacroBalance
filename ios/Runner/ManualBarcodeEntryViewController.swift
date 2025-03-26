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
    // Using Navigation Bar for Cancel/Done

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        barcodeTextField.becomeFirstResponder() // Show keyboard immediately
    }

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "Enter Barcode"

        // Navigation Bar Items
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(submitButtonTapped))
        navigationItem.rightBarButtonItem?.isEnabled = false // Disabled initially

        // Configure TextField
        barcodeTextField.translatesAutoresizingMaskIntoConstraints = false
        barcodeTextField.placeholder = "Enter barcode number"
        barcodeTextField.borderStyle = .roundedRect
        barcodeTextField.keyboardType = .numberPad // Use number pad
        barcodeTextField.clearButtonMode = .whileEditing
        barcodeTextField.delegate = self
        barcodeTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        barcodeTextField.font = UIFont.systemFont(ofSize: 24, weight: .regular) // Increased font size
        barcodeTextField.textAlignment = .center // Center align text
        view.addSubview(barcodeTextField)

        // Loading Indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = .gray
        view.addSubview(loadingIndicator)

        // Layout TextField & Indicator
        NSLayoutConstraint.activate([
            barcodeTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60), // More padding top
            barcodeTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30), // More padding horizontal
            barcodeTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            barcodeTextField.heightAnchor.constraint(equalToConstant: 60), // Increased height

            // Center loading indicator
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
            // Optionally show an alert if needed, though button should be disabled
            return
        }

        // --- Start Loading State ---
        barcodeTextField.isHidden = true
        navigationItem.leftBarButtonItem?.isEnabled = false
        navigationItem.rightBarButtonItem?.isEnabled = false
        loadingIndicator.startAnimating()
        view.endEditing(true) // Dismiss keyboard
        // --- End Loading State ---

        // Call delegate but DO NOT dismiss here
        delegate?.manualBarcodeEntryDidFinish(with: barcode)
        // Dismissal will be handled by the NativeCameraViewController
    }

    @objc private func cancelButtonTapped() {
        delegate?.manualBarcodeEntryDidCancel()
        dismiss(animated: true, completion: nil) // Dismiss the modal NavController
    }
}
