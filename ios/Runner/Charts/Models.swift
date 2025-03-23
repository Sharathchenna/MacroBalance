import Foundation

// MARK: - Data Models
struct WeightEntry: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
    let unit: String
    
    init(date: Date, weight: Double, unit: String = "kg") {
        self.date = date
        self.weight = weight
        self.unit = unit
    }
}

struct StepsEntry: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let steps: Int
    let goal: Int
    
    init(date: Date, steps: Int, goal: Int = 10000) {
        self.date = date
        self.steps = steps
        self.goal = goal
    }
    
    static func == (lhs: StepsEntry, rhs: StepsEntry) -> Bool {
        lhs.id == rhs.id
    }
}

struct CaloriesEntry: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
    let goal: Double
    let consumed: Double
    let burned: Double
    
    init(date: Date, calories: Double, goal: Double = 2500, consumed: Double? = nil, burned: Double = 0) {
        self.date = date
        self.calories = calories
        self.goal = goal
        self.consumed = consumed ?? calories
        self.burned = burned
    }
}

struct MacrosEntry: Identifiable {
    let id = UUID()
    let date: Date
    let proteins: Double
    let carbs: Double
    let fats: Double
    let proteinGoal: Double
    let carbGoal: Double // This was missing the property named carbGoal
    let fatGoal: Double
    
    // Additional nutritional data
    var calories: Double { (proteins * 4) + (carbs * 4) + (fats * 9) }
    var calorieGoal: Double { (proteinGoal * 4) + (carbGoal * 4) + (fatGoal * 9) }
    var micronutrients: [String: Double]?
    var vitamins: [String: Double]?
    var minerals: [String: Double]?
    
    // Computed properties for backward compatibility
    var protein: Double { proteins }
    var fat: Double { fats }
    var carbsGoal: Double { carbGoal } // Add this for backward compatibility
    
    // Percentage calculations
    var proteinPercentage: Double { proteins > 0 ? (proteins * 4) / max(1, calories) * 100 : 0 }
    var carbsPercentage: Double { carbs > 0 ? (carbs * 4) / max(1, calories) * 100 : 0 }
    var fatsPercentage: Double { fats > 0 ? (fats * 9) / max(1, calories) * 100 : 0 }
    
    init(
        date: Date,
        proteins: Double,
        carbs: Double,
        fats: Double,
        proteinGoal: Double = 150,
        carbGoal: Double = 250,
        fatGoal: Double = 65,
        micronutrients: [String: Double]? = nil,
        vitamins: [String: Double]? = nil,
        minerals: [String: Double]? = nil
    ) {
        self.date = date
        self.proteins = proteins
        self.carbs = carbs
        self.fats = fats
        self.proteinGoal = proteinGoal
        self.carbGoal = carbGoal
        self.fatGoal = fatGoal
        self.micronutrients = micronutrients
        self.vitamins = vitamins
        self.minerals = minerals
    }
}

// MARK: - Data Provider Protocol
protocol StatsDataProvider {
    func fetchWeightData(completion: @escaping ([WeightEntry]) -> Void)
    func fetchCalorieData(completion: @escaping ([CaloriesEntry]) -> Void)
    func fetchMacroData(completion: @escaping ([MacrosEntry]) -> Void)
    func fetchStepData(completion: @escaping ([StepsEntry]) -> Void)
    
    func saveWeightEntry(_ entry: WeightEntry, completion: @escaping (Bool) -> Void)
    func saveCalorieEntry(_ entry: CaloriesEntry, completion: @escaping (Bool) -> Void)
    func saveMacroEntry(_ entry: MacrosEntry, completion: @escaping (Bool) -> Void)
}