import UIKit
import Flutter
import SwiftUI
import HealthKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var methodHandler: FlutterMethodHandler?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("[AppDelegate] Application launching")
        let controller = window?.rootViewController as? FlutterViewController
        methodHandler = FlutterMethodHandler(window: window, viewController: controller)
        
        // Set up method channel for native chart data
        if let controller = controller {
            let chartChannel = FlutterMethodChannel(
                name: "app.macrobalance.com/nativecharts",
                binaryMessenger: controller.binaryMessenger
            )
            
            print("[AppDelegate] Setting up method channel")
            chartChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
                print("[AppDelegate] Received method call: \(call.method)")
                switch call.method {
                case "createWeightChart", "createStepsChart", "createCaloriesChart", "createMacrosChart":
                    if let args = call.arguments as? [String: Any],
                       let data = args["data"] as? [[String: Any]] {
                        print("[AppDelegate] Processing chart data: \(data.count) entries")
                        // Return success instead of just echoing the data
                        result("success")
                    } else {
                        print("[AppDelegate] Invalid arguments for method: \(call.method)")
                        result(FlutterError(code: "INVALID_ARGUMENTS", 
                                        message: "Invalid arguments for chart", 
                                        details: nil))
                    }
                    
                default:
                    print("[AppDelegate] Method not implemented: \(call.method)")
                    result(FlutterMethodNotImplemented)
                }
            }
            
            print("[AppDelegate] Registering platform view factories")
            registerPlatformViewFactories(controller: controller)
        }
        
        // Register method handler for goals
        let goalsChannel = FlutterMethodChannel(
            name: "app.macrobalance.com/goals",
            binaryMessenger: controller!.binaryMessenger)
        
        goalsChannel.setMethodCallHandler { [weak self] call, result in
            guard let strongSelf = self else { return }
            
            switch call.method {
            case "showGoalsView":
                let goalsVC = GoalsViewController()
                if let args = call.arguments as? [String: Any],
                   let initialSection = args["initialSection"] as? String {
                    goalsVC.initialSection = initialSection
                }
                
                controller?.present(UINavigationController(rootViewController: goalsVC),
                                 animated: true) {
                    result(nil)
                }
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        // Register goals view factory
        let goalsFactory = FLNativeViewFactory(
            messenger: controller!.binaryMessenger,
            parentViewController: controller
        )
        registrar(forPlugin: "goals_view")?.register(
            goalsFactory,
            withId: "goals_view"
        )

        // Setup method channel for stats tab view
        let statsChannel = FlutterMethodChannel(
            name: "app.macrobalance.com.stats/tabview",
            binaryMessenger: controller!.binaryMessenger
        )
        
        statsChannel.setMethodCallHandler { [weak self] call, result in
            guard let strongSelf = self else { return }
            
            switch call.method {
            case "showStatsTabView":
                let tabController = StatsTabBarController()
                controller?.present(
                    UINavigationController(rootViewController: tabController),
                    animated: true
                ) {
                    result(nil)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Stats method channel
        let statsChannelNew = FlutterMethodChannel(
            name: "com.macrobalance.app.stats",
            binaryMessenger: controller!.binaryMessenger
        )
        
        statsChannelNew.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "showStats":
                self?.showStatsViewController(controller)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func registerPlatformViewFactories(controller: FlutterViewController) {
        // Register view factories for each chart type
        print("[AppDelegate] Creating and registering chart factories")
        
        let weightChartFactory = FLNativeViewFactory(messenger: controller.binaryMessenger, parentViewController: controller)
        registrar(forPlugin: "weightChart")?.register(weightChartFactory, withId: "weightChart")
        print("[AppDelegate] Registered weight chart factory")
        
        let stepsChartFactory = FLNativeViewFactory(messenger: controller.binaryMessenger, parentViewController: controller)
        registrar(forPlugin: "stepsChart")?.register(stepsChartFactory, withId: "stepsChart")
        print("[AppDelegate] Registered steps chart factory")
        
        let caloriesChartFactory = FLNativeViewFactory(messenger: controller.binaryMessenger, parentViewController: controller)
        registrar(forPlugin: "caloriesChart")?.register(caloriesChartFactory, withId: "caloriesChart")
        print("[AppDelegate] Registered calories chart factory")
        
        let macrosChartFactory = FLNativeViewFactory(messenger: controller.binaryMessenger, parentViewController: controller)
        registrar(forPlugin: "macrosChart")?.register(macrosChartFactory, withId: "macrosChart")
        print("[AppDelegate] Registered macros chart factory")
    }

    private func showStatsViewController(_ flutterViewController: FlutterViewController?) {
        guard let flutterViewController = flutterViewController else { return }
        
        let statsVC = StatsTabBarController()
        let navController = UINavigationController(rootViewController: statsVC)
        navController.modalPresentationStyle = .fullScreen
        flutterViewController.present(navController, animated: true)
    }
}
