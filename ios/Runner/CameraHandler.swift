import AVFoundation
import Vision
import UIKit
import Flutter

// Protocol to send results back to AppDelegate/MethodChannel handler
protocol CameraHandlerDelegate: AnyObject {
    func didFindBarcode(_ barcode: String)
    func didCapturePhoto(_ photoData: Data)
    func cameraSetupFailed(error: String)
    func cameraAccessDenied()
    func cameraInitialized() // Notify when setup is complete
    func zoomLevelsAvailable(min: Double, max: Double)
}

class CameraHandler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {

    weak var delegate: CameraHandlerDelegate?
    private var flutterResult: FlutterResult? // To hold the result callback for async operations

    // Camera Session Components
    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer? // May not be needed if preview is handled by Flutter
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var backCamera: AVCaptureDevice?
    private var frontCamera: AVCaptureDevice? // If needed
    private var currentCameraInput: AVCaptureDeviceInput?

    // State Management
    private let sessionQueue = DispatchQueue(label: "sessionQueue", qos: .userInitiated)
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var isBarcodeScanningEnabled = false
    private var isProcessingFrame = false // To prevent processing multiple frames simultaneously
    private var currentZoomFactor: CGFloat = 1.0
    private var minZoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 1.0
    private var currentFlashMode: AVCaptureDevice.FlashMode = .off
    private var currentCameraMode: CameraMode = .barcode // Default mode

    enum CameraMode {
        case barcode
        case photo
    }

    // Vision requests
    private var barcodeRequest: VNDetectBarcodesRequest?

    override init() {
        super.init()
        setupVision()
    }

    // MARK: - Setup & Teardown -

    private func setupVision() {
        barcodeRequest = VNDetectBarcodesRequest(completionHandler: handleBarcodes)
        // Configure barcode symbologies if needed, e.g., barcodeRequest?.symbologies = [.ean13, .qr, .upce, .code128] // Add relevant types
    }

    func checkCameraPermissions(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        default:
            completion(false)
        }
    }

    func initializeCamera(flutterResult: FlutterResult?) {
        self.flutterResult = flutterResult // Store for later use if needed

        checkCameraPermissions { [weak self] granted in
            guard let self = self else { return }
            if granted {
                self.sessionQueue.async { // Perform setup on the session queue
                    self.configureSession()
                    DispatchQueue.main.async {
                        self.delegate?.cameraInitialized()
                        self.flutterResult?(nil) // Indicate success
                        self.flutterResult = nil // Clear after use
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.delegate?.cameraAccessDenied()
                    self.flutterResult?(FlutterError(code: "PERMISSION_DENIED", message: "Camera access denied", details: nil))
                    self.flutterResult = nil
                }
            }
        }
    }

    private func configureSession() {
        guard captureSession == nil else {
            print("Camera session already configured.")
            // Ensure session is running if already configured
            if !(captureSession?.isRunning ?? false) {
                startSession()
            }
            return
        }

        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo // Use high quality for photos

        // Find back camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            reportError("Could not find back camera.")
            return
        }
        self.backCamera = camera
        self.currentCameraInput = try? AVCaptureDeviceInput(device: camera)

        guard let input = currentCameraInput else {
            reportError("Could not create camera input.")
            return
        }

        captureSession?.beginConfiguration()

        if captureSession?.canAddInput(input) ?? false {
            captureSession?.addInput(input)
        } else {
            reportError("Could not add camera input to session.")
            captureSession?.commitConfiguration()
            return
        }

        // Setup Video Data Output (for barcode scanning)
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoDataOutput?.alwaysDiscardsLateVideoFrames = true
        videoDataOutput?.setSampleBufferDelegate(self, queue: videoDataOutputQueue)

        if captureSession?.canAddOutput(videoDataOutput!) ?? false {
            captureSession?.addOutput(videoDataOutput!)
            // Set video orientation (important for Vision)
             if let connection = videoDataOutput?.connection(with: .video) {
                 if connection.isVideoOrientationSupported {
                     connection.videoOrientation = .portrait // Adjust if needed based on device orientation handling
                 }
             }
        } else {
            reportError("Could not add video data output.")
        }

        // Setup Photo Output
        photoOutput = AVCapturePhotoOutput()
        if captureSession?.canAddOutput(photoOutput!) ?? false {
            captureSession?.addOutput(photoOutput!)
        } else {
            reportError("Could not add photo output.")
        }

        captureSession?.commitConfiguration()

        // Get zoom capabilities after configuration
        minZoomFactor = camera.minAvailableVideoZoomFactor
        maxZoomFactor = camera.maxAvailableVideoZoomFactor
        DispatchQueue.main.async {
            self.delegate?.zoomLevelsAvailable(min: Double(self.minZoomFactor), max: Double(self.maxZoomFactor))
        }

        // Start the session
        startSession()
    }

    func startSession() {
        sessionQueue.async {
            if !(self.captureSession?.isRunning ?? false) {
                self.captureSession?.startRunning()
                print("Camera session started.")
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            if self.captureSession?.isRunning ?? false {
                self.captureSession?.stopRunning()
                print("Camera session stopped.")
            }
            // Release resources if fully tearing down
            // self.captureSession = nil
            // self.videoDataOutput = nil
            // self.photoOutput = nil
            // self.currentCameraInput = nil
        }
    }

    func teardownCamera() {
        stopSession()
        // Additional cleanup if needed
        sessionQueue.async {
            self.captureSession = nil
            self.videoDataOutput = nil
            self.photoOutput = nil
            self.currentCameraInput = nil
            self.backCamera = nil
            print("Camera resources released.")
        }
    }


    private func reportError(_ message: String) {
        print("Camera Error: \(message)")
        DispatchQueue.main.async {
            self.delegate?.cameraSetupFailed(error: message)
            self.flutterResult?(FlutterError(code: "CAMERA_ERROR", message: message, details: nil))
            self.flutterResult = nil // Clear after use
        }
        // Consider stopping the session on critical errors
        // stopSession()
    }

    // MARK: - Mode Switching -

    func switchCameraMode(to mode: String, result: @escaping FlutterResult) { // Added @escaping
         sessionQueue.async { [weak self] in
             guard let self = self else { return }
             let newMode: CameraMode = (mode == "barcode") ? .barcode : .photo
             if newMode != self.currentCameraMode {
                 self.currentCameraMode = newMode
                 print("Switched camera mode to: \(mode)")
                 // Adjust session preset or other settings if needed based on mode
                 // e.g., lower preset for barcode scanning for performance?
                 // self.captureSession?.sessionPreset = (newMode == .barcode) ? .hd1280x720 : .photo
             }
             DispatchQueue.main.async {
                 result(nil) // Confirm mode switch
             }
         }
     }

    // MARK: - Barcode Scanning (Vision) -

    func startBarcodeScanning(result: FlutterResult) {
        isBarcodeScanningEnabled = true
        print("Barcode scanning enabled.")
        result(nil) // Acknowledge start request
    }

    func stopBarcodeScanning(result: FlutterResult) {
        isBarcodeScanningEnabled = false
        print("Barcode scanning disabled.")
        result(nil) // Acknowledge stop request
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isBarcodeScanningEnabled, currentCameraMode == .barcode, !isProcessingFrame else {
            return
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get CVPixelBuffer.")
            return
        }

        isProcessingFrame = true // Mark as processing

        // Determine image orientation
        // This might need adjustment based on how device orientation is handled
        let imageOrientation = CGImagePropertyOrientation.right // Assuming portrait right for back camera

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: imageOrientation, options: [:])
        do {
            try handler.perform([barcodeRequest!])
        } catch {
            print("Failed to perform Vision request: \(error)")
            isProcessingFrame = false // Reset flag on error
        }
    }

    private func handleBarcodes(request: VNRequest, error: Error?) {
        defer { isProcessingFrame = false } // Ensure flag is reset

        guard let results = request.results as? [VNBarcodeObservation], error == nil else {
            print("Vision error or no results: \(error?.localizedDescription ?? "Unknown error")")
            return
        }

        if let barcode = results.first?.payloadStringValue {
            // Found a barcode
            print("Detected barcode: \(barcode)")
            isBarcodeScanningEnabled = false // Stop scanning after finding one
            DispatchQueue.main.async {
                self.delegate?.didFindBarcode(barcode)
            }
        }
    }

    // MARK: - Photo Capture -

    func takePicture(result: @escaping FlutterResult) {
         guard currentCameraMode == .photo else {
             result(FlutterError(code: "WRONG_MODE", message: "Camera not in photo mode", details: nil))
             return
         }
         guard let photoOutput = self.photoOutput else {
             result(FlutterError(code: "NOT_INITIALIZED", message: "Photo output not available", details: nil))
             return
         }

         sessionQueue.async {
             // Determine preferred codec
             var format: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.jpeg] // Default to JPEG
             if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                 format = [AVVideoCodecKey: AVVideoCodecType.hevc] // Use HEVC if available
             }

             // Initialize settings with the chosen format
             let photoSettings = AVCapturePhotoSettings(format: format)

             // Configure other settings (flash)
             if photoOutput.supportedFlashModes.contains(self.currentFlashMode) {
                 photoSettings.flashMode = self.currentFlashMode
             }
             // Add other settings like highResolutionPhotoEnabled if needed
             // if photoOutput.isHighResolutionCaptureEnabled {
             //     photoSettings.isHighResolutionPhotoEnabled = true
             // }


             self.flutterResult = result // Store the result callback for the delegate method
             photoOutput.capturePhoto(with: photoSettings, delegate: self)
         }
     }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let storedResult = self.flutterResult else {
            print("Error: FlutterResult callback missing for photo capture.")
            return
        }
        self.flutterResult = nil // Clear immediately

        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            storedResult(FlutterError(code: "CAPTURE_ERROR", message: error.localizedDescription, details: nil))
            return
        }

        guard let photoData = photo.fileDataRepresentation() else {
            print("Could not get photo data.")
            storedResult(FlutterError(code: "DATA_ERROR", message: "Could not get photo data", details: nil))
            return
        }

        print("Photo captured successfully.")
        // Send data back via delegate or directly via storedResult
        // Using delegate is cleaner if AppDelegate handles the result sending
        // delegate?.didCapturePhoto(photoData)
        // OR send directly:
        storedResult(photoData) // Send raw photo data back to Flutter
    }


    // MARK: - Camera Controls -

    func setFlashMode(mode: String, result: @escaping FlutterResult) { // Added @escaping
        guard let device = backCamera, device.hasTorch, device.hasFlash else {
            result(FlutterError(code: "UNSUPPORTED", message: "Flash/Torch not available", details: nil))
            return
        }

        let newMode: AVCaptureDevice.FlashMode
        let newTorchMode: AVCaptureDevice.TorchMode

        switch mode.lowercased() {
        case "torch":
            newMode = .off // Flash is for capture, Torch is for continuous light
            newTorchMode = .on
        case "on": // Treat 'on' as auto flash for capture
            newMode = .auto
            newTorchMode = .off
        case "auto":
             newMode = .auto
             newTorchMode = .off
        case "off":
            newMode = .off
            newTorchMode = .off
        default:
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid flash mode: \(mode)", details: nil))
            return
        }

        sessionQueue.async {
            do {
                try device.lockForConfiguration()

                // Set Flash for photo capture
                if device.isFlashModeSupported(newMode) {
                    self.currentFlashMode = newMode // Store for takePicture
                    // Note: Flash mode is set in AVCapturePhotoSettings during capture
                }

                // Set Torch for continuous light (like in barcode mode)
                if device.isTorchModeSupported(newTorchMode) {
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel) // Use max brightness for torch
                    device.torchMode = newTorchMode
                }

                device.unlockForConfiguration()
                print("Flash/Torch mode set to \(mode)")
                DispatchQueue.main.async { result(nil) }
            } catch {
                print("Could not set flash/torch mode: \(error)")
                DispatchQueue.main.async { result(FlutterError(code: "CONFIG_ERROR", message: "Could not set flash/torch mode", details: error.localizedDescription)) }
            }
        }
    }


    func setZoomLevel(zoom: Double, result: @escaping FlutterResult) { // Added @escaping
        guard let device = backCamera else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Camera device not available", details: nil))
            return
        }

        let clampedZoom = max(minZoomFactor, min(CGFloat(zoom), maxZoomFactor))

        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedZoom
                device.unlockForConfiguration()
                self.currentZoomFactor = clampedZoom // Update state
                print("Zoom set to \(clampedZoom)")
                DispatchQueue.main.async { result(nil) }
            } catch {
                print("Could not set zoom level: \(error)")
                DispatchQueue.main.async { result(FlutterError(code: "CONFIG_ERROR", message: "Could not set zoom level", details: error.localizedDescription)) }
            }
        }
    }

    // Add focus control if needed (e.g., tap to focus)
    // func focus(at point: CGPoint) { ... }
}
