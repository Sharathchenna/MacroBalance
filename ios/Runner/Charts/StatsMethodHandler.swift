import Flutter
import Foundation

class StatsMethodHandler {
    private let channel: FlutterMethodChannel
    private let dataManager = StatsDataManager.shared
    
    init(messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(
            name: "app.macrobalance.com/stats",
            binaryMessenger: messenger
        )
        setupMethodCallHandler()
    }
    
    private func setupMethodCallHandler() {
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }
            
            switch call.method {
            case "initialize":
                // Initialize any required services
                self.dataManager.setup { success in
                    if success {
                        result(nil)
                    } else {
                        result(FlutterError(code: "INIT_FAILED",
                                          message: "Failed to initialize stats services",
                                          details: nil))
                    }
                }
            case "fetchStats":
                self.fetchStats(completion: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    private func fetchStats(completion: @escaping FlutterResult) {
        var stats: [String: Any] = [:]
        let group = DispatchGroup()
        
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
                "protein": $0.protein,
                "carbs": $0.carbs,
                "fat": $0.fat,
                "proteinGoal": $0.proteinGoal,
                "carbGoal": $0.carbGoal,
                "fatGoal": $0.fatGoal
            ] }
            group.leave()
        }
        
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
        
        group.notify(queue: .main) {
            completion(stats)
        }
    }
}