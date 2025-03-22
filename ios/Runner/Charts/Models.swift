import Foundation

// MARK: - Data Models
struct WeightEntryModel {
    let date: Date
    let weight: Double
}

struct CalorieEntryModel {
    let date: Date
    let consumed: Double
    let burned: Double
    let goal: Double
}

struct MacroEntryModel {
    let date: Date
    let protein: Double
    let carbs: Double
    let fat: Double
    let proteinGoal: Double
    let carbsGoal: Double
    let fatGoal: Double
}

struct StepEntryModel {
    let date: Date
    let steps: Int
    let goal: Int
    let distance: Double
    let calories: Double
    let activeMinutes: Int
}

// MARK: - Data Provider Protocol
protocol StatsDataProvider {
    func fetchWeightData(completion: @escaping ([WeightEntryModel]) -> Void)
    func fetchCalorieData(completion: @escaping ([CalorieEntryModel]) -> Void)
    func fetchMacroData(completion: @escaping ([MacroEntryModel]) -> Void)
    func fetchStepData(completion: @escaping ([StepEntryModel]) -> Void)
    
    func saveWeightEntry(_ entry: WeightEntryModel, completion: @escaping (Bool) -> Void)
    func saveCalorieEntry(_ entry: CalorieEntryModel, completion: @escaping (Bool) -> Void)
    func saveMacroEntry(_ entry: MacroEntryModel, completion: @escaping (Bool) -> Void)
}