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
import AVFoundation  // Added for camera functionality

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate, NativeCameraViewControllerDelegate {
    // Remove these properties
    // private var methodHandler: FlutterMethodHandler?
    // private var statsMethodHandler: StatsMethodHandler?
    
    // Keep the camera view channel for now
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
        
        // Remove these initializations
        // methodHandler = FlutterMethodHandler(window: window, viewController: controller)
        
        // Remove stats handler initialization
        // statsMethodHandler = StatsMethodHandler(...)
        
        // Remove stats view factory registration
        // let statsFactory = StatsViewFactory(...)
        // registrar(forPlugin: "StatsView")?.register(...)

        // Initialize camera view channel
        nativeCameraViewChannel = FlutterMethodChannel(name: nativeCameraViewChannelName,
                                                     binaryMessenger: controller.binaryMessenger)
        nativeCameraViewChannel?.setMethodCallHandler(handleNativeCameraViewMethodCall)

        // Explicitly configure Firebase here BEFORE registering plugins
        FirebaseApp.configure()
        print("[AppDelegate] Firebase configured via FirebaseApp.configure()")
        
        GeneratedPluginRegistrant.register(with: self)
        
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

     // MARK: - Native Camera View Method Channel Handler -

     private func handleNativeCameraViewMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
         print("[AppDelegate] Native Camera View Method Call: \(call.method)")

         guard let controller = window?.rootViewController as? FlutterViewController else {
             result(FlutterError(code: "INTERNAL_ERROR", message: "Cannot get root view controller", details: nil))
             return
         }

         // Handle specific methods
         if call.method == "showNativeCamera" {
             let nativeCameraVC = NativeCameraViewController()
             nativeCameraVC.delegate = self
             nativeCameraVC.modalPresentationStyle = .fullScreen
             controller.present(nativeCameraVC, animated: true, completion: nil)
             result(nil) // Acknowledge successful presentation
         } else {
             result(FlutterMethodNotImplemented)
         }
     }

     // MARK: - NativeCameraViewControllerDelegate Methods -

     func nativeCameraDidFinish(withBarcode barcode: String) {
         print("[AppDelegate] Native Camera Finished with Barcode: \(barcode)")
         // Send result back to Flutter via the channel
         nativeCameraViewChannel?.invokeMethod("cameraResult", arguments: ["type": "barcode", "value": barcode])
     }

     func nativeCameraDidFinish(withPhotoData photoData: Data) {
         print("[AppDelegate] Native Camera Finished with Photo Data: \(photoData.count) bytes")
         // Send result back to Flutter
         nativeCameraViewChannel?.invokeMethod("cameraResult", arguments: ["type": "photo", "value": FlutterStandardTypedData(bytes: photoData)])
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
