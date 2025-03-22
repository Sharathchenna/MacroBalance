import Flutter
import UIKit

class FlutterMethodHandler: NSObject {
    private weak var window: UIWindow?
    private weak var viewController: FlutterViewController?
    
    init(window: UIWindow?, viewController: FlutterViewController?) {
        self.window = window
        self.viewController = viewController
        super.init()
        setupMethodChannels()
    }
    
    private func setupMethodChannels() {
        guard let controller = viewController else {
            print("[FlutterMethodHandler] No view controller available")
            return
        }
        
        let goalsChannel = FlutterMethodChannel(
            name: "app.macrobalance.com/goals",
            binaryMessenger: controller.binaryMessenger
        )
        
        goalsChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "showGoalsView":
                self?.handleShowGoalsView(call: call, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func handleShowGoalsView(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let viewController = self.viewController else {
            result(FlutterError(code: "VIEW_CONTROLLER_ERROR",
                              message: "Flutter view controller not available",
                              details: nil))
            return
        }
        
        let goalsViewController = GoalsViewController()
        let navigationController = UINavigationController(rootViewController: goalsViewController)
        
        if let args = call.arguments as? [String: Any],
           let initialSection = args["initialSection"] as? String {
            goalsViewController.initialSection = initialSection
        }
        
        viewController.present(navigationController, animated: true) {
            result(nil)
        }
    }
}