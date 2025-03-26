import UIKit
import AVFoundation
import Vision
import PhotosUI // For PHPickerViewController

// Delegate protocol to send results back to AppDelegate
protocol NativeCameraViewControllerDelegate: AnyObject {
    func nativeCameraDidFinish(withBarcode barcode: String)
    func nativeCameraDidFinish(withPhotoData photoData: Data)
    func nativeCameraDidCancel()
    // Add other necessary delegate methods (e.g., errors)
}

class NativeCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, PHPickerViewControllerDelegate, ManualBarcodeEntryDelegate {

    weak var delegate: NativeCameraViewControllerDelegate?

    // Camera Session Components
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var backCamera: AVCaptureDevice?
    private var currentCameraInput: AVCaptureDeviceInput?

    // State Management
    private let sessionQueue = DispatchQueue(label: "nativeCameraSessionQueue", qos: .userInitiated)
    private let videoDataOutputQueue = DispatchQueue(label: "nativeVideoDataOutputQueue", qos: .userInitiated)
    private var isContinuousBarcodeScanningEnabled = true // Default to true, reset in viewWillAppear
    private var isProcessingFrame = false
    private var hasSentResult = false // Flag to prevent sending multiple results
    private var currentZoomFactor: CGFloat = 1.0
    private var minZoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 1.0
    private var currentFlashMode: AVCaptureDevice.FlashMode = .off // For photo capture flash
    private var isSessionSetupComplete = false // Flag to prevent race condition

    // Vision Request for Barcodes
    private var barcodeRequest: VNDetectBarcodesRequest?

    // UI Elements (declare properties)
    private let previewView = UIView()
    private let shutterButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let flashButton = UIButton(type: .system)
    private let galleryButton = UIButton(type: .system)
    private let manualEntryButton = UIButton(type: .system)
    private let barcodeOverlayView = UIView() // Keep the view instance for constraints
    private let topBar = UIView()
    private let bottomBar = UIView()
    private let infoButton = UIButton(type: .system) // Info button
    private let instructionLabel = UILabel() // Instruction label

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black
        setupUI()
        setupVision()
        checkCameraPermissions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reset state when the view is about to appear
        hasSentResult = false
        isContinuousBarcodeScanningEnabled = true // Ensure scanning is enabled on appear
        // Only start if setup is fully complete to avoid race condition
        if isSessionSetupComplete {
             startSessionIfNeeded()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    // MARK: - Setup

    private func setupUI() {
        // Preview View (add first, send to back later)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)

        // Top Translucent Bar
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.addSubview(topBar)

        // Bottom Translucent Bar
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.addSubview(bottomBar)

        // Send preview to back AFTER adding bars
        view.sendSubviewToBack(previewView)

        // Close Button
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        topBar.addSubview(closeButton) // Add to topBar

        // Flash Button
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal) // Default: Off
        flashButton.tintColor = .white
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        topBar.addSubview(flashButton) // Add to topBar

        // Info Button
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.setImage(UIImage(systemName: "info.circle"), for: .normal)
        infoButton.tintColor = .white
        infoButton.addTarget(self, action: #selector(infoButtonTapped), for: .touchUpInside)
        topBar.addSubview(infoButton) // Add to topBar

        // Instruction Label
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.text = "Scan a barcode or take a photo"
        instructionLabel.textColor = .white
        instructionLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        instructionLabel.textAlignment = .center
        topBar.addSubview(instructionLabel) // Add to topBar

        // Shutter Button (for AI Photo)
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 40 // Adjust size
        shutterButton.layer.borderColor = UIColor.darkGray.cgColor // Darker border for contrast on white
        shutterButton.layer.borderWidth = 3
        shutterButton.addTarget(self, action: #selector(shutterButtonTapped), for: .touchUpInside)
        bottomBar.addSubview(shutterButton) // Add to bottomBar

        // Gallery Button
        galleryButton.translatesAutoresizingMaskIntoConstraints = false
        galleryButton.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
        galleryButton.tintColor = .white
        galleryButton.addTarget(self, action: #selector(galleryButtonTapped), for: .touchUpInside)
        bottomBar.addSubview(galleryButton) // Add to bottomBar

        // Manual Entry Button
        manualEntryButton.translatesAutoresizingMaskIntoConstraints = false
        manualEntryButton.setImage(UIImage(systemName: "keyboard"), for: .normal)
        manualEntryButton.tintColor = .white
        manualEntryButton.addTarget(self, action: #selector(manualEntryButtonTapped), for: .touchUpInside)
        bottomBar.addSubview(manualEntryButton) // Add to bottomBar

        // Barcode Overlay - Keep instance, make invisible
        barcodeOverlayView.translatesAutoresizingMaskIntoConstraints = false
        barcodeOverlayView.backgroundColor = .clear // Invisible
        // barcodeOverlayView.layer.borderColor = UIColor.red.cgColor // For debugging layout if needed
        // barcodeOverlayView.layer.borderWidth = 1 // For debugging layout if needed
        view.addSubview(barcodeOverlayView) // Add back to view hierarchy

        // --- Layout Constraints ---
        NSLayoutConstraint.activate([
            // Preview fills view
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Top Bar
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 140), // Increased height slightly

            // Bottom Bar
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 150), // Adjust height as needed

            // Close Button (within Top Bar Safe Area)
            closeButton.topAnchor.constraint(equalTo: topBar.safeAreaLayoutGuide.topAnchor, constant: 15),
            closeButton.leadingAnchor.constraint(equalTo: topBar.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            // Info Button (next to Flash Button)
            infoButton.centerYAnchor.constraint(equalTo: flashButton.centerYAnchor),
            infoButton.trailingAnchor.constraint(equalTo: flashButton.leadingAnchor, constant: -15), // Space between info and flash
            infoButton.widthAnchor.constraint(equalToConstant: 44),
            infoButton.heightAnchor.constraint(equalToConstant: 44),

            // Flash Button (within Top Bar Safe Area)
            flashButton.topAnchor.constraint(equalTo: topBar.safeAreaLayoutGuide.topAnchor, constant: 15),
            flashButton.trailingAnchor.constraint(equalTo: topBar.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            flashButton.widthAnchor.constraint(equalToConstant: 44),
            flashButton.heightAnchor.constraint(equalToConstant: 44),

            // Instruction Label (Near bottom of topBar, centered)
            instructionLabel.bottomAnchor.constraint(equalTo: topBar.safeAreaLayoutGuide.bottomAnchor, constant: -10), // Position near bottom of topBar safe area
            instructionLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            instructionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: topBar.leadingAnchor, constant: 20), // Prevent overlap
            instructionLabel.trailingAnchor.constraint(lessThanOrEqualTo: topBar.trailingAnchor, constant: -20), // Prevent overlap

            // Shutter Button (within Bottom Bar Safe Area)
            shutterButton.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: bottomBar.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            shutterButton.widthAnchor.constraint(equalToConstant: 80),
            shutterButton.heightAnchor.constraint(equalToConstant: 80),

            // Gallery Button (within Bottom Bar Safe Area)
            galleryButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            galleryButton.leadingAnchor.constraint(equalTo: bottomBar.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            galleryButton.widthAnchor.constraint(equalToConstant: 44),
            galleryButton.heightAnchor.constraint(equalToConstant: 44),

            // Manual Entry Button (within Bottom Bar Safe Area)
            manualEntryButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            manualEntryButton.trailingAnchor.constraint(equalTo: bottomBar.safeAreaLayoutGuide.trailingAnchor, constant: -40),
            manualEntryButton.widthAnchor.constraint(equalToConstant: 44),
            manualEntryButton.heightAnchor.constraint(equalToConstant: 44),

            // Barcode Overlay Constraints (Full width between bars)
            barcodeOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            barcodeOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            barcodeOverlayView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            barcodeOverlayView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor)
        ])
    }

    private func setupVision() {
        barcodeRequest = VNDetectBarcodesRequest(completionHandler: handleBarcodes)
        // Configure symbologies if needed
    }

    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupSession()
                    } else {
                        self?.showPermissionError("Camera access denied.")
                    }
                }
            }
        case .denied, .restricted:
            showPermissionError("Camera access previously denied or restricted.")
        @unknown default:
            fatalError("Unknown camera authorization status")
        }
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession == nil else { return }

            self.captureSession = AVCaptureSession()
            self.captureSession?.sessionPreset = .photo // High quality for potential photos

            // Find back camera
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.reportError("Could not find back camera.")
                return
            }
            self.backCamera = camera
            do {
                self.currentCameraInput = try AVCaptureDeviceInput(device: camera)
            } catch {
                self.reportError("Could not create camera input: \(error)")
                return
            }

            guard let input = self.currentCameraInput else { return }

            self.captureSession?.beginConfiguration()

            if self.captureSession?.canAddInput(input) ?? false {
                self.captureSession?.addInput(input)
            } else {
                self.reportError("Could not add camera input.")
                self.captureSession?.commitConfiguration()
                return
            }

            // Video Data Output (for barcode scanning)
            self.videoDataOutput = AVCaptureVideoDataOutput()
            self.videoDataOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            self.videoDataOutput?.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutput?.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)
            if self.captureSession?.canAddOutput(self.videoDataOutput!) ?? false {
                self.captureSession?.addOutput(self.videoDataOutput!)
                if let connection = self.videoDataOutput?.connection(with: .video), connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            } else {
                self.reportError("Could not add video data output.")
            }

            // Photo Output
            self.photoOutput = AVCapturePhotoOutput()
            if self.captureSession?.canAddOutput(self.photoOutput!) ?? false {
                self.captureSession?.addOutput(self.photoOutput!)
            } else {
                self.reportError("Could not add photo output.")
            }

            self.captureSession?.commitConfiguration()

            // Mark setup as complete before dispatching UI/start tasks
            self.isSessionSetupComplete = true

            // Setup Preview Layer on Main Thread
            DispatchQueue.main.async {
                self.setupPreviewLayer()
                // Get zoom capabilities
                self.minZoomFactor = camera.minAvailableVideoZoomFactor
                self.maxZoomFactor = camera.maxAvailableVideoZoomFactor
            }

            // Don't start session here yet. Start after preview layer is set up.
            // self.startSessionIfNeeded()

            // Dispatch back to session queue AFTER main thread preview setup to start session
            DispatchQueue.main.async {
                self.setupPreviewLayer()
                // Get zoom capabilities
                self.minZoomFactor = camera.minAvailableVideoZoomFactor
                self.maxZoomFactor = camera.maxAvailableVideoZoomFactor

                // Now that preview is ready, start the session on its queue
                self.sessionQueue.async {
                    self.startSessionIfNeeded()
                }
            }
        }
    }


    private func setupPreviewLayer() {
        guard let session = captureSession else { return }
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = previewView.bounds // Use bounds of the dedicated preview view
        if let layer = previewLayer {
            previewView.layer.addSublayer(layer)
        }
    }

     override func viewDidLayoutSubviews() {
         super.viewDidLayoutSubviews()
         previewLayer?.frame = previewView.bounds // Ensure preview layer resizes
     }

    private func startSessionIfNeeded() {
        sessionQueue.async {
            if !(self.captureSession?.isRunning ?? false) {
                self.captureSession?.startRunning()
                print("Native Camera Session Started")
            }
        }
    }

    private func stopSession() {
        sessionQueue.async {
            if self.captureSession?.isRunning ?? false {
                self.captureSession?.stopRunning()
                print("Native Camera Session Stopped")
            }
        }
    }

    // MARK: - Actions

    @objc private func closeButtonTapped() {
        dismiss(animated: true) { [weak self] in
            self?.delegate?.nativeCameraDidCancel()
        }
    }

    @objc private func flashButtonTapped() {
        guard let device = backCamera, device.hasTorch else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                if device.torchMode == .on {
                    device.torchMode = .off
                    DispatchQueue.main.async { self.flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal) }
                } else {
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                    DispatchQueue.main.async { self.flashButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal) }
                }
                device.unlockForConfiguration()
            } catch {
                print("Error toggling torch: \(error)")
            }
        }
    }

    @objc private func infoButtonTapped() {
        let title = "Camera Help"

        // Define attributes for styling
        let boldFont = UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)
        let regularFont = UIFont.systemFont(ofSize: UIFont.systemFontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 8 // Add space between paragraphs

        let boldAttributes: [NSAttributedString.Key: Any] = [.font: boldFont, .paragraphStyle: paragraphStyle]
        let regularAttributes: [NSAttributedString.Key: Any] = [.font: regularFont, .paragraphStyle: paragraphStyle]

        // Create attributed string
        let attributedMessage = NSMutableAttributedString()

        attributedMessage.append(NSAttributedString(string: "📷 How to Use:\n", attributes: boldAttributes))

        attributedMessage.append(NSAttributedString(string: "Barcode Scanning:\n", attributes: boldAttributes))
        attributedMessage.append(NSAttributedString(string: "Align the product's barcode within the frame. The app will automatically detect it.\n\n", attributes: regularAttributes))

        attributedMessage.append(NSAttributedString(string: "Food AI Analysis:\n", attributes: boldAttributes))
        attributedMessage.append(NSAttributedString(string: "Position the food item clearly and tap the white shutter button.\n\n", attributes: regularAttributes))

        attributedMessage.append(NSAttributedString(string: "❗️ Disclaimer:\n", attributes: boldAttributes))
        attributedMessage.append(NSAttributedString(string: "AI-generated nutritional information provides estimates only. Please verify accuracy, especially for specific dietary needs or allergies.", attributes: regularAttributes))


        // Create alert controller
        let alert = UIAlertController(title: title, message: "", preferredStyle: .alert) // Set message to empty initially

        // Use KVC to set the attributed message (unofficial but often works)
        alert.setValue(attributedMessage, forKey: "attributedMessage")

        // Add action
        let okAction = UIAlertAction(title: "Got it!", style: .default, handler: nil)
        alert.addAction(okAction)

        present(alert, animated: true, completion: nil)
    }

    @objc private func shutterButtonTapped() {
        print("Shutter tapped - Capturing photo for AI...")
        capturePhoto()
    }

    @objc private func galleryButtonTapped() {
        print("Gallery button tapped")
        var config = PHPickerConfiguration()
        config.filter = .images // Only allow images
        config.selectionLimit = 1 // Only one image
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func manualEntryButtonTapped() {
        print("Manual entry button tapped")
        let manualVC = ManualBarcodeEntryViewController()
        manualVC.delegate = self
        // Present modally or push onto navigation stack
        let navController = UINavigationController(rootViewController: manualVC) // Wrap in Nav Controller for title/bar
        present(navController, animated: true)
    }

    // MARK: - Barcode Scanning (Vision)

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isContinuousBarcodeScanningEnabled, !isProcessingFrame else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        isProcessingFrame = true
        let imageOrientation = CGImagePropertyOrientation.right // Assuming portrait

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: imageOrientation, options: [:])
        do {
            try handler.perform([barcodeRequest!])
        } catch {
            print("Failed to perform Vision request: \(error)")
            isProcessingFrame = false
        }
    }

    private func handleBarcodes(request: VNRequest, error: Error?) {
        defer { isProcessingFrame = false }

        guard let results = request.results as? [VNBarcodeObservation], error == nil,
              let barcode = results.first?.payloadStringValue else {
            // No barcode found in this frame, continue scanning
            return
        }

        // Barcode found! Check if we already sent a result for this presentation
        guard !hasSentResult else {
            print("Native Vision Detected Barcode (\(barcode)), but result already sent.")
            return
        }
        hasSentResult = true // Mark result as sent
        print("Native Vision Detected Barcode: \(barcode)")
        isContinuousBarcodeScanningEnabled = false // Stop scanning after finding one
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate)) // Vibrate feedback

        // Send result back via delegate (on main thread)
        DispatchQueue.main.async { [weak self] in
             self?.dismiss(animated: true) {
                 self?.delegate?.nativeCameraDidFinish(withBarcode: barcode)
             }
        }
    }

    // MARK: - Photo Capture

    private func capturePhoto() {
        // Check if we already sent a result for this presentation
        guard !hasSentResult else {
            print("Capture photo requested, but result already sent.")
            return
        }
        guard let photoOutput = self.photoOutput else {
            reportError("Photo output not available.")
            return
        }

        sessionQueue.async {
            var format: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.jpeg]
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                format = [AVVideoCodecKey: AVVideoCodecType.hevc]
            }
            let photoSettings = AVCapturePhotoSettings(format: format)

            // Use flash setting based on torch state? Or dedicated photo flash?
            // For simplicity, let's use the torch state for now.
            if self.backCamera?.torchMode == .on {
                 if photoOutput.supportedFlashModes.contains(.on) {
                     photoSettings.flashMode = .on
                 }
            } else {
                 if photoOutput.supportedFlashModes.contains(.off) {
                     photoSettings.flashMode = .off
                 }
            }

            photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            reportError("Error capturing photo: \(error.localizedDescription)")
            return
        }

        guard let photoData = photo.fileDataRepresentation() else {
            reportError("Could not get photo data.")
            return
        }

        // Mark result as sent before dismissing and calling delegate
        hasSentResult = true
        print("Native Photo captured successfully.")

        // Send photo data back via delegate
        DispatchQueue.main.async { [weak self] in
             self?.dismiss(animated: true) {
                 self?.delegate?.nativeCameraDidFinish(withPhotoData: photoData)
             }
        }
    }

    // MARK: - PHPickerViewControllerDelegate (Gallery)

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard !hasSentResult, let provider = results.first?.itemProvider else {
             print("Gallery picker finished, but result already sent or no provider.")
             return
        }

        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                 guard let self = self, !self.hasSentResult else { return } // Double check flag

                guard let uiImage = image as? UIImage, let photoData = uiImage.jpegData(compressionQuality: 0.8) else { // Compress to JPEG
                    self.reportError("Could not load image from gallery or convert to data.")
                    return
                }

                self.hasSentResult = true // Mark result as sent
                print("Native Image selected from gallery.")

                // Send photo data back via delegate
                DispatchQueue.main.async {
                     self.dismiss(animated: true) { // Dismiss camera VC as well
                         self.delegate?.nativeCameraDidFinish(withPhotoData: photoData)
                     }
                }
            }
        } else {
             reportError("Selected item cannot be loaded as an image.")
        }
    }

     // MARK: - ManualBarcodeEntryDelegate

     func manualBarcodeEntryDidFinish(with barcode: String) {
         // Check if we already sent a result for this presentation
         guard !hasSentResult else {
             print("Manual barcode entry finished, but result already sent.")
             // If already sent, just dismiss self (which includes the presented manual VC)
             dismiss(animated: true, completion: nil)
             return
         }
         hasSentResult = true // Mark result as sent
         print("Manual Barcode Entered: \(barcode)")

         // Dismiss the NativeCameraViewController (self) which also dismisses the presented ManualBarcodeEntryViewController
         dismiss(animated: true) { [weak self] in
             self?.delegate?.nativeCameraDidFinish(withBarcode: barcode)
         }
     }

     func manualBarcodeEntryDidCancel() {
         print("Manual Barcode Entry Cancelled")
         // Just dismiss the manual entry screen, keep camera open
     }


    // MARK: - Error Handling

    private func showPermissionError(_ message: String) {
        print("Permission Error: \(message)")
        // Show an alert to the user
        let alert = UIAlertController(title: "Camera Access Required", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.dismiss(animated: true) {
                self?.delegate?.nativeCameraDidCancel() // Notify delegate on cancel
            }
        })
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            // Open app settings
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
             // Dismiss camera VC after attempting to open settings
             self.dismiss(animated: true) {
                 self.delegate?.nativeCameraDidCancel()
             }
        })
        present(alert, animated: true)
    }

    private func reportError(_ message: String) {
        print("Native Camera Error: \(message)")
        // Optionally show an alert or send error back via delegate
        // For now, just print
    }
}
