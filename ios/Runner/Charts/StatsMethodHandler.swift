import Flutter
import Foundation
import UIKit

// Add a Notification Name constant
extension Notification.Name {
    static let macrosDataDidChange = Notification.Name("macrosDataDidChangeNotification")
}

class StatsMethodHandler: NSObject {
    // Channel for communication with Flutter
    private let channel: FlutterMethodChannel
    
    // Data manager for accessing stats data
    private let dataManager = StatsDataManager.shared
    
    // Reference to parent view controller
    private weak var parentViewController: FlutterViewController?
    
    // State tracking
    private var isPresenting = false
    private var dismissTimer: Timer?
    
    init(messenger: FlutterBinaryMessenger, parentViewController: FlutterViewController) {
        self.channel = FlutterMethodChannel(
            name: "app.macrobalance.com/stats",
            binaryMessenger: messenger
        )
        self.parentViewController = parentViewController
        super.init()
        setupMethodCallHandler()
    }
    
    deinit {
        dismissTimer?.invalidate()
    }
    
    // MARK: - Method Channel Setup
    
    private func setupMethodCallHandler() {
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { 
                result(FlutterError(code: "UNAVAILABLE", 
                                  message: "StatsMethodHandler was deallocated",
                                  details: nil))
                return
            }
            
            switch call.method {
            case "showStats":
                let args = call.arguments as? [String: Any]
                let initialSection = args?["initialSection"] as? String ?? "weight"
                self.handleShowStats(initialSection: initialSection, result: result)
                
            case "fetchStats":
                self.fetchStats(result: result)

            case "macrosDataChanged":
                // Received notification from Flutter that data changed
                print("[StatsMethodHandler] Received macrosDataChanged notification from Flutter.")
                // Ensure posting happens on the main thread for UI observers
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .macrosDataDidChange, object: nil)
                    print("[StatsMethodHandler] Posted .macrosDataDidChange notification on main thread.") // Add log
                }
                result(nil) // Acknowledge the call

            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    // MARK: - Show Stats Handler
    
    private func handleShowStats(initialSection: String, result: @escaping FlutterResult) {
        // Run on main thread for UI operations
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", 
                                  message: "StatsMethodHandler was deallocated",
                                  details: nil))
                return
            }
            
            // Check if we're already presenting to avoid duplicate presentations
            guard !self.isPresenting else {
                result(FlutterError(code: "ALREADY_PRESENTING",
                                  message: "A stats screen is already being presented",
                                  details: nil))
                return
            }
            
            guard let parentVC = self.parentViewController else {
                result(FlutterError(code: "UNAVAILABLE",
                                  message: "Parent view controller is not available",
                                  details: nil))
                return
            }
            
            // Mark as presenting
            self.isPresenting = true
            
            // If there's already a presented controller, dismiss it first
            if let presented = parentVC.presentedViewController {
                presented.dismiss(animated: false) { [weak self] in
                    self?.presentStatsController(parentVC: parentVC, initialSection: initialSection, result: result)
                }
            } else {
                // Present directly if no existing controller
                self.presentStatsController(parentVC: parentVC, initialSection: initialSection, result: result)
            }
        }
    }
    
    private func presentStatsController(parentVC: FlutterViewController, initialSection: String, result: @escaping FlutterResult) {
        // Create the tab controller
        let statsVC = StatsTabBarController()
        statsVC.navigateToSection(initialSection)
        
        // Set dismissal callback
        statsVC.onDismiss = { [weak self] in
            guard let self = self else { return }
            
            // Reset presentation state
            self.isPresenting = false
            
            // Cancel any pending timers
            self.dismissTimer?.invalidate()
            self.dismissTimer = nil
        }
        
        // Wrap in navigation controller with proper presentation style
        let navController = UINavigationController(rootViewController: statsVC)
        navController.modalPresentationStyle = .fullScreen
        
        // Present the controller
        parentVC.present(navController, animated: true) {
            // Report success to Flutter
            result(nil)
            
            // Set a failsafe timer to reset state if the dismissal callback isn't called
            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                
                // Check if the screen is still showing after our timer
                if parentVC.presentedViewController == navController {
                    // Screen is still showing, do nothing
                } else {
                    // Screen is gone but callback wasn't triggered, reset state
                    self.isPresenting = false
                    self.dismissTimer = nil
                }
            }
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchStats(result: @escaping FlutterResult) {
        // Create container for stats data
        var stats: [String: Any] = [:]
        let group = DispatchGroup()
        
        // Fetch weight data
        group.enter()
        dataManager.fetchWeightData { entries in
            stats["weight"] = entries.map { [
                "date": ISO8601DateFormatter().string(from: $0.date),
                "weight": $0.weight,
                "unit": $0.unit
            ] }
            group.leave()
        }
        
        // Fetch steps data
        group.enter()
        dataManager.fetchStepData { entries in
            stats["steps"] = entries.map { [
                "date": ISO8601DateFormatter().string(from: $0.date),
                "steps": $0.steps,
                "goal": $0.goal
            ] }
            group.leave()
        }
        
        // Fetch calories data
        group.enter()
        dataManager.fetchCalorieData { entries in
            stats["calories"] = entries.map { [
                "date": ISO8601DateFormatter().string(from: $0.date),
                "consumed": $0.consumed,
                "burned": $0.burned,
                "goal": $0.goal
            ] }
            group.leave()
        }
        
        // Fetch macros data
        group.enter()
        dataManager.fetchMacroData { entries in
            stats["macros"] = entries.map { [
                "date": ISO8601DateFormatter().string(from: $0.date),
                "protein": $0.proteins,
                "carbs": $0.carbs,
                "fat": $0.fats,
                "proteinGoal": $0.proteinGoal,
                "carbGoal": $0.carbGoal,
                "fatGoal": $0.fatGoal
            ] }
            group.leave()
        }
        
        // Return all stats when all fetches complete
        group.notify(queue: .main) {
            result(stats)
        }
    }
}
