import Foundation

struct StatsData {
    struct Weight {
        let date: Date
        let weight: Double
        let unit: String
        
        func toDict() -> [String: Any] {
            return [
                "date": date.timeIntervalSince1970,
                "weight": weight,
                "unit": unit
            ]
        }
        
        static func fromDict(_ dict: [String: Any]) -> Weight? {
            guard let timestamp = dict["date"] as? TimeInterval,
                  let weight = dict["weight"] as? Double,
                  let unit = dict["unit"] as? String else {
                return nil
            }
            return Weight(date: Date(timeIntervalSince1970: timestamp),
                        weight: weight,
                        unit: unit)
        }
    }
    
    struct Steps {
        let date: Date
        let count: Int
        let goal: Int
        
        func toDict() -> [String: Any] {
            return [
                "date": date.timeIntervalSince1970,
                "count": count,
                "goal": goal
            ]
        }
        
        static func fromDict(_ dict: [String: Any]) -> Steps? {
            guard let timestamp = dict["date"] as? TimeInterval,
                  let count = dict["count"] as? Int,
                  let goal = dict["goal"] as? Int else {
                return nil
            }
            return Steps(date: Date(timeIntervalSince1970: timestamp),
                        count: count,
                        goal: goal)
        }
    }
    
    struct Calories {
        let date: Date
        let consumed: Int
        let burned: Int
        let goal: Int
        
        func toDict() -> [String: Any] {
            return [
                "date": date.timeIntervalSince1970,
                "consumed": consumed,
                "burned": burned,
                "goal": goal
            ]
        }
        
        static func fromDict(_ dict: [String: Any]) -> Calories? {
            guard let timestamp = dict["date"] as? TimeInterval,
                  let consumed = dict["consumed"] as? Int,
                  let burned = dict["burned"] as? Int,
                  let goal = dict["goal"] as? Int else {
                return nil
            }
            return Calories(date: Date(timeIntervalSince1970: timestamp),
                          consumed: consumed,
                          burned: burned,
                          goal: goal)
        }
    }
    
    struct Macros {
        let date: Date
        let protein: Double
        let carbs: Double
        let fat: Double
        let proteinGoal: Double
        let carbsGoal: Double
        let fatGoal: Double
        
        func toDict() -> [String: Any] {
            return [
                "date": date.timeIntervalSince1970,
                "protein": protein,
                "carbs": carbs,
                "fat": fat,
                "proteinGoal": proteinGoal,
                "carbsGoal": carbsGoal,
                "fatGoal": fatGoal
            ]
        }
        
        static func fromDict(_ dict: [String: Any]) -> Macros? {
            guard let timestamp = dict["date"] as? TimeInterval,
                  let protein = dict["protein"] as? Double,
                  let carbs = dict["carbs"] as? Double,
                  let fat = dict["fat"] as? Double,
                  let proteinGoal = dict["proteinGoal"] as? Double,
                  let carbsGoal = dict["carbsGoal"] as? Double,
                  let fatGoal = dict["fatGoal"] as? Double else {
                return nil
            }
            return Macros(date: Date(timeIntervalSince1970: timestamp),
                         protein: protein,
                         carbs: carbs,
                         fat: fat,
                         proteinGoal: proteinGoal,
                         carbsGoal: carbsGoal,
                         fatGoal: fatGoal)
        }
    }
}