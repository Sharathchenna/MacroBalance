import UIKit
import Flutter
import SwiftUI
import HealthKit
import shared_preferences_foundation
import health
import app_links
import path_provider_foundation
import url_launcher_ios
import app_settings
import flutter_native_splash
import device_info_plus
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@main
// Remove CameraHandlerDelegate, Add NativeCameraViewControllerDelegate
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate, NativeCameraViewControllerDelegate {
    private var methodHandler: FlutterMethodHandler?
    private var statsMethodHandler: StatsMethodHandler?
    // Remove old camera handler properties
    // private var cameraHandler: CameraHandler?
    // private var cameraMethodChannel: FlutterMethodChannel?
    // private let cameraChannelName = "com.macrotracker/camera"

    // New channel for presenting the native view
    private var nativeCameraViewChannel: FlutterMethodChannel?
    private let nativeCameraViewChannelName = "com.macrotracker/native_camera_view"
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("[AppDelegate] Application launching")
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        
        methodHandler = FlutterMethodHandler(window: window, viewController: controller)
        
        // Initialize the stats method handler - this handles all stats-related calls
        statsMethodHandler = StatsMethodHandler(
            messenger: controller.binaryMessenger,
            parentViewController: controller
        )
        
        // Register native view factory for stats
        let statsFactory = StatsViewFactory(
            messenger: controller.binaryMessenger,
            flutterViewController: controller
        )
        registrar(forPlugin: "StatsView")?.register(
            statsFactory,
            withId: "stats_view"
        )

        // Initialize NEW Method Channel for Native Camera View
        nativeCameraViewChannel = FlutterMethodChannel(name: nativeCameraViewChannelName,
                                                      binaryMessenger: controller.binaryMessenger)
        nativeCameraViewChannel?.setMethodCallHandler(handleNativeCameraViewMethodCall) // Set the NEW handler

        // Explicitly configure Firebase here BEFORE registering plugins
        FirebaseApp.configure()
        print("[AppDelegate] Firebase configured via FirebaseApp.configure()")
        
        GeneratedPluginRegistrant.register(with: self)
        
        // Note: FirebaseApp.configure() is now handled in Flutter code (comment remains, but we added configure above)
        // Just set up the messaging delegate
        Messaging.messaging().delegate = self

        // Configure the StatsDataManager with the binary messenger
        // This allows the native side to call back into Flutter for data
        StatsDataManager.shared.configure(with: controller.binaryMessenger)
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                 completionHandler: { _, _ in }
             )
         } // <-- Corrected placement of closing brace for if #available

         application.registerForRemoteNotifications()

         return super.application(application, didFinishLaunchingWithOptions: launchOptions)
     } // <-- Correct closing brace for application(_:didFinishLaunchingWithOptions:)


     // MARK: - Native Camera View Method Channel Handler -

     private func handleNativeCameraViewMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
         print("[AppDelegate] Native Camera View Method Call: \(call.method)")

         guard let controller = window?.rootViewController as? FlutterViewController else {
             result(FlutterError(code: "INTERNAL_ERROR", message: "Cannot get root view controller", details: nil))
             return
         }

         switch call.method {
         case "showNativeCamera":
             let nativeCameraVC = NativeCameraViewController()
             nativeCameraVC.delegate = self // Set AppDelegate as the delegate
             nativeCameraVC.modalPresentationStyle = .fullScreen // Present full screen
             controller.present(nativeCameraVC, animated: true, completion: nil)
             result(nil) // Acknowledge the call
         default:
             result(FlutterMethodNotImplemented)
         }
     }


     // MARK: - NativeCameraViewControllerDelegate Methods -

     func nativeCameraDidFinish(withBarcode barcode: String) {
         print("[AppDelegate] Native Camera Finished with Barcode: \(barcode)")
         // Send result back to Flutter via the new channel
         nativeCameraViewChannel?.invokeMethod("cameraResult", arguments: ["type": "barcode", "value": barcode])
     }

     func nativeCameraDidFinish(withPhotoData photoData: Data) {
         print("[AppDelegate] Native Camera Finished with Photo Data: \(photoData.count) bytes")
         // Send result back to Flutter via the new channel
         // Note: Sending large data like images over method channels can be inefficient.
         // Consider saving to a temp file and sending the path if performance is an issue.
         nativeCameraViewChannel?.invokeMethod("cameraResult", arguments: ["type": "photo", "value": FlutterStandardTypedData(bytes: photoData)])
     }

     func nativeCameraDidCancel() {
         print("[AppDelegate] Native Camera Cancelled")
         // Optionally notify Flutter that the user cancelled
         nativeCameraViewChannel?.invokeMethod("cameraResult", arguments: ["type": "cancel"])
     }


     // MARK: - Old Camera Handler Code (To be removed) -
     /*
     // MARK: - Camera Method Channel Handler - (REMOVED)
     private func handleCameraMethodCall(...) { ... }

     // MARK: - CameraHandlerDelegate Methods - (REMOVED)
     func didFindBarcode(...) { ... }
     func didCapturePhoto(...) { ... }
     func cameraSetupFailed(...) { ... }
     func cameraAccessDenied(...) { ... }
     func cameraInitialized(...) { ... }
     func zoomLevelsAvailable(...) { ... }
     */


     // MARK: - Stats and Other Methods (Keep these) -
    
    private func initializeStatsServices(completion: @escaping (Bool) -> Void) {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(true) // Return true even if HealthKit isn't available
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
    
    // Add messaging delegate methods
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("Firebase registration token: \(String(describing: fcmToken))")
        // Optionally: Send token to your backend server
    }

    // MARK: - Remote Notifications Registration

    override func application(_ application: UIApplication,
                        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("[AppDelegate] Registered for remote notifications with token.")
        // Pass device token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
    }

    override func application(_ application: UIApplication,
                        didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - App Lifecycle (No changes needed for NativeCameraViewController presentation) -
    // Keep existing applicationWillResignActive, applicationDidBecomeActive, applicationWillTerminate
    // They don't directly interact with the modally presented NativeCameraViewController lifecycle,
    // which manages its own session start/stop in viewWillAppear/viewWillDisappear.
}
