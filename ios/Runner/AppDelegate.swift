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

@main
@objc class AppDelegate: FlutterAppDelegate {
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
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
        }
        GeneratedPluginRegistrant.register(with: self)
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
}
