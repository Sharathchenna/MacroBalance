import Foundation
import UIKit
import AVFoundation
import Vision

class NativeBarcodeScanner: NSObject {
    private let methodChannel: FlutterMethodChannel
    private var captureSession: AVCaptureSession?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?
    private var isDetecting = false
    
    // Configuration
    private var scanArea: CGRect?
    private var overlapThreshold: Float = 0.5
    
    // Supported barcode types for iOS
    private let supportedBarcodeTypes: [VNBarcodeSymbology] = [
        .aztec,
        .code39,
        .code93,
        .code128,
        .dataMatrix,
        .ean8,
        .ean13,
        .itf14,
        .pdf417,
        .qr,
        .upce
    ]
    
    init(methodChannel: FlutterMethodChannel) {
        self.methodChannel = methodChannel
        super.init()
        setupMethodChannel()
    }
    
    private func setupMethodChannel() {
        methodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else { return }
            
            switch call.method {
            case "setScanArea":
                self.handleSetScanArea(call: call, result: result)
            case "setOverlapThreshold":
                self.handleSetOverlapThreshold(call: call, result: result)
            case "startDetection":
                self.handleStartDetection(result: result)
            case "stopDetection":
                self.handleStopDetection(result: result)
            case "processImage":
                self.handleProcessImage(call: call, result: result)
            case "dispose":
                self.handleDispose(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - Method Channel Handlers
    
    private func handleSetScanArea(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let x = args["x"] as? Double,
              let y = args["y"] as? Double,
              let width = args["width"] as? Double,
              let height = args["height"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid scan area arguments", details: nil))
            return
        }
        
        scanArea = CGRect(x: x, y: y, width: width, height: height)
        print("[NativeBarcodeScanner] Scan area set to: \(scanArea!)")
        result(nil)
    }
    
    private func handleSetOverlapThreshold(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let threshold = call.arguments as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid threshold argument", details: nil))
            return
        }
        
        overlapThreshold = Float(max(0.0, min(1.0, threshold)))
        print("[NativeBarcodeScanner] Overlap threshold set to: \(overlapThreshold)")
        result(nil)
    }
    
    private func handleStartDetection(result: @escaping FlutterResult) {
        isDetecting = true
        print("[NativeBarcodeScanner] Detection started")
        result(nil)
    }
    
    private func handleStopDetection(result: @escaping FlutterResult) {
        isDetecting = false
        print("[NativeBarcodeScanner] Detection stopped")
        result(nil)
    }
    
    private func handleProcessImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imageData = args["imageData"] as? FlutterStandardTypedData,
              let width = args["width"] as? Int,
              let height = args["height"] as? Int,
              let format = args["format"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid image arguments", details: nil))
            return
        }
        
        // Process image on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.processImageData(imageData.data, width: width, height: height, format: format) { barcodeValue in
                DispatchQueue.main.async {
                    result(barcodeValue)
                }
            }
        }
    }
    
    private func handleDispose(result: @escaping FlutterResult) {
        isDetecting = false
        captureSession = nil
        videoDataOutput = nil
        videoDataOutputQueue = nil
        scanArea = nil
        print("[NativeBarcodeScanner] Disposed")
        result(nil)
    }
    
    // MARK: - Image Processing
    
    private func processImageData(_ data: Data, width: Int, height: Int, format: String, completion: @escaping (String?) -> Void) {
        guard isDetecting else {
            completion(nil)
            return
        }
        
        // Create CGImage from raw data
        guard let cgImage = createCGImage(from: data, width: width, height: height, format: format) else {
            print("[NativeBarcodeScanner] Failed to create CGImage from data")
            completion(nil)
            return
        }
        
        // Create Vision request
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("[NativeBarcodeScanner] Vision error: \(error.localizedDescription)")
                self.reportError(error.localizedDescription)
                completion(nil)
                return
            }
            
            guard let observations = request.results as? [VNBarcodeObservation] else {
                completion(nil)
                return
            }
            
            // Process detected barcodes
            for observation in observations {
                if let payloadStringValue = observation.payloadStringValue,
                   !payloadStringValue.isEmpty {
                    
                    // Check if barcode is in scan area (if specified)
                    if let scanArea = self.scanArea,
                       !self.isBarcodeInScanArea(observation.boundingBox, scanArea: scanArea, imageSize: CGSize(width: width, height: height)) {
                        continue
                    }
                    
                    print("[NativeBarcodeScanner] Native barcode detected: \(payloadStringValue)")
                    
                    // Report detection via method channel
                    self.reportBarcodeDetection(payloadStringValue, boundingBox: observation.boundingBox, imageSize: CGSize(width: width, height: height))
                    
                    completion(payloadStringValue)
                    return
                }
            }
            
            completion(nil)
        }
        
        // Set supported symbologies
        request.symbologies = supportedBarcodeTypes
        
        // Perform request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("[NativeBarcodeScanner] Failed to perform Vision request: \(error.localizedDescription)")
            reportError(error.localizedDescription)
            completion(nil)
        }
    }
    
    private func createCGImage(from data: Data, width: Int, height: Int, format: String) -> CGImage? {
        let bytesPerPixel: Int
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo
        
        switch format.lowercased() {
        case "bgra8888":
            bytesPerPixel = 4
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        case "rgba8888":
            bytesPerPixel = 4
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        case "rgb888":
            bytesPerPixel = 3
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        default:
            // Default to BGRA8888
            bytesPerPixel = 4
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        }
        
        let bytesPerRow = width * bytesPerPixel
        
        guard data.count >= bytesPerRow * height else {
            print("[NativeBarcodeScanner] Insufficient data for image dimensions")
            return nil
        }
        
        return data.withUnsafeBytes { bytes in
            guard let provider = CGDataProvider(data: NSData(bytes: bytes.bindMemory(to: UInt8.self).baseAddress!, length: data.count)) else {
                return nil
            }
            
            return CGImage(
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bitsPerPixel: bitsPerComponent * bytesPerPixel,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func isBarcodeInScanArea(_ boundingBox: CGRect, scanArea: CGRect, imageSize: CGSize) -> Bool {
        // Convert normalized coordinates to image coordinates
        let actualBoundingBox = CGRect(
            x: boundingBox.minX * imageSize.width,
            y: (1.0 - boundingBox.maxY) * imageSize.height, // Vision uses bottom-left origin
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )
        
        let intersection = actualBoundingBox.intersection(scanArea)
        guard !intersection.isNull && !intersection.isEmpty else { return false }
        
        let overlapArea = intersection.width * intersection.height
        let barcodeArea = actualBoundingBox.width * actualBoundingBox.height
        
        guard barcodeArea > 0 else { return false }
        
        let overlapPercentage = Float(overlapArea / barcodeArea)
        
        print("[NativeBarcodeScanner] Barcode overlap: \(String(format: "%.1f", overlapPercentage * 100))%")
        
        return overlapPercentage >= overlapThreshold
    }
    
    private func reportBarcodeDetection(_ barcode: String, boundingBox: CGRect, imageSize: CGSize) {
        // Convert normalized coordinates to screen coordinates for Flutter
        let convertedBoundingBox: [String: Any] = [
            "x": boundingBox.minX * imageSize.width,
            "y": (1.0 - boundingBox.maxY) * imageSize.height,
            "width": boundingBox.width * imageSize.width,
            "height": boundingBox.height * imageSize.height
        ]
        
        DispatchQueue.main.async { [weak self] in
            self?.methodChannel.invokeMethod("onBarcodeDetected", arguments: [
                "barcode": barcode,
                "boundingBox": convertedBoundingBox
            ])
        }
    }
    
    private func reportError(_ error: String) {
        DispatchQueue.main.async { [weak self] in
            self?.methodChannel.invokeMethod("onBarcodeError", arguments: [
                "error": error
            ])
        }
    }
} 