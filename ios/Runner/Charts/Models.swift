import Foundation
import SwiftUI

// Create Models namespace as an enum
enum Models {
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

    // Food item
    struct FoodItem: Identifiable, Codable {
        var id: UUID
        var name: String
        var proteins: Double
        var carbs: Double
        var fats: Double
        var servingSize: Double
        var servingUnit: String
        
        var calories: Double {
            return (proteins * 4) + (carbs * 4) + (fats * 9)
        }
        
        init(id: UUID = UUID(), name: String, servingSize: Double, servingUnit: String, proteins: Double, carbs: Double, fats: Double) {
            self.id = id
            self.name = name
            self.servingSize = servingSize
            self.servingUnit = servingUnit
            self.proteins = proteins
            self.carbs = carbs
            self.fats = fats
        }
    }

    // Meal tracking
    struct Meal: Identifiable, Codable {
        var id: UUID
        var name: String
        var time: Date
        var proteins: Double
        var carbs: Double
        var fats: Double
        var foods: [FoodItem]
        
        var calories: Double {
            return (proteins * 4) + (carbs * 4) + (fats * 9)
        }
        
        init(id: UUID = UUID(), name: String, time: Date, proteins: Double, carbs: Double, fats: Double, foods: [FoodItem] = []) {
            self.id = id
            self.name = name
            self.time = time
            self.proteins = proteins
            self.carbs = carbs
            self.fats = fats
            self.foods = foods
        }
    }

    struct MacrosEntry: Identifiable, Codable {
        var id: UUID
        var date: Date
        var proteins: Double
        var carbs: Double
        var fats: Double
        var proteinGoal: Double
        var carbGoal: Double
        var fatGoal: Double
        var micronutrients: [Micronutrient]
        var water: Double // Water intake in ml
        var waterGoal: Double // Water goal in ml
        var meals: [Meal]?
        var fiber: Double = 0 // Added fiber property
        
        // Computed properties
        var calories: Double { 
            (proteins * 4) + (carbs * 4) + (fats * 9) 
        }
        
        var calorieGoal: Double { 
            (proteinGoal * 4) + (carbGoal * 4) + (fatGoal * 9) 
        }
        
        // Percentage calculations
        var proteinPercentage: Double { 
            calories > 0 ? (proteins * 4) / calories * 100 : 0 
        }
        
        var carbsPercentage: Double { 
            calories > 0 ? (carbs * 4) / calories * 100 : 0 
        }
        
        var fatsPercentage: Double { 
            calories > 0 ? (fats * 9) / calories * 100 : 0 
        }
        
        // Goal achievement percentages
        var proteinGoalPercentage: Double {
            proteinGoal > 0 ? proteins / proteinGoal * 100 : 0
        }
        
        var carbGoalPercentage: Double {
            carbGoal > 0 ? carbs / carbGoal * 100 : 0
        }
        
        var fatGoalPercentage: Double {
            fatGoal > 0 ? fats / fatGoal * 100 : 0
        }
        
        var calorieGoalPercentage: Double {
            calorieGoal > 0 ? calories / calorieGoal * 100 : 0
        }
        
        var waterPercentage: Double {
            waterGoal > 0 ? water / waterGoal * 100 : 0
        }
        
        // Helper methods
        func getPercentage(for nutrientType: NutrientType) -> Double {
            switch nutrientType {
            case .protein: return proteinPercentage
            case .carbs: return carbsPercentage
            case .fat: return fatsPercentage
            }
        }
    }
    
    // Micronutrient model
    struct Micronutrient: Identifiable, Codable {
        var id: String
        var name: String
        var amount: Double
        var goal: Double
        var unit: String
        var category: String
        
        var percentOfGoal: Double {
            guard goal > 0 else { return 0 }
            return min((amount / goal) * 100, 200) // Cap at 200%
        }
        
        init(id: String? = nil, name: String, amount: Double, goal: Double, unit: String, category: String) {
            self.id = id ?? UUID().uuidString
            self.name = name
            self.amount = amount
            self.goal = goal
            self.unit = unit
            self.category = category
        }
        
        init(name: String, amount: Double, goal: Double, unit: String, category: MicronutrientCategory) {
            self.id = UUID().uuidString
            self.name = name
            self.amount = amount
            self.goal = goal
            self.unit = unit
            self.category = category.rawValue
        }
    }
}

// MARK: - Extensions
extension Models.MacrosEntry {
    static var sampleData: [Models.MacrosEntry] {
        let calendar = Calendar.current
        let today = Date()
        
        let micronutrients = [
            Models.Micronutrient(name: "Vitamin C", amount: 65, goal: 90, unit: "mg", category: .vitamins),
            Models.Micronutrient(name: "Vitamin D", amount: 10, goal: 15, unit: "μg", category: .vitamins),
            Models.Micronutrient(name: "Calcium", amount: 850, goal: 1000, unit: "mg", category: .minerals),
            Models.Micronutrient(name: "Iron", amount: 12, goal: 18, unit: "mg", category: .minerals),
            Models.Micronutrient(name: "Fiber", amount: 22, goal: 30, unit: "g", category: .other)
        ]
        
        let meals = [
            Models.Meal(
                name: "Breakfast",
                time: Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date())!,
                proteins: 25,
                carbs: 45,
                fats: 15
            ),
            Models.Meal(
                name: "Lunch",
                time: Calendar.current.date(bySettingHour: 13, minute: 15, second: 0, of: Date())!,
                proteins: 40,
                carbs: 65,
                fats: 20
            ),
            Models.Meal(
                name: "Dinner",
                time: Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!,
                proteins: 45,
                carbs: 70,
                fats: 25
            )
        ]
        
        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            return Models.MacrosEntry(
                id: UUID(),
                date: date,
                proteins: Double.random(in: 100...150),
                carbs: Double.random(in: 200...300),
                fats: Double.random(in: 50...80),
                proteinGoal: 140,
                carbGoal: 250,
                fatGoal: 65,
                micronutrients: micronutrients,
                water: Double.random(in: 1500...2500),
                waterGoal: 2500,
                meals: meals,
                fiber: Double.random(in: 15...35) // Adding fiber data
            )
        }
    }
    
    // Add the missing generateSampleData method
    static func generateSampleData(from startDate: Date, to endDate: Date) -> [Models.MacrosEntry] {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1
        
        let micronutrients = [
            Models.Micronutrient(name: "Vitamin C", amount: 65, goal: 90, unit: "mg", category: .vitamins),
            Models.Micronutrient(name: "Vitamin D", amount: 10, goal: 15, unit: "μg", category: .vitamins),
            Models.Micronutrient(name: "Calcium", amount: 850, goal: 1000, unit: "mg", category: .minerals),
            Models.Micronutrient(name: "Iron", amount: 12, goal: 18, unit: "mg", category: .minerals),
            Models.Micronutrient(name: "Fiber", amount: 22, goal: 30, unit: "g", category: .other)
        ]
        
        return (0..<max(1, days)).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: endDate)!
            
            // Generate random meal data
            let meals = [
                Models.Meal(
                    name: "Breakfast",
                    time: calendar.date(bySettingHour: 8, minute: 30, second: 0, of: date)!,
                    proteins: Double.random(in: 20...30),
                    carbs: Double.random(in: 40...50),
                    fats: Double.random(in: 10...20)
                ),
                Models.Meal(
                    name: "Lunch",
                    time: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: date)!,
                    proteins: Double.random(in: 35...45),
                    carbs: Double.random(in: 60...70),
                    fats: Double.random(in: 15...25)
                ),
                Models.Meal(
                    name: "Dinner",
                    time: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: date)!,
                    proteins: Double.random(in: 40...50),
                    carbs: Double.random(in: 65...75),
                    fats: Double.random(in: 20...30)
                )
            ]
            
            return Models.MacrosEntry(
                id: UUID(),
                date: date,
                proteins: Double.random(in: 100...150),
                carbs: Double.random(in: 200...300),
                fats: Double.random(in: 50...80),
                proteinGoal: 140,
                carbGoal: 250,
                fatGoal: 65,
                micronutrients: micronutrients,
                water: Double.random(in: 1500...2500),
                waterGoal: 2500,
                meals: meals,
                fiber: Double.random(in: 15...35)
            )
        }
    }
}

// Define NutrientType for consistent usage across charts
enum NutrientType: String, CaseIterable, Identifiable {
    case protein
    case carbs
    case fat
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .protein: return "Protein"
        case .carbs: return "Carbohydrates"
        case .fat: return "Fat"
        }
    }
    
    var energyPerGram: Double {
        switch self {
        case .protein: return 4
        case .carbs: return 4
        case .fat: return 9
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .protein: return Color.proteinColor
        case .carbs: return Color.carbColor
        case .fat: return Color.fatColor
        }
    }
}

// Micronutrient categories
enum MicronutrientCategory: String, CaseIterable, Identifiable {
    case vitamins = "Vitamins"
    case minerals = "Minerals"
    case other = "Other Nutrients"
    
    var id: String { self.rawValue }
    
    var displayName: String { self.rawValue }
}

// MARK: - Data Provider Protocol
protocol StatsDataProvider {
    func fetchWeightData(completion: @escaping ([Models.WeightEntry]) -> Void)
    func fetchCalorieData(completion: @escaping ([Models.CaloriesEntry]) -> Void)
    func fetchMacroData(completion: @escaping ([Models.MacrosEntry]) -> Void)
    func fetchStepData(completion: @escaping ([Models.StepsEntry]) -> Void)
    
    func saveWeightEntry(_ entry: Models.WeightEntry, completion: @escaping (Bool) -> Void)
    func saveCalorieEntry(_ entry: Models.CaloriesEntry, completion: @escaping (Bool) -> Void)
    func saveMacroEntry(_ entry: Models.MacrosEntry, completion: @escaping (Bool) -> Void)
}

// Period for viewing stats
enum ViewPeriod: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    
    var id: String { self.rawValue }
}

// Removing duplicate color definitions as they are now in ChartUtilities.swift