import UIKit
import AVFoundation
import Vision
import PhotosUI // For PHPickerViewController

// Mirror the Flutter enum
enum CameraMode: String {
    case barcode = "barcode"
    case camera = "camera"
    case label = "label"
}

// Delegate protocol to send results back to AppDelegate
protocol NativeCameraViewControllerDelegate: AnyObject {
    func nativeCameraDidFinish(withBarcode barcode: String, mode: CameraMode) // Add mode
    func nativeCameraDidFinish(withPhotoData photoData: Data, mode: CameraMode) // Add mode
    func nativeCameraDidCancel()
    // Add other necessary delegate methods (e.g., errors)
}

class NativeCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, PHPickerViewControllerDelegate, ManualBarcodeEntryDelegate {

    weak var delegate: NativeCameraViewControllerDelegate?
    var initialMode: CameraMode = .camera // Default, will be set externally

    // Camera Session Components
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var backCamera: AVCaptureDevice?
    private var currentCameraInput: AVCaptureDeviceInput?

    // State Management
    private let sessionQueue = DispatchQueue(label: "nativeCameraSessionQueue", qos: .userInitiated)
    private let videoDataOutputQueue = DispatchQueue(label: "nativeVideoDataOutputQueue") // Removed qos for potential main thread interaction later if needed for UI updates from barcode handler
    private var isContinuousBarcodeScanningEnabled = true // Default to true, reset in viewWillAppear
    private var isProcessingFrame = false
    private var hasSentResult = false // Flag to prevent sending multiple results
    private var currentZoomFactor: CGFloat = 1.0
    private var minZoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 1.0
    private var currentFlashMode: AVCaptureDevice.FlashMode = .off // For photo capture flash
    private var isSessionSetupComplete = false // Flag to prevent race condition
    private var currentMode: CameraMode = .camera // Initialize with default

    // Vision Request for Barcodes
    private var barcodeRequest: VNDetectBarcodesRequest?

    // UI Elements (declare properties)
    private let previewView = UIView()
    private let shutterButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .custom) // Changed to custom for more styling options
    private let flashButton = UIButton(type: .custom) // Changed to custom for more styling options
    private let galleryButton = UIButton(type: .custom) // Changed to custom for more styling options
    private let manualEntryButton = UIButton(type: .custom) // Changed to custom for more styling options
    private let topBar = UIView()
    private let buttonsContainer = UIView() // Replace bottom bar with floating container
    private let infoButton = UIButton(type: .custom) // Changed to custom for more styling options
    private let instructionLabel = UILabel() // Instruction label
    
    // Initialize segmented control with icons
    private let modeSegmentedControl = UISegmentedControl(items: [
        UIImage(systemName: "barcode.viewfinder") ?? "Barcode", // Fallback text
        UIImage(systemName: "camera.fill") ?? "Camera",       // Fallback text
        UIImage(systemName: "text.viewfinder") ?? "Label"        // Fallback text
    ])
    private let barcodeScanGuideView = UIView() // Visual guide for barcode scanning
    private let labelScanGuideView = UIView() // Visual guide for label scanning

    // Haptic Feedback Generator
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium) // Prepare generator
    
    // Premium UI Colors
    private let accentColor = UIColor(red: 0.28, green: 0.72, blue: 0.82, alpha: 1.0) // Sky blue accent
    private let premiumGoldColor = UIColor(red: 0.93, green: 0.79, blue: 0.33, alpha: 1.0) // Rich gold
    private let darkOverlayColor = UIColor.black.withAlphaComponent(0.4) // Translucent overlay
    private let premiumBackgroundColor = UIColor(white: 0.12, alpha: 0.85) // Premium dark background

    // Add new property for product lookup state
    private var isLookingUpProduct = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black
        setupUI()
        currentMode = initialMode // Set current mode from initial value
        setupVision()
        checkCameraPermissions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reset state when the view is about to appear
        hasSentResult = false
        // Only start if setup is fully complete to avoid race condition
        if isSessionSetupComplete {
             startSessionIfNeeded()
             updateUIForCurrentMode() // Ensure UI matches mode on appear
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

        // Top Translucent Bar (with premium glassmorphism effect)
        topBar.translatesAutoresizingMaskIntoConstraints = false
        // Use blur effect for a premium glassmorphism look
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(blurView)

        // Add subtle gradient overlay to blur for depth
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.4).cgColor,
            UIColor.black.withAlphaComponent(0.2).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]

        // Create a container for the gradient
        let gradientView = UIView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.backgroundColor = .clear
        topBar.addSubview(gradientView)
        gradientView.layer.insertSublayer(gradientLayer, at: 0)

        // Add subtle border at bottom of top bar for premium feel
        let borderView = UIView()
        borderView.translatesAutoresizingMaskIntoConstraints = false
        borderView.backgroundColor = premiumGoldColor.withAlphaComponent(0.2)
        topBar.addSubview(borderView)

        view.addSubview(topBar)

        // Floating buttons container (replacing bottom bar)
        buttonsContainer.translatesAutoresizingMaskIntoConstraints = false
        buttonsContainer.backgroundColor = .clear // Container is transparent
        view.addSubview(buttonsContainer)

        // Send preview to back
        view.sendSubviewToBack(previewView)

        // Close Button (premium floating style)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = premiumBackgroundColor
        closeButton.layer.cornerRadius = 22 // Make it circular
        closeButton.layer.borderWidth = 1.0
        closeButton.layer.borderColor = premiumGoldColor.withAlphaComponent(0.2).cgColor // Subtle gold border
        closeButton.layer.shadowColor = UIColor.black.cgColor
        closeButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        closeButton.layer.shadowOpacity = 0.4
        closeButton.layer.shadowRadius = 4
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        topBar.addSubview(closeButton)

        // Flash Button (premium floating style with better icon)
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        let flashConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        flashButton.setImage(UIImage(systemName: "bolt.slash.fill", withConfiguration: flashConfig), for: .normal)
        flashButton.tintColor = premiumGoldColor // Use gold color for flash icon
        flashButton.backgroundColor = premiumBackgroundColor
        flashButton.layer.cornerRadius = 22 // Make it circular
        flashButton.layer.borderWidth = 1.0
        flashButton.layer.borderColor = premiumGoldColor.withAlphaComponent(0.2).cgColor
        flashButton.layer.shadowColor = UIColor.black.cgColor
        flashButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        flashButton.layer.shadowOpacity = 0.4
        flashButton.layer.shadowRadius = 4
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        topBar.addSubview(flashButton)

        // Info Button (premium floating style)
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        let infoConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        infoButton.setImage(UIImage(systemName: "info.circle.fill", withConfiguration: infoConfig), for: .normal)
        infoButton.tintColor = .white
        infoButton.backgroundColor = premiumBackgroundColor
        infoButton.layer.cornerRadius = 22 // Make it circular
        infoButton.layer.borderWidth = 1.0
        infoButton.layer.borderColor = premiumGoldColor.withAlphaComponent(0.2).cgColor
        infoButton.layer.shadowColor = UIColor.black.cgColor
        infoButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        infoButton.layer.shadowOpacity = 0.4
        infoButton.layer.shadowRadius = 4
        infoButton.addTarget(self, action: #selector(infoButtonTapped), for: .touchUpInside)
        topBar.addSubview(infoButton)

        // Instruction Label with premium styling
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.textColor = .white
        instructionLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 0
        // Add subtle shadow effects for a premium feel
        instructionLabel.layer.shadowColor = UIColor.black.cgColor
        instructionLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        instructionLabel.layer.shadowOpacity = 0.5
        instructionLabel.layer.shadowRadius = 3
        topBar.addSubview(instructionLabel)

        // Mode Segmented Control (premium floating style)
        modeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        modeSegmentedControl.selectedSegmentIndex = modeToIndex(initialMode)
        modeSegmentedControl.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        modeSegmentedControl.backgroundColor = premiumBackgroundColor
        // Use premium gold color for selected segment
        modeSegmentedControl.selectedSegmentTintColor = premiumGoldColor
        modeSegmentedControl.layer.cornerRadius = 16 // More rounded corners
        modeSegmentedControl.clipsToBounds = true
        // Add subtle border and shadow for floating feel
        modeSegmentedControl.layer.borderWidth = 0.5
        modeSegmentedControl.layer.borderColor = premiumGoldColor.withAlphaComponent(0.3).cgColor
        // Set text color for normal and selected states
        modeSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        modeSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected) // Darker text for better contrast with gold
        // Add premium shadow
        modeSegmentedControl.layer.shadowColor = UIColor.black.cgColor
        modeSegmentedControl.layer.shadowOffset = CGSize(width: 0, height: 3)
        modeSegmentedControl.layer.shadowOpacity = 0.4
        modeSegmentedControl.layer.shadowRadius = 6
        view.addSubview(modeSegmentedControl) // Add to main view

        // Shutter Button (premium floating style)
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 38 // Large circular button
        shutterButton.layer.shadowColor = UIColor.black.cgColor
        shutterButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        shutterButton.layer.shadowOpacity = 0.3
        shutterButton.layer.shadowRadius = 5
        
        // Make the button respond better to touches
        shutterButton.isUserInteractionEnabled = true
        
        // Use tintColor to make it clear this is an interactive element
        shutterButton.tintColor = .lightGray
        
        // Add inner circle as an image instead of a subview for better touch handling
        let circleConfig = UIImage.SymbolConfiguration(pointSize: 50, weight: .regular)
        let circleImage = UIImage(systemName: "circle.fill", withConfiguration: circleConfig)
        shutterButton.setImage(circleImage, for: .normal)
        
        // Set button's touch-down state for better feedback
        shutterButton.showsTouchWhenHighlighted = true
                
        shutterButton.addTarget(self, action: #selector(shutterButtonTapped), for: .touchUpInside)
        // Add additional touch events to ensure the button is responsive
        shutterButton.addTarget(self, action: #selector(shutterButtonTouchDown), for: .touchDown)
        
        buttonsContainer.addSubview(shutterButton)

        // Gallery Button (floating island style)
        galleryButton.translatesAutoresizingMaskIntoConstraints = false
        galleryButton.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
        galleryButton.tintColor = .white
        galleryButton.backgroundColor = darkOverlayColor
        galleryButton.layer.cornerRadius = 24
        galleryButton.layer.shadowColor = UIColor.black.cgColor
        galleryButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        galleryButton.layer.shadowOpacity = 0.3
        galleryButton.layer.shadowRadius = 3
        galleryButton.addTarget(self, action: #selector(galleryButtonTapped), for: .touchUpInside)
        buttonsContainer.addSubview(galleryButton)

        // Manual Entry Button (floating island style)
        manualEntryButton.translatesAutoresizingMaskIntoConstraints = false
        manualEntryButton.setImage(UIImage(systemName: "keyboard"), for: .normal)
        manualEntryButton.tintColor = .white
        manualEntryButton.backgroundColor = darkOverlayColor
        manualEntryButton.layer.cornerRadius = 24
        manualEntryButton.layer.shadowColor = UIColor.black.cgColor
        manualEntryButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        manualEntryButton.layer.shadowOpacity = 0.3
        manualEntryButton.layer.shadowRadius = 3
        manualEntryButton.addTarget(self, action: #selector(manualEntryButtonTapped), for: .touchUpInside)
        buttonsContainer.addSubview(manualEntryButton)

        // Barcode Scan Guide View (enhanced with subtle glow and premium gold color)
        barcodeScanGuideView.translatesAutoresizingMaskIntoConstraints = false
        barcodeScanGuideView.backgroundColor = .clear
        barcodeScanGuideView.layer.borderColor = premiumGoldColor.cgColor // Change to premium gold color
        barcodeScanGuideView.layer.borderWidth = 3 // Make border thicker for better visibility
        barcodeScanGuideView.layer.cornerRadius = 12 // More rounded corners
        barcodeScanGuideView.layer.shadowColor = premiumGoldColor.cgColor // Gold shadow
        barcodeScanGuideView.layer.shadowOffset = .zero
        barcodeScanGuideView.layer.shadowOpacity = 0.5 // Increased opacity for better visibility
        barcodeScanGuideView.layer.shadowRadius = 6 // Increased radius for a more noticeable glow
        barcodeScanGuideView.isHidden = true // Initially hidden
        view.addSubview(barcodeScanGuideView)

        // Label Scan Guide View (enhanced with subtle glow)
        labelScanGuideView.translatesAutoresizingMaskIntoConstraints = false
        labelScanGuideView.backgroundColor = .clear
        labelScanGuideView.layer.borderColor = premiumGoldColor.cgColor // Use premium gold color color
        labelScanGuideView.layer.borderWidth = 3
        labelScanGuideView.layer.cornerRadius = 12 // More rounded corners
        labelScanGuideView.layer.shadowColor = premiumGoldColor.cgColor
        labelScanGuideView.layer.shadowOffset = .zero
        labelScanGuideView.layer.shadowOpacity = 0.5
        labelScanGuideView.layer.shadowRadius = 6
        labelScanGuideView.isHidden = true // Initially hidden
        view.addSubview(labelScanGuideView)

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

            // Floating buttons container
            buttonsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            buttonsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonsContainer.heightAnchor.constraint(equalToConstant: 80),

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

            // Instruction Label (Centered in Top Bar)
            instructionLabel.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 15), // Below buttons
            instructionLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            instructionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: topBar.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(lessThanOrEqualTo: topBar.trailingAnchor, constant: -20),
            instructionLabel.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -15), // Bottom padding

            // Shutter Button (centered in floating container)
            shutterButton.centerXAnchor.constraint(equalTo: buttonsContainer.centerXAnchor),
            shutterButton.centerYAnchor.constraint(equalTo: buttonsContainer.centerYAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: 76),
            shutterButton.heightAnchor.constraint(equalToConstant: 76),

            // Gallery Button (left floating island)
            galleryButton.centerYAnchor.constraint(equalTo: buttonsContainer.centerYAnchor),
            galleryButton.leadingAnchor.constraint(equalTo: buttonsContainer.leadingAnchor, constant: 10),
            galleryButton.widthAnchor.constraint(equalToConstant: 48),
            galleryButton.heightAnchor.constraint(equalToConstant: 48),

            // Manual Entry Button (right floating island)
            manualEntryButton.centerYAnchor.constraint(equalTo: buttonsContainer.centerYAnchor),
            manualEntryButton.trailingAnchor.constraint(equalTo: buttonsContainer.trailingAnchor, constant: -10),
            manualEntryButton.widthAnchor.constraint(equalToConstant: 48),
            manualEntryButton.heightAnchor.constraint(equalToConstant: 48),

            // Mode Segmented Control (Above Floating Container)
            modeSegmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeSegmentedControl.bottomAnchor.constraint(equalTo: buttonsContainer.topAnchor, constant: -20),
            modeSegmentedControl.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
            modeSegmentedControl.heightAnchor.constraint(equalToConstant: 40),

            // Barcode Scan Guide Constraints (Small rectangle in center)
            barcodeScanGuideView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            barcodeScanGuideView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            barcodeScanGuideView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7),
            barcodeScanGuideView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.15),

            // Label Scan Guide Constraints (Larger rectangle in center)
            labelScanGuideView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            labelScanGuideView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            labelScanGuideView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            labelScanGuideView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4),

            // Blur effect view fills top bar
            blurView.topAnchor.constraint(equalTo: topBar.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: topBar.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            
            // Gradient view fills top bar
            gradientView.topAnchor.constraint(equalTo: topBar.topAnchor),
            gradientView.bottomAnchor.constraint(equalTo: topBar.bottomAnchor),
            gradientView.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            
            // Bottom border
            borderView.heightAnchor.constraint(equalToConstant: 1),
            borderView.bottomAnchor.constraint(equalTo: topBar.bottomAnchor),
            borderView.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
        ])
        
        // Make sure top bar extends below safe area for notched devices
        let topBarHeightConstraint = instructionLabel.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -15)
        topBarHeightConstraint.priority = .defaultHigh
        topBarHeightConstraint.isActive = true
    }

    // MARK: - Vision and Setup Methods
    
    private func setupVision() {
        barcodeRequest = VNDetectBarcodesRequest(completionHandler: handleBarcodes)
        // Configure barcode symbologies if needed
        // barcodeRequest?.symbologies = [.ean13, .qr, .upce, .code128]
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
                if let connection = self.videoDataOutput?.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }
            } else {
                self.reportError("Could not add video data output to session.")
                self.captureSession?.commitConfiguration()
                return
            }

            // Photo Output (for camera mode)
            self.photoOutput = AVCapturePhotoOutput()
            if self.captureSession?.canAddOutput(self.photoOutput!) ?? false {
                self.captureSession?.addOutput(self.photoOutput!)
            } else {
                self.reportError("Could not add photo output to session.")
                // Don't return, proceed with configuration if possible
            }

            self.captureSession?.commitConfiguration()

            // Get zoom capabilities
            self.minZoomFactor = camera.minAvailableVideoZoomFactor
            self.maxZoomFactor = camera.maxAvailableVideoZoomFactor

            // Dispatch back to session queue AFTER main thread preview setup to start session
            DispatchQueue.main.async {
                self.setupPreviewLayer()
                self.isSessionSetupComplete = true

                // Now that preview is ready, update UI for initial mode and start the session
                self.updateUIForCurrentMode() // Update UI based on initialMode
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

    // MARK: - Session Management
    
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
    
    private func reportError(_ message: String) {
        print("Camera Error: \(message)")
        DispatchQueue.main.async {
            self.showPermissionError(message)
        }
    }
    
    private func showPermissionError(_ message: String) {
        let alert = UIAlertController(
            title: "Camera Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    // MARK: - UI Actions
    
    @objc private func closeButtonTapped() {
        hapticGenerator.impactOccurred()
        // Only dismiss if not already sent a result
        if !hasSentResult {
            hasSentResult = true
            delegate?.nativeCameraDidCancel()
        }
        dismiss(animated: true)
    }
    
    @objc private func flashButtonTapped() {
        hapticGenerator.impactOccurred()
        
        guard let device = backCamera else { return }
        
        do {
            try device.lockForConfiguration()
            
            // Toggle flash/torch mode with animation
            if device.hasTorch {
                switch device.torchMode {
                case .off:
                    if device.isTorchModeSupported(.on) {
                        // Create a subtle animation for turning on the flash
                        UIView.animate(withDuration: 0.2, animations: {
                            self.flashButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                            self.flashButton.backgroundColor = self.premiumGoldColor.withAlphaComponent(0.3)
                        }) { _ in
                            UIView.animate(withDuration: 0.2) {
                                self.flashButton.transform = CGAffineTransform.identity
                                self.flashButton.backgroundColor = self.premiumBackgroundColor
                            }
                        }
                        
                        device.torchMode = .on
                        // Use a brighter gold icon for "on" state
                        let flashOnConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
                        flashButton.setImage(UIImage(systemName: "bolt.fill", withConfiguration: flashOnConfig), for: .normal)
                        flashButton.tintColor = premiumGoldColor
                    }
                case .on:
                    // Create a subtle animation for turning off the flash
                    UIView.animate(withDuration: 0.15, animations: {
                        self.flashButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                    }) { _ in
                        UIView.animate(withDuration: 0.15) {
                            self.flashButton.transform = CGAffineTransform.identity
                        }
                    }
                    
                    device.torchMode = .off
                    let flashOffConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
                    flashButton.setImage(UIImage(systemName: "bolt.slash.fill", withConfiguration: flashOffConfig), for: .normal)
                    flashButton.tintColor = premiumGoldColor.withAlphaComponent(0.8)
                @unknown default:
                    break
                }
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Could not toggle flash: \(error)")
        }
    }
    
    @objc private func infoButtonTapped() {
        hapticGenerator.impactOccurred()
        
        // Create a custom alert with premium styling
        let alert = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .alert
        )
        
        // Configure title, message, and AI disclaimer based on current mode
        let titleFont = UIFont.systemFont(ofSize: 18, weight: .bold)
        let messageFont = UIFont.systemFont(ofSize: 14, weight: .regular)
        let disclaimerFont = UIFont.systemFont(ofSize: 12, weight: .light)
        
        let titleColor = UIColor.white
        let messageColor = UIColor.white
        let disclaimerColor = UIColor.systemRed.withAlphaComponent(0.8)
        
        // Mode-specific content
        let title: String
        let message: String
        let disclaimer: String
        
        switch currentMode {
        case .barcode:
            title = "Barcode Scanner"
            message = "Position the barcode within the highlighted area. Hold the device steady, and the scanner will automatically detect and process valid barcodes."
            disclaimer = "Note: Some barcodes may not be recognized. You can use manual entry if scanning fails."
            
        case .camera:
            title = "Photo Mode"
            message = "Take a clear photo of your food or product. Make sure there's good lighting for best results."
            disclaimer = "AI results are estimates and should be verified for accuracy."
            
        case .label:
            title = "Nutrition Label Scanner"
            message = "Position the entire nutrition label within the highlighted area. Try to capture the full label with good lighting for best results."
            disclaimer = "AI results are estimates and should be verified for accuracy."
        }
        
        // Create attributed strings with custom styling
        let attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: titleFont,
                .foregroundColor: titleColor
            ]
        )
        
        let attributedMessage = NSMutableAttributedString(
            string: message,
            attributes: [
                .font: messageFont,
                .foregroundColor: messageColor
            ]
        )
        
        // Add disclaimer with spacing
        attributedMessage.append(NSAttributedString(string: "\n\n"))
        attributedMessage.append(NSAttributedString(
            string: disclaimer,
            attributes: [
                .font: disclaimerFont,
                .foregroundColor: disclaimerColor
            ]
        ))
        
        // Set attributed strings
        alert.setValue(attributedTitle, forKey: "attributedTitle")
        alert.setValue(attributedMessage, forKey: "attributedMessage")
        
        // Add OK button
        alert.addAction(UIAlertAction(
            title: "Got it",
            style: .default,
            handler: nil
        ))
        
        // Present the alert
        present(alert, animated: true)
    }
    
    @objc private func modeChanged(_ sender: UISegmentedControl) {
        let selectedMode: CameraMode
        switch sender.selectedSegmentIndex {
        case 0: selectedMode = .barcode
        case 1: selectedMode = .camera
        case 2: selectedMode = .label
        default: selectedMode = .camera // Fallback
        }

        if selectedMode != currentMode {
            currentMode = selectedMode
            updateUIForCurrentMode()
            hapticGenerator.impactOccurred()
        }
    }
    
    private func updateUIForCurrentMode() {
        // Update instruction text and guide visibility based on mode
        switch currentMode {
        case .barcode:
            updateInstructionLabelText("Scan a barcode")
            barcodeScanGuideView.isHidden = false
            labelScanGuideView.isHidden = true
            isContinuousBarcodeScanningEnabled = true
        case .camera:
            updateInstructionLabelText("Take a photo")
            barcodeScanGuideView.isHidden = true
            labelScanGuideView.isHidden = true
            isContinuousBarcodeScanningEnabled = false
        case .label:
            updateInstructionLabelText("Scan a nutrition label")
            barcodeScanGuideView.isHidden = true
            labelScanGuideView.isHidden = false
            isContinuousBarcodeScanningEnabled = false
        }
    }
    
    @objc private func shutterButtonTapped() {
        // Prepare haptic before using it
        hapticGenerator.prepare()
        hapticGenerator.impactOccurred(intensity: 1.0)
        
        print("Shutter button tapped in mode: \(currentMode)")
        
        // Visual feedback for button press
        UIView.animate(withDuration: 0.1, animations: {
            self.shutterButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.shutterButton.transform = CGAffineTransform.identity
            }
        }
        
        switch currentMode {
        case .camera: // Regular photo mode
            guard let photoOutput = photoOutput else {
                print("Error: Photo output not initialized")
                showPermissionError("Camera not properly initialized")
                return
            }
            
            // Configure the photo settings
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.flashMode = currentFlashMode
            
            print("Taking photo with settings: \(photoSettings)")
            
            // Capture the photo
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
            
        case .label: // Label scanning mode - should capture photo and send to Gemini
            guard let photoOutput = photoOutput else {
                print("Error: Photo output not initialized")
                showPermissionError("Camera not properly initialized")
                return
            }
            
            print("Taking label photo for Gemini analysis")
            
            // Configure the photo settings - use highest quality for label recognition
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.flashMode = currentFlashMode
            
            // For highest quality, using the previewPhotoPixelFormatType
            // The AVCapturePhotoSettings doesn't directly have a jpegPhotoQuality property
            if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                // If HEVC is available, use it for potentially better quality
                let format: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.hevc
                ]
                // Create HEVC settings - this constructor doesn't return an optional
                let hevcSettings = AVCapturePhotoSettings(format: format)
                hevcSettings.previewPhotoFormat = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                
                // Mark that we're handling a label scan
                hasSentResult = true
                
                // Capture the photo with HEVC format
                photoOutput.capturePhoto(with: hevcSettings, delegate: self)
                return
            }
            
            // Fallback to highest quality JPEG if HEVC isn't available or fails
            photoSettings.previewPhotoFormat = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            
            // Mark that we're handling a label scan
            hasSentResult = true
            
            // Capture the photo
            photoOutput.capturePhoto(with: photoSettings, delegate: self)
            
        case .barcode:
            // For barcode mode, we rely on continuous scanning
            // This case should not need manual capture as barcodes are detected automatically
            print("Shutter button pressed in barcode mode - barcode scanning should be automatic")
            
            // However, we can try to force a barcode scan on the current frame if desired
            // This might be useful if continuous scanning is struggling to detect a barcode
            if let currentFrame = self.getCurrentFrameImage() {
                self.performManualBarcodeDetection(on: currentFrame)
            }
        }
    }
    
    // Helper method to get the current frame as an image
    private func getCurrentFrameImage() -> UIImage? {
        guard let layer = previewLayer else { return nil }
        
        UIGraphicsBeginImageContextWithOptions(layer.frame.size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        layer.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
    
    // Helper method to manually detect barcodes in an image
    private func performManualBarcodeDetection(on image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        
        do {
            try requestHandler.perform([barcodeRequest!])
        } catch {
            print("Failed to perform manual barcode detection: \(error)")
        }
    }
    
    @objc private func shutterButtonTouchDown() {
        // Additional touch-down feedback
        print("Shutter button touch down")
    }
    
    @objc private func galleryButtonTapped() {
        hapticGenerator.impactOccurred()
        
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func manualEntryButtonTapped() {
        hapticGenerator.impactOccurred()
        
        let manualEntryVC = ManualBarcodeEntryViewController()
        manualEntryVC.delegate = self
        
        let navController = UINavigationController(rootViewController: manualEntryVC)
        present(navController, animated: true)
    }
    
    // MARK: - Barcode Handling
    
    private func lookupProduct(with barcode: String, completion: @escaping (Bool) -> Void) {
        // Here you would implement your product lookup logic
        // For now, we'll simulate a lookup with a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Simulate product found/not found
            let productFound = Bool.random() // Replace with actual lookup logic
            completion(productFound)
        }
    }
    
    private func showProductNotFoundMessage() {
        let alert = UIAlertController(
            title: "Product Not Found",
            message: "We couldn't find this product in our database. Please try again.",
            preferredStyle: .alert
        )
        
        // Style the alert with premium colors
        alert.view.tintColor = premiumGoldColor
        alert.view.backgroundColor = premiumBackgroundColor
        alert.view.layer.cornerRadius = 12
        alert.view.layer.borderWidth = 1
        alert.view.layer.borderColor = premiumGoldColor.withAlphaComponent(0.3).cgColor
        
        // Add OK button with premium styling
        let okAction = UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            // Reset all scanning states
            self.isLookingUpProduct = false
            self.hasSentResult = false
            self.isProcessingFrame = false
            
            // Ensure continuous scanning is enabled
            self.isContinuousBarcodeScanningEnabled = true
            
            // Show visual feedback that scanning has resumed
            UIView.animate(withDuration: 0.2, animations: {
                self.barcodeScanGuideView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self.barcodeScanGuideView.layer.borderColor = self.premiumGoldColor.cgColor
            }) { _ in
                UIView.animate(withDuration: 0.2) {
                    self.barcodeScanGuideView.transform = CGAffineTransform.identity
                }
            }
        }
        alert.addAction(okAction)
        
        present(alert, animated: true)
    }
    
    private func handleBarcodes(request: VNRequest, error: Error?) {
        // Stop processing if we've already sent a result, are looking up a product, or are in another mode
        guard !hasSentResult, !isLookingUpProduct, currentMode == .barcode, isContinuousBarcodeScanningEnabled else {
            isProcessingFrame = false
            return
        }
        
        // Check for errors
        if let error = error {
            print("Barcode detection error: \(error.localizedDescription)")
            isProcessingFrame = false
            return
        }
        
        // Process barcode observations
        guard let observations = request.results as? [VNBarcodeObservation], !observations.isEmpty else {
            isProcessingFrame = false
            return
        }
        
        // Get the barcode scan guide frame in normalized coordinates (0-1)
        var guideFrame = CGRect.zero
        
        DispatchQueue.main.sync {
            // Convert barcodeScanGuideView frame to camera view coordinates
            let guideViewFrame = barcodeScanGuideView.frame
            
            // Convert from view coordinates to normalized coordinates (0-1)
            let viewWidth = previewView.frame.width
            let viewHeight = previewView.frame.height
            
            // Update normalized rectangle
            guideFrame = CGRect(
                x: guideViewFrame.minX / viewWidth,
                y: guideViewFrame.minY / viewHeight,
                width: guideViewFrame.width / viewWidth,
                height: guideViewFrame.height / viewHeight
            )
        }
        
        // Find a valid barcode within the guide frame
        for observation in observations {
            guard let payloadString = observation.payloadStringValue else { continue }
            
            // Check if the barcode's bounding box is mostly within our guide frame
            let observationBox = observation.boundingBox
            let flippedBox = CGRect(
                x: observationBox.origin.x,
                y: 1 - observationBox.origin.y - observationBox.height,
                width: observationBox.width,
                height: observationBox.height
            )
            
            // Calculate overlap between barcode and guide frame
            let intersection = flippedBox.intersection(guideFrame)
            if !intersection.isNull {
                // Calculate how much of the barcode is within the guide frame (as a percentage)
                let overlapArea = intersection.width * intersection.height
                let barcodeArea = flippedBox.width * flippedBox.height
                let overlapPercentage = overlapArea / barcodeArea
                
                // Only accept barcode if sufficient portion is within guide frame (e.g., >50%)
                if overlapPercentage > 0.5 {
                    // Valid barcode found within guide frame
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, !self.hasSentResult else { return }
                        
                        // Show visual feedback that barcode was detected
                        let originalBorderColor = self.barcodeScanGuideView.layer.borderColor
                        UIView.animate(withDuration: 0.15, animations: {
                            self.barcodeScanGuideView.layer.borderColor = UIColor.systemGreen.cgColor
                            self.barcodeScanGuideView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                        }) { _ in
                            UIView.animate(withDuration: 0.1) {
                                self.barcodeScanGuideView.layer.borderColor = originalBorderColor
                                self.barcodeScanGuideView.transform = CGAffineTransform.identity
                            }
                        }
                        
                        // Start product lookup
                        self.isLookingUpProduct = true
                        self.lookupProduct(with: payloadString) { [weak self] productFound in
                            guard let self = self else { return }
                            
                            if productFound {
                                // Product found, proceed to Flutter
                                self.hasSentResult = true
                                self.hapticGenerator.impactOccurred(intensity: 1.0)
                                
                                // Dismiss and send result to delegate after a brief delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    self.dismiss(animated: true) {
                                        self.delegate?.nativeCameraDidFinish(withBarcode: payloadString, mode: .barcode)
                                    }
                                }
                            } else {
                                // Product not found, show message
                                self.showProductNotFoundMessage()
                            }
                        }
                    }
                    return // Exit loop after finding a valid barcode
                }
            }
        }
        
        isProcessingFrame = false
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard currentMode == .barcode, isContinuousBarcodeScanningEnabled, !isProcessingFrame, !hasSentResult else {
            return
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        isProcessingFrame = true
        
        let imageRequestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .right,  // For portrait orientation with back camera
            options: [:]
        )
        
        do {
            try imageRequestHandler.perform([barcodeRequest!])
        } catch {
            print("Failed to perform barcode detection: \(error)")
            isProcessingFrame = false
        }
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Photo capture error: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("Could not get image data from photo capture")
            return
        }
        
        // We've successfully captured a photo
        hasSentResult = true
        
        // Dismiss camera and send result
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.nativeCameraDidFinish(withPhotoData: imageData, mode: self.currentMode)
        }
    }
    
    // MARK: - Helpers
    
    private func modeToIndex(_ mode: CameraMode) -> Int {
        switch mode {
        case .barcode: return 0
        case .camera: return 1
        case .label: return 2
        }
    }
    
    private func indexToMode(_ index: Int) -> CameraMode {
        switch index {
        case 0: return .barcode
        case 1: return .camera
        case 2: return .label
        default: return .camera // Default fallback
        }
    }

    // MARK: - PHPickerViewControllerDelegate Methods
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else {
            print("No image selected")
            return
        }
        
        // Get the image data
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] reading, error in
            guard let self = self,
                  let image = reading as? UIImage,
                  let imageData = image.jpegData(compressionQuality: 0.8) else {
                print("Failed to get image data")
                return
            }
            
            // Mark as sent to prevent duplicate results
            self.hasSentResult = true
            
            DispatchQueue.main.async {
                // Dismiss the camera view and send result back
                self.dismiss(animated: true) {
                    self.delegate?.nativeCameraDidFinish(withPhotoData: imageData, mode: self.currentMode)
                }
            }
        }
    }
    
    // MARK: - ManualBarcodeEntryDelegate Methods
    
    func manualBarcodeEntryDidFinish(with barcode: String) {
        // Check if we already sent a result for this presentation
        guard !hasSentResult else {
            print("DEBUG: Manual barcode entry finished, but result already sent.")
            // If already sent, just dismiss self (which includes the presented manual VC)
            dismiss(animated: true, completion: nil)
            return
        }
        
        print("DEBUG: Manual Barcode Entered: \(barcode)")
        print("DEBUG: Delegate exists? \(delegate != nil)")
        
        // First dismiss the manual entry view controller (which was presented modally)
        // Then dismiss the camera view controller and send the barcode to Flutter
        
        // Mark result as sent to prevent multiple results
        hasSentResult = true
        
        // Show haptic feedback
        hapticGenerator.impactOccurred(intensity: 1.0)
        
        // Get a reference to the presenting view controller (the navigation controller containing ManualBarcodeEntryViewController)
        if let presentedVC = self.presentedViewController {
            // First dismiss the manual entry screen
            presentedVC.dismiss(animated: true) {
                // Then dismiss the camera view controller and send the result to Flutter
                self.dismiss(animated: true) {
                    // Call the delegate after both screens are dismissed
                    self.delegate?.nativeCameraDidFinish(withBarcode: barcode, mode: .barcode)
                    print("DEBUG: Both screens dismissed, barcode result sent to Flutter")
                }
            }
        } else {
            // If for some reason the manual entry screen is not presented, just dismiss the camera view
            self.dismiss(animated: true) {
                self.delegate?.nativeCameraDidFinish(withBarcode: barcode, mode: .barcode)
                print("DEBUG: Camera screen dismissed, barcode result sent to Flutter")
            }
        }
    }
    
    func manualBarcodeEntryDidCancel() {
        print("Manual Barcode Entry Cancelled")
        // Just dismiss the manual entry screen, keep camera open
    }

    // Enhanced premium text styling for instruction label
    private func updateInstructionLabelText(_ text: String) {
        let attributedString = NSMutableAttributedString(string: text)
        let letterSpacing: CGFloat = 0.8
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 4
        
        // Create premium text effect with gold accent
        let attributes: [NSAttributedString.Key: Any] = [
            .kern: letterSpacing,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle,
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .strokeColor: premiumGoldColor.withAlphaComponent(0.3),
            .strokeWidth: -1.0 // Negative width creates filled text with outline
        ]
        
        attributedString.addAttributes(attributes, range: NSRange(location: 0, length: text.count))
        instructionLabel.attributedText = attributedString
        
        // Add subtle gold accent to the shadow
        instructionLabel.layer.shadowColor = premiumGoldColor.withAlphaComponent(0.4).cgColor
        instructionLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        instructionLabel.layer.shadowOpacity = 0.5
        instructionLabel.layer.shadowRadius = 3
    }
}
