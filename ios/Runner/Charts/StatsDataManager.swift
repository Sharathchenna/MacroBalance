import Foundation
import HealthKit
import UIKit

class StatsDataManager: StatsDataProvider {
    static let shared = StatsDataManager()
    private let healthStore = HKHealthStore()
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    func setup(completion: @escaping (Bool) -> Void) {
        // Check if HealthKit is available on this device
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(true) // Return true even if HealthKit isn't available, as we can show basic stats
            return
        }
        
        // Request authorization for the health data types we need
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit authorization error: \(error.localizedDescription)")
            }
            completion(success)
        }
    }
    
    func fetchWeightData(completion: @escaping ([WeightEntry]) -> Void) {
        let calendar = Calendar.current
        let today = Date()
        
        let entries = (0..<7).map { days -> WeightEntry in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            return WeightEntry(date: date, weight: Double.random(in: 70...72))
        }
        completion(entries.reversed())
    }
    
    func fetchStepData(completion: @escaping ([StepsEntry]) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion([])
            return
        }
        
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        
        query.initialResultsHandler = { query, results, error in
            guard let results = results else {
                completion([])
                return
            }
            
            var entries: [StepsEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { statistics, stop in
                let count = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                entries.append(StepsEntry(
                    date: statistics.startDate,
                    steps: Int(count),
                    goal: 10000
                ))
            }
            
            completion(entries)
        }
        
        healthStore.execute(query)
    }
    
    func fetchCalorieData(completion: @escaping ([CaloriesEntry]) -> Void) {
        let calendar = Calendar.current
        let today = Date()
        
        let entries = (0..<7).map { days -> CaloriesEntry in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            let calories = Double.random(in: 1800...2200)
            return CaloriesEntry(
                date: date,
                calories: calories,
                goal: 2500,
                consumed: calories,
                burned: Double.random(in: 200...500)
            )
        }
        completion(entries.reversed())
    }
    
    func fetchMacroData(completion: @escaping ([MacrosEntry]) -> Void) {
        let calendar = Calendar.current
        let today = Date()
        
        let entries = (0..<7).map { days -> MacrosEntry in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            return MacrosEntry(
                date: date,
                proteins: Double.random(in: 120...150),
                carbs: Double.random(in: 200...250),
                fats: Double.random(in: 50...65)
            )
        }
        completion(entries)
    }
    
    func saveWeightEntry(_ entry: WeightEntry, completion: @escaping (Bool) -> Void) {
        // TODO: Implement persistence
        completion(true)
    }
    
    func saveCalorieEntry(_ entry: CaloriesEntry, completion: @escaping (Bool) -> Void) {
        // TODO: Implement persistence
        completion(true)
    }
    
    func saveMacroEntry(_ entry: MacrosEntry, completion: @escaping (Bool) -> Void) {
        // TODO: Implement persistence
        completion(true)
    }
}