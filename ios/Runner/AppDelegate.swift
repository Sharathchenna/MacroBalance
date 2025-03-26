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
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
    private var methodHandler: FlutterMethodHandler?
    private var statsMethodHandler: StatsMethodHandler?
    
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

        // Explicitly configure Firebase here BEFORE registering plugins
        FirebaseApp.configure()
        print("[AppDelegate] Firebase configured via FirebaseApp.configure()")
        
        GeneratedPluginRegistrant.register(with: self)
        
        // Note: FirebaseApp.configure() is now handled in Flutter code (comment remains, but we added configure above)
        // Just set up the messaging delegate
        Messaging.messaging().delegate = self
        
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
}
