import UIKit
import Flutter
import SwiftUI

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        print("[AppDelegate] Application launching")
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        // Set up method channel for native chart data
        let chartChannel = FlutterMethodChannel(
            name: "app.macrobalance.com/nativecharts",
            binaryMessenger: controller.binaryMessenger
        )
        
        print("[AppDelegate] Setting up method channel")
        chartChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            print("[AppDelegate] Received method call: \(call.method)")
            switch call.method {
            case "createWeightChart", "createStepsChart", "createCaloriesChart":
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
    }
}
