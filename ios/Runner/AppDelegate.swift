import UIKit
import Flutter
import SwiftUI
import HealthKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging
import AVFoundation  // Added for camera functionality

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MessagingDelegate, NativeCameraViewControllerDelegate {
    // Remove these properties
    // private var methodHandler: FlutterMethodHandler?
    // private var statsMethodHandler: StatsMethodHandler?
    
    // Keep the camera view channel for now
    private var nativeCameraViewChannel: FlutterMethodChannel?
    private let nativeCameraViewChannelName = "com.macrotracker/native_camera_view"
    
    // Add stats channel
    private var statsChannel: FlutterMethodChannel?
    private let statsChannelName = "app.macrobalance.com/stats"

    // Registrar for the app's own native camera code. Under the UIScene lifecycle the
    // app delegate has no window, so the camera is presented from this registrar's
    // view controller (the FlutterViewController hosting the implicit engine).
    private var nativeCameraRegistrar: FlutterPluginRegistrar?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("[AppDelegate] Application launching")

        // Plugins and method channels are set up in didInitializeImplicitFlutterEngine.
        // With the UIScene lifecycle the Flutter engine and its view controller are
        // created when the scene connects, which is after this method returns.

        // Configure Firebase here, BEFORE plugins are registered (that happens later,
        // in didInitializeImplicitFlutterEngine).
        FirebaseApp.configure()
        print("[AppDelegate] Firebase configured via FirebaseApp.configure()")

        // App Group Id for home_widget should be set in Info.plist

        // Keep Firebase messaging setup
        Messaging.messaging().delegate = self

        // Remove StatsDataManager configuration
        // StatsDataManager.shared.configure(with: controller.binaryMessenger)
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                 completionHandler: { _, _ in }
             )
         }

         application.registerForRemoteNotifications()

         return super.application(application, didFinishLaunchingWithOptions: launchOptions)
     }

     // MARK: - Implicit Flutter engine (UIScene lifecycle) -

     func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
         print("[AppDelegate] Implicit Flutter engine initialized")
         GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

         let messenger = engineBridge.applicationRegistrar.messenger()

         // Initialize camera view channel
         nativeCameraViewChannel = FlutterMethodChannel(name: nativeCameraViewChannelName,
                                                      binaryMessenger: messenger)
         nativeCameraViewChannel?.setMethodCallHandler(handleNativeCameraViewMethodCall)
         nativeCameraRegistrar = engineBridge.pluginRegistry.registrar(forPlugin: "MacroBalanceNativeCameraView")

         // Initialize stats channel
         statsChannel = FlutterMethodChannel(name: statsChannelName,
                                           binaryMessenger: messenger)
         statsChannel?.setMethodCallHandler(handleStatsMethodCall)
     }

     /// The view controller to present native UI from. Prefers the Flutter view
     /// controller that owns the engine, then the key window of the active scene.
     private func presentingViewController() -> UIViewController? {
         if let controller = nativeCameraRegistrar?.viewController {
             return controller
         }
         let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
         let scene = windowScenes.first { $0.activationState == .foregroundActive } ?? windowScenes.first
         let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
         return window?.rootViewController
     }

     // MARK: - Native Camera View Method Channel Handler -

     private func handleNativeCameraViewMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
         print("[AppDelegate] Native Camera View Method Call: \(call.method)")

         guard let controller = presentingViewController() else {
             result(FlutterError(code: "INTERNAL_ERROR", message: "Cannot get root view controller", details: nil))
             return
         }

         // Handle specific methods
         if call.method == "showNativeCamera" {
             // Extract initialMode argument from Flutter call
             let args = call.arguments as? [String: Any]
             let initialModeString = args?["initialMode"] as? String ?? "camera" // Default to camera if not provided
             let initialMode = CameraMode(rawValue: initialModeString) ?? .camera // Convert string to enum

             let nativeCameraVC = NativeCameraViewController()
             nativeCameraVC.delegate = self
             nativeCameraVC.initialMode = initialMode // Set the initial mode
             nativeCameraVC.modalPresentationStyle = .fullScreen
             controller.present(nativeCameraVC, animated: true, completion: nil)
             result(nil) // Acknowledge successful presentation
         } else {
             result(FlutterMethodNotImplemented)
         }
     }

     // MARK: - Stats Method Channel Handler -
     
     private func handleStatsMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
         print("[AppDelegate] Stats Method Call: \(call.method)")
         
         switch call.method {
         case "macrosDataChanged":
             // Handle the macros data changed notification
             // This is just an acknowledgment that the data changed
             // No need to return any data
             result(nil)
         default:
             result(FlutterMethodNotImplemented)
         }
     }

     // MARK: - NativeCameraViewControllerDelegate Methods -

     func nativeCameraDidFinish(withBarcode barcode: String, mode: CameraMode) { // Updated signature
         print("DEBUG: [AppDelegate] Native Camera Finished with Barcode: \(barcode) in mode: \(mode.rawValue)")
         
         // Send result back to Flutter via the channel, including mode
         print("DEBUG: [AppDelegate] Invoking 'cameraResult' method on nativeCameraViewChannel")
         print("DEBUG: [AppDelegate] Channel exists? \(nativeCameraViewChannel != nil)")
         
         nativeCameraViewChannel?.invokeMethod("cameraResult", arguments: [
             "type": "barcode",
             "value": barcode,
             "mode": mode.rawValue // Include mode string
         ]) { (result) in
             if let error = result as? FlutterError {
                 print("DEBUG: [AppDelegate] Error invoking method: \(error.message ?? "unknown error")")
             } else {
                 print("DEBUG: [AppDelegate] Successfully sent barcode result to Flutter")
             }
         }
     }

     func nativeCameraDidFinish(withPhotoData photoData: Data, mode: CameraMode) { // Updated signature
         print("DEBUG: [AppDelegate] Native Camera Finished with Photo Data: \(photoData.count) bytes in mode: \(mode.rawValue)")
         
         // Send result back to Flutter, including mode
         print("DEBUG: [AppDelegate] Invoking 'cameraResult' method on nativeCameraViewChannel for photo")
         print("DEBUG: [AppDelegate] Channel exists? \(nativeCameraViewChannel != nil)")
         
         nativeCameraViewChannel?.invokeMethod("cameraResult", arguments: [
             "type": "photo",
             "value": FlutterStandardTypedData(bytes: photoData),
             "mode": mode.rawValue // Include mode string
         ]) { (result) in
             if let error = result as? FlutterError {
                 print("DEBUG: [AppDelegate] Error invoking method for photo: \(error.message ?? "unknown error")")
             } else {
                 print("DEBUG: [AppDelegate] Successfully sent photo result to Flutter")
             }
         }
     }

     func nativeCameraDidCancel() {
         print("[AppDelegate] Native Camera Cancelled")
         // Notify Flutter that the user cancelled
         nativeCameraViewChannel?.invokeMethod("cameraResult", arguments: ["type": "cancel"])
     }

     // Remove Stats methods
     /*
     private func initializeStatsServices(completion: @escaping (Bool) -> Void) {
         // Check if HealthKit is available
         guard HKHealthStore.isHealthDataAvailable() else {
             completion(true)
             return
         }
         
         // Request HealthKit authorization
         let healthStore = HKHealthStore()
         let typesToRead: Set<HKObjectType> = [
             HKObjectType.quantityType(forIdentifier: .stepCount)!,
             HKObjectType.quantityType(forIdentifier: .bodyMass)!,
             HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
             HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!
         ]
         
         healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
             DispatchQueue.main.async {
                 completion(success)
             }
         }
     }

     private func showStatsViewController(_ flutterViewController: FlutterViewController, initialSection: String) throws {
         let statsVC = StatsViewController(
             messenger: flutterViewController.binaryMessenger,
             parentViewController: flutterViewController
         )
         statsVC.navigateToSection(initialSection)
         let navController = UINavigationController(rootViewController: statsVC)
         navController.modalPresentationStyle = .fullScreen
         flutterViewController.present(navController, animated: true)
     }
     */
    
    // Keep Firebase messaging methods
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
    }

    // MARK: - Remote Notifications Registration

    override func application(_ application: UIApplication,
                        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("[AppDelegate] Registered for remote notifications with token.")
        Messaging.messaging().apnsToken = deviceToken
    }

    override func application(_ application: UIApplication,
                        didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
