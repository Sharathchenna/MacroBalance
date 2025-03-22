import Foundation
import HealthKit
import UIKit

class StatsDataManager: StatsDataProvider {
    static let shared = StatsDataManager()
    private let healthStore = HKHealthStore()
    private let defaults = UserDefaults.standard
    private let weightEntriesKey = "weightEntries"
    
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
        // First try to get saved weight entries
        if let savedEntries = loadSavedWeightEntries() {
            // Filter to entries from last few weeks based on current period
            completion(savedEntries)
            return
        }
        
        // Fall back to HealthKit if available
        if HKHealthStore.isHealthDataAvailable() {
            fetchWeightFromHealthKit { healthKitEntries in
                if !healthKitEntries.isEmpty {
                    completion(healthKitEntries)
                    return
                }
                
                // Fall back to mock data if nothing else is available
                completion(self.generateMockWeightData())
            }
            return
        }
        
        // If HealthKit is not available, use mock data
        completion(generateMockWeightData())
    }
    
    private func fetchWeightFromHealthKit(completion: @escaping ([WeightEntry]) -> Void) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion([])
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .month, value: -3, to: now)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictEndDate
        )
        
        let query = HKSampleQuery(
            sampleType: weightType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
        ) { (query, samples, error) in
            guard let samples = samples as? [HKQuantitySample], error == nil else {
                print("Error fetching weight data: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }
            
            // Get user's preferred weight unit
            let weightUnit = self.defaults.string(forKey: "weight_unit") ?? "kg"
            let unit: HKUnit = weightUnit == "kg" ? .gramUnit(with: .kilo) : .pound()
            
            // Convert to WeightEntry objects
            let entries = samples.map { sample in
                let weight = sample.quantity.doubleValue(for: unit)
                return WeightEntry(
                    date: sample.endDate,
                    weight: weight,
                    unit: weightUnit
                )
            }
            
            completion(entries)
        }
        
        healthStore.execute(query)
    }
    
    private func loadSavedWeightEntries() -> [WeightEntry]? {
        guard let data = defaults.data(forKey: weightEntriesKey) else { return nil }
        
        do {
            let entriesData = try JSONDecoder().decode([WeightEntryData].self, from: data)
            return entriesData.map { entryData in
                WeightEntry(
                    date: Date(timeIntervalSince1970: entryData.timestamp),
                    weight: entryData.weight,
                    unit: entryData.unit
                )
            }
        } catch {
            print("Error decoding weight entries: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func generateMockWeightData() -> [WeightEntry] {
        let calendar = Calendar.current
        let today = Date()
        let weightUnit = defaults.string(forKey: "weight_unit") ?? "kg"
        
        // Generate a trend with some natural variations
        let baseWeight = weightUnit == "kg" ? 70.0 : 154.0
        var currentWeight = baseWeight
        let trend = -0.2 // slight downward trend
        
        // Create 30 days of weight entries with a realistic pattern
        return (0..<30).map { days -> WeightEntry in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            
            // Apply trend and add some random variation
            let dailyVariation = Double.random(in: -0.3...0.4)
            let weekendEffect = calendar.isDateInWeekend(date) ? 0.1 : 0.0 // slight increase on weekends
            
            if days > 0 { // Don't modify the first entry
                currentWeight += trend + dailyVariation + weekendEffect
            }
            
            return WeightEntry(date: date, weight: currentWeight, unit: weightUnit)
        }.reversed() // Return in chronological order
    }
    
    func fetchStepData(completion: @escaping ([StepsEntry]) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(generateMockStepData())
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
                completion(self.generateMockStepData())
                return
            }
            
            var entries: [StepsEntry] = []
            results.enumerateStatistics(from: startDate, to: now) { statistics, stop in
                let count = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                entries.append(StepsEntry(
                    date: statistics.startDate,
                    steps: Int(count),
                    goal: self.defaults.integer(forKey: "steps_goal") > 0 ? self.defaults.integer(forKey: "steps_goal") : 10000
                ))
            }
            
            completion(entries)
        }
        
        healthStore.execute(query)
    }
    
    private func generateMockStepData() -> [StepsEntry] {
        let calendar = Calendar.current
        let today = Date()
        let stepsGoal = defaults.integer(forKey: "steps_goal") > 0 ? defaults.integer(forKey: "steps_goal") : 10000
        
        return (0..<7).map { days -> StepsEntry in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            let isWeekend = calendar.isDateInWeekend(date)
            
            // Weekend has fewer steps on average
            let steps = isWeekend ? 
                Int.random(in: 6000...9000) : 
                Int.random(in: 7500...12000)
                
            return StepsEntry(date: date, steps: steps, goal: stepsGoal)
        }.reversed()
    }
    
    func fetchCalorieData(completion: @escaping ([CaloriesEntry]) -> Void) {
        // For now using mock data, can be enhanced to use real data from food tracking
        let calendar = Calendar.current
        let today = Date()
        
        let caloriesGoal = defaults.double(forKey: "calories_goal") > 0 ? 
            defaults.double(forKey: "calories_goal") : 2500
        
        let entries = (0..<7).map { days -> CaloriesEntry in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            let calories = Double.random(in: 1800...2200)
            return CaloriesEntry(
                date: date,
                calories: calories,
                goal: caloriesGoal,
                consumed: calories,
                burned: Double.random(in: 200...500)
            )
        }
        completion(entries.reversed())
    }
    
    func fetchMacroData(completion: @escaping ([MacrosEntry]) -> Void) {
        let calendar = Calendar.current
        let today = Date()
        
        // Get macro goals from settings
        let proteinGoal = defaults.double(forKey: "protein_goal") > 0 ? 
            defaults.double(forKey: "protein_goal") : 150
        let carbGoal = defaults.double(forKey: "carbs_goal") > 0 ? 
            defaults.double(forKey: "carbs_goal") : 250
        let fatGoal = defaults.double(forKey: "fat_goal") > 0 ? 
            defaults.double(forKey: "fat_goal") : 65
        
        let entries = (0..<7).map { days -> MacrosEntry in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            return MacrosEntry(
                date: date,
                proteins: Double.random(in: 120...150),
                carbs: Double.random(in: 200...250),
                fats: Double.random(in: 50...65),
                proteinGoal: proteinGoal,
                carbGoal: carbGoal,
                fatGoal: fatGoal
            )
        }
        
        completion(entries.reversed())
    }
    
    func saveWeightEntry(_ entry: WeightEntry, completion: @escaping (Bool) -> Void) {
        // Load existing entries
        var entries = loadSavedWeightEntries() ?? []
        
        // Add new entry
        entries.append(entry)
        
        // Sort by date
        entries.sort { $0.date < $1.date }
        
        // Convert to saveable format
        let entriesData = entries.map { entry -> WeightEntryData in
            return WeightEntryData(
                timestamp: entry.date.timeIntervalSince1970,
                weight: entry.weight,
                unit: entry.unit
            )
        }
        
        // Encode and save
        do {
            let data = try JSONEncoder().encode(entriesData)
            defaults.set(data, forKey: weightEntriesKey)
            
            // Optionally save to HealthKit if available
            if HKHealthStore.isHealthDataAvailable() {
                saveWeightToHealthKit(entry) { success in
                    completion(success)
                }
            } else {
                completion(true)
            }
        } catch {
            print("Error encoding weight entries: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    private func saveWeightToHealthKit(_ entry: WeightEntry, completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable(),
              let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            completion(false)
            return
        }
        
        // Check if we have permissions to save
        healthStore.getRequestStatusForAuthorization(
            toShare: [weightType], 
            read: [weightType]) { status, error in
            
            guard status == .unnecessary || status == .shouldRequest else {
                completion(false)
                return
            }
            
            // Convert to the right unit
            let unit: HKUnit = entry.unit == "kg" ? .gramUnit(with: .kilo) : .pound()
            let quantity = HKQuantity(unit: unit, doubleValue: entry.weight)
            
            // Create the weight sample
            let sample = HKQuantitySample(
                type: weightType,
                quantity: quantity,
                start: entry.date,
                end: entry.date
            )
            
            // Save to HealthKit
            self.healthStore.save(sample) { success, error in
                if let error = error {
                    print("Error saving weight to HealthKit: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
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

// Data structure for persisting weight entries
struct WeightEntryData: Codable {
    let timestamp: TimeInterval
    let weight: Double
    let unit: String
}