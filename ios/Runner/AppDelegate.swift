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

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var methodHandler: FlutterMethodHandler?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("[AppDelegate] Application launching")
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        
        methodHandler = FlutterMethodHandler(window: window, viewController: controller)
        
        // Register native view factory for stats
        let nativeViewFactory = FLNativeViewFactory(
            messenger: controller.binaryMessenger,
            parentViewController: controller
        )
        registrar(forPlugin: "stats_view")?.register(
            nativeViewFactory,
            withId: "stats_view"
        )
        
        // Stats method channel
        let statsChannel = FlutterMethodChannel(
            name: "app.macrobalance.com/stats",
            binaryMessenger: controller.binaryMessenger
        )
        
        statsChannel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE",
                                  message: "Failed to handle method call",
                                  details: "AppDelegate was deallocated"))
                return
            }
            
            switch call.method {
            case "initialize":
                // Initialize any required services
                self.initializeStatsServices { success in
                    if success {
                        result(nil)
                    } else {
                        result(FlutterError(code: "INIT_FAILED",
                                          message: "Failed to initialize stats services",
                                          details: nil))
                    }
                }
            case "showStats":
                do {
                    try self.showStatsViewController(controller)
                    result(nil)
                } catch {
                    result(FlutterError(code: "SHOW_STATS_FAILED",
                                      message: "Failed to show stats view",
                                      details: error.localizedDescription))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
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

    private func showStatsViewController(_ flutterViewController: FlutterViewController) throws {
        let statsVC = StatsTabBarController()
        let navController = UINavigationController(rootViewController: statsVC)
        navController.modalPresentationStyle = .fullScreen
        flutterViewController.present(navController, animated: true) { [weak self] in
            // Handle completion if needed
        }
    }
}
