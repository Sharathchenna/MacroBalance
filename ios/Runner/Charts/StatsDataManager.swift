import Foundation
import HealthKit
import UIKit
import Flutter

class StatsDataManager: StatsDataProvider {
    static let shared = StatsDataManager()
    private let healthStore = HKHealthStore()
    private let defaults = UserDefaults.standard
    private let weightEntriesKey = "weightEntries"
    private var messenger: FlutterBinaryMessenger?
    
    private init() {
        // Initialize without messenger
    }
    
    func configure(with messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }
    
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
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        fetchStepData(from: startDate, to: endDate, completion: completion)
    }
    
    func fetchStepData(from startDate: Date, to endDate: Date, completion: @escaping ([StepsEntry]) -> Void) {
        // Check if HealthKit is available and we have permission
        guard HKHealthStore.isHealthDataAvailable(),
              UserDefaults.standard.bool(forKey: "healthkit_connected") else {
            completion(generateMockStepData(from: startDate, to: endDate))
            return
        }
        
        let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: DateComponents(day: 1)
        )
        
        query.initialResultsHandler = { [weak self] query, results, error in
            guard let self = self,
                  let results = results else {
                DispatchQueue.main.async {
                    completion(self?.generateMockStepData(from: startDate, to: endDate) ?? [])
                }
                return
            }
            
            var entries: [StepsEntry] = []
            let goal = UserDefaults.standard.integer(forKey: "steps_goal") > 0 ? 
                      UserDefaults.standard.integer(forKey: "steps_goal") : 10000
            
            results.enumerateStatistics(from: startDate, to: endDate) { statistics, stop in
                let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                let entry = StepsEntry(
                    date: statistics.startDate,
                    steps: Int(steps),
                    goal: goal
                )
                entries.append(entry)
            }
            
            DispatchQueue.main.async {
                completion(entries)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func generateMockStepData(from startDate: Date, to endDate: Date) -> [StepsEntry] {
        let calendar = Calendar.current
        let goal = UserDefaults.standard.integer(forKey: "steps_goal") > 0 ? 
                  UserDefaults.standard.integer(forKey: "steps_goal") : 10000
        
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        
        return (0...days).map { day in
            let date = calendar.date(byAdding: .day, value: day, to: startDate)!
            let isWeekend = calendar.isDateInWeekend(date)
            
            // Generate realistic step counts
            let baseSteps = isWeekend ? 8000 : 10000
            let variation = Int.random(in: -2000...2000)
            let steps = max(0, baseSteps + variation)
            
            return StepsEntry(
                date: date,
                steps: steps,
                goal: goal
            )
        }
    }
    
    func fetchCalorieData(from startDate: Date, to endDate: Date, completion: @escaping ([CaloriesEntry]) -> Void) {
        guard let messenger = self.messenger else {
            // Provide mock data if messenger is not available
            let calendar = Calendar.current
            let caloriesGoal = defaults.double(forKey: "calories_goal") > 0 ? 
                defaults.double(forKey: "calories_goal") : 2500
            
            let entries = calendar.datesBetween(startDate, and: endDate).map { date -> CaloriesEntry in
                let calories = Double.random(in: 1800...2200)
                return CaloriesEntry(
                    date: date,
                    calories: calories,
                    goal: caloriesGoal,
                    consumed: calories,
                    burned: Double.random(in: 200...500)
                )
            }
            
            completion(entries)
            return
        }
        
        // Create the method channel
        let channel = FlutterMethodChannel(
            name: "com.example.macrotracker/stats",
            binaryMessenger: messenger
        )
        
        // Format dates for the channel
        let dateFormatter = ISO8601DateFormatter()
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)
        
        // Prepare arguments
        let arguments: [String: Any] = [
            "startDate": startDateString,
            "endDate": endDateString
        ]
        
        // Invoke method
        channel.invokeMethod("getCalorieData", arguments: arguments) { result in
            guard let data = result as? [[String: Any]] else {
                completion([])
                return
            }
            
            let entries = data.compactMap { dict -> CaloriesEntry? in
                guard let dateString = dict["date"] as? String,
                      let date = dateFormatter.date(from: dateString),
                      let calories = dict["calories"] as? Double,
                      let goal = dict["goal"] as? Double,
                      let burned = dict["burned"] as? Double else {
                    return nil
                }
                
                return CaloriesEntry(
                    date: date,
                    calories: calories,
                    goal: goal,
                    burned: burned
                )
            }
            
            completion(entries.sorted { $0.date < $1.date })
        }
    }
    
    // Keep the old method for backward compatibility
    func fetchCalorieData(completion: @escaping ([CaloriesEntry]) -> Void) {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        fetchCalorieData(from: startDate, to: endDate, completion: completion)
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
    
    func requestHealthKitPermissions(completion: @escaping (Bool) -> Void) {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }
        
        // Define the types we want to read
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!
        ]
        
        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("HealthKit authorization error: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                if success {
                    // Save that we've successfully connected to HealthKit
                    UserDefaults.standard.set(true, forKey: "healthkit_connected")
                }
                
                completion(success)
            }
        }
    }
}

// Data structure for persisting weight entries
struct WeightEntryData: Codable {
    let timestamp: TimeInterval
    let weight: Double
    let unit: String
}

// Add Calendar extension for date range
extension Calendar {
    func datesBetween(_ from: Date, and to: Date) -> [Date] {
        var dates: [Date] = []
        var date = from
        
        while date <= to {
            dates.append(date)
            guard let newDate = self.date(byAdding: .day, value: 1, to: date) else { break }
            date = newDate
        }
        
        return dates
    }
}