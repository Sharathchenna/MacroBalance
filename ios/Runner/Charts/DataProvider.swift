import Foundation

class StatsDataManager: StatsDataProvider {
    static let shared = StatsDataManager()
    private let defaults = UserDefaults.standard
    
    private let weightKey = "stored_weight_entries"
    private let calorieKey = "stored_calorie_entries"
    private let macroKey = "stored_macro_entries"
    
    private init() {}
    
    func fetchWeightData(completion: @escaping ([WeightEntryModel]) -> Void) {
        // For now, return mock data
        let calendar = Calendar.current
        let today = Date()
        
        let entries = (0..<7).map { days -> WeightEntryModel in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            return WeightEntryModel(date: date, weight: Double.random(in: 70...72))
        }
        
        completion(entries)
    }
    
    func fetchCalorieData(completion: @escaping ([CalorieEntryModel]) -> Void) {
        let calendar = Calendar.current
        let today = Date()
        
        let entries = (0..<7).map { days -> CalorieEntryModel in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            return CalorieEntryModel(
                date: date,
                consumed: Double.random(in: 1800...2200),
                burned: Double.random(in: 300...500),
                goal: 2200
            )
        }
        
        completion(entries)
    }
    
    func fetchMacroData(completion: @escaping ([MacroEntryModel]) -> Void) {
        let calendar = Calendar.current
        let today = Date()
        
        let entries = (0..<7).map { days -> MacroEntryModel in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            return MacroEntryModel(
                date: date,
                protein: Double.random(in: 120...150),
                carbs: Double.random(in: 200...250),
                fat: Double.random(in: 50...65),
                proteinGoal: 150,
                carbsGoal: 250,
                fatGoal: 65
            )
        }
        
        completion(entries)
    }
    
    func fetchStepData(completion: @escaping ([StepEntryModel]) -> Void) {
        let calendar = Calendar.current
        let today = Date()
        
        let entries = (0..<7).map { days -> StepEntryModel in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            return StepEntryModel(
                date: date,
                steps: Int.random(in: 8000...12000),
                goal: 10000,
                distance: Double.random(in: 6...8),
                calories: Double.random(in: 300...400),
                activeMinutes: Int.random(in: 30...60)
            )
        }
        
        completion(entries)
    }
    
    func saveWeightEntry(_ entry: WeightEntryModel, completion: @escaping (Bool) -> Void) {
        // TODO: Implement actual data persistence
        completion(true)
    }
    
    func saveCalorieEntry(_ entry: CalorieEntryModel, completion: @escaping (Bool) -> Void) {
        // TODO: Implement actual data persistence
        completion(true)
    }
    
    func saveMacroEntry(_ entry: MacroEntryModel, completion: @escaping (Bool) -> Void) {
        // TODO: Implement actual data persistence
        completion(true)
    }
    
    // MARK: - Private Helper Methods
    
    private func encode<T: Encodable>(_ data: T) -> Data? {
        try? JSONEncoder().encode(data)
    }
    
    private func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}