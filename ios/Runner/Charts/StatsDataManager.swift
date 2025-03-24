import Foundation
import HealthKit
import UIKit
import Flutter
import SwiftUI

// MARK: - StatsDataManager
class StatsDataManager: StatsDataProvider {
    static let shared = StatsDataManager()
    private let healthStore = HKHealthStore()
    private let defaults = UserDefaults.standard
    private let weightEntriesKey = "weightEntries"
    private var messenger: FlutterBinaryMessenger?
    
    // Add required data properties
    private var weightData: [StatsData.Weight] = []
    private var stepsData: [StatsData.Steps] = []
    private var macrosData: [StatsData.Macros] = []
    
    // Cache for user settings
    private var userCalorieGoal: Double?
    
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
    
    func fetchWeightData(completion: @escaping ([Models.WeightEntry]) -> Void) {
        // First try to get saved weight entries
        if let savedEntries = loadSavedWeightEntries() {
            let statsDataEntries = savedEntries.map { entry in
                StatsData.Weight(date: entry.date, weight: entry.weight, unit: entry.unit)
            }
            self.weightData = statsDataEntries
            completion(savedEntries)
            return
        }
        
        // Fall back to HealthKit if available
        if HKHealthStore.isHealthDataAvailable() {
            fetchWeightFromHealthKit { healthKitEntries in
                if !healthKitEntries.isEmpty {
                    let statsDataEntries = healthKitEntries.map { entry in
                        StatsData.Weight(date: entry.date, weight: entry.weight, unit: entry.unit)
                    }
                    self.weightData = statsDataEntries
                    completion(healthKitEntries)
                    return
                }
                
                // Fall back to mock data if nothing else is available
                let mockData = self.generateMockWeightData()
                let statsDataEntries = mockData.map { entry in
                    StatsData.Weight(date: entry.date, weight: entry.weight, unit: entry.unit)
                }
                self.weightData = statsDataEntries
                completion(mockData)
            }
            return
        }
        
        // If HealthKit is not available, use mock data
        let mockData = generateMockWeightData()
        let statsDataEntries = mockData.map { entry in
            StatsData.Weight(date: entry.date, weight: entry.weight, unit: entry.unit)
        }
        self.weightData = statsDataEntries
        completion(mockData)
    }
    
    private func fetchWeightFromHealthKit(completion: @escaping ([Models.WeightEntry]) -> Void) {
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
                return Models.WeightEntry(
                    date: sample.endDate,
                    weight: weight,
                    unit: weightUnit
                )
            }
            
            completion(entries)
        }
        
        healthStore.execute(query)
    }
    
    private func loadSavedWeightEntries() -> [Models.WeightEntry]? {
        guard let data = defaults.data(forKey: weightEntriesKey) else { return nil }
        
        do {
            let entriesData = try JSONDecoder().decode([WeightEntryData].self, from: data)
            return entriesData.map { entryData in
                Models.WeightEntry(
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
    
    private func generateMockWeightData() -> [Models.WeightEntry] {
        let calendar = Calendar.current
        let today = Date()
        let weightUnit = defaults.string(forKey: "weight_unit") ?? "kg"
        
        // Generate a trend with some natural variations
        let baseWeight = weightUnit == "kg" ? 70.0 : 154.0
        var currentWeight = baseWeight
        let trend = -0.2 // slight downward trend
        
        // Create 30 days of weight entries with a realistic pattern
        return (0..<30).map { days -> Models.WeightEntry in
            let date = calendar.date(byAdding: .day, value: -days, to: today)!
            
            // Apply trend and add some random variation
            let dailyVariation = Double.random(in: -0.3...0.4)
            let weekendEffect = calendar.isDateInWeekend(date) ? 0.1 : 0.0 // slight increase on weekends
            
            if days > 0 { // Don't modify the first entry
                currentWeight += trend + dailyVariation + weekendEffect
            }
            
            return Models.WeightEntry(date: date, weight: currentWeight, unit: weightUnit)
        }.reversed() // Return in chronological order
    }
    
    func fetchStepData(completion: @escaping ([Models.StepsEntry]) -> Void) {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        fetchStepData(from: startDate, to: endDate, completion: completion)
    }
    
    func fetchStepData(from startDate: Date, to endDate: Date, completion: @escaping ([Models.StepsEntry]) -> Void) {
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
            
            var entries: [Models.StepsEntry] = []
            let goal = UserDefaults.standard.integer(forKey: "steps_goal") > 0 ? 
                      UserDefaults.standard.integer(forKey: "steps_goal") : 10000
            
            results.enumerateStatistics(from: startDate, to: endDate) { statistics, stop in
                let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                let statsDataEntry = StatsData.Steps(
                    date: statistics.startDate,
                    count: Int(steps),
                    goal: goal
                )
                self.stepsData.append(statsDataEntry)
                let entry = Models.StepsEntry(
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
    
    private func generateMockStepData(from startDate: Date, to endDate: Date) -> [Models.StepsEntry] {
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
            
            return Models.StepsEntry(
                date: date,
                steps: steps,
                goal: goal
            )
        }
    }
    
    func fetchCalorieData(from startDate: Date, to endDate: Date, completion: @escaping ([Models.CaloriesEntry]) -> Void) {
        guard let messenger = self.messenger else {
            // Provide mock data if messenger is not available
            let calendar = Calendar.current
            let caloriesGoal = defaults.double(forKey: "calories_goal") > 0 ? 
                defaults.double(forKey: "calories_goal") : 2500
            
            let entries = calendar.datesBetween(startDate, and: endDate).map { date -> Models.CaloriesEntry in
                let calories = Double.random(in: 1800...2200)
                return Models.CaloriesEntry(
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
            
            let entries = data.compactMap { dict -> Models.CaloriesEntry? in
                guard let dateString = dict["date"] as? String,
                      let date = dateFormatter.date(from: dateString),
                      let calories = dict["calories"] as? Double,
                      let goal = dict["goal"] as? Double,
                      let burned = dict["burned"] as? Double else {
                    return nil
                }
                
                return Models.CaloriesEntry(
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
    func fetchCalorieData(completion: @escaping ([Models.CaloriesEntry]) -> Void) {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        fetchCalorieData(from: startDate, to: endDate, completion: completion)
    }
    
    func fetchMacroData(completion: @escaping ([Models.MacrosEntry]) -> Void) {
        let calendar = Calendar.current
        let today = Date()
        
        // Get macro goals from settings
        let proteinGoal = defaults.double(forKey: "protein_goal") > 0 ? 
            defaults.double(forKey: "protein_goal") : 150
        let carbGoal = defaults.double(forKey: "carbs_goal") > 0 ? 
            defaults.double(forKey: "carbs_goal") : 250
        let fatGoal = defaults.double(forKey: "fat_goal") > 0 ? 
            defaults.double(forKey: "fat_goal") : 65
        
        // Generate entries for last 30 days with realistic patterns
        var entries: [Models.MacrosEntry] = []
        
        for day in 0..<30 {
            let date = calendar.date(byAdding: .day, value: -day, to: today)!
            let isWeekend = calendar.isDateInWeekend(date)
            
            // Create variation based on weekday/weekend
            let proteinMultiplier = isWeekend ? Double.random(in: 0.8...1.0) : Double.random(in: 0.9...1.05)
            let carbMultiplier = isWeekend ? Double.random(in: 0.85...1.2) : Double.random(in: 0.9...1.1)
            let fatMultiplier = isWeekend ? Double.random(in: 0.9...1.3) : Double.random(in: 0.85...1.1)
            
            // Calculate day's macros
            let proteins = proteinGoal * proteinMultiplier
            let carbs = carbGoal * carbMultiplier
            let fats = fatGoal * fatMultiplier
            
            // Create the entry
            let entry = Models.MacrosEntry(
                id: UUID(),
                date: date,
                proteins: proteins,
                carbs: carbs,
                fats: fats,
                proteinGoal: proteinGoal,
                carbGoal: carbGoal,
                fatGoal: fatGoal,
                micronutrients: [],
                water: Double.random(in: 1800...2500),
                waterGoal: 2500,
                meals: []
            )
            
            entries.append(entry)
            
            // Store in internal data
            self.macrosData.append(StatsData.Macros(
                date: date,
                protein: proteins,
                carbs: carbs,
                fat: fats,
                proteinGoal: proteinGoal,
                carbsGoal: carbGoal,
                fatGoal: fatGoal
            ))
        }
        
        completion(entries.sorted(by: { $0.date < $1.date }))
    }
    
    func saveWeightEntry(_ entry: Models.WeightEntry, completion: @escaping (Bool) -> Void) {
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
    
    private func saveWeightToHealthKit(_ entry: Models.WeightEntry, completion: @escaping (Bool) -> Void) {
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
    
    func saveCalorieEntry(_ entry: Models.CaloriesEntry, completion: @escaping (Bool) -> Void) {
        // TODO: Implement persistence
        completion(true)
    }
    
    func saveMacroEntry(_ entry: Models.MacrosEntry, completion: @escaping (Bool) -> Void) {
        // Store in internal data
        self.macrosData.append(StatsData.Macros(
            date: entry.date,
            protein: entry.proteins,
            carbs: entry.carbs,
            fat: entry.fats,
            proteinGoal: entry.proteinGoal,
            carbsGoal: entry.carbGoal,
            fatGoal: entry.fatGoal
        ))
        
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
    
    // Get user's daily calorie goal
    func getUserCalorieGoal() -> Double {
        // Return cached value if available
        if let cachedGoal = userCalorieGoal {
            return cachedGoal
        }
        
        // In a real app, this would fetch from user preferences or settings
        // For now, return a default value of 2500 calories
        let defaultGoal: Double = 2500
        
        // Cache the value
        userCalorieGoal = defaultGoal
        
        return defaultGoal
    }
    
    // Set user's daily calorie goal
    func setUserCalorieGoal(_ goal: Double, completion: @escaping (Bool) -> Void) {
        // In a real app, this would update user preferences or settings
        userCalorieGoal = goal
        
        // Simulate API success
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(true)
        }
    }
    
    func getTodaysMacros() -> MacrosDataEntry? {
        // In a real app, this would fetch from a database or API
        // For now, return sample data
        return MacrosDataEntry.sampleData()
    }
    
    func getWeeklyMacros() -> [MacrosDataEntry] {
        // Generate mock data for the past week
        var entries: [MacrosDataEntry] = []
        let calendar = Calendar.current
        
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date()) else { continue }
            
            let entry = MacrosDataEntry(
                date: date,
                proteins: Double.random(in: 120...160),
                carbs: Double.random(in: 200...280),
                fats: Double.random(in: 50...80),
                water: Double.random(in: 1800...2500),
                meals: generateRandomMeals(forDate: date)
            )
            entries.append(entry)
        }
        
        return entries
    }
    
    private func generateRandomMeals(forDate date: Date) -> [Models.Meal] {
        let calendar = Calendar.current
        var meals: [Models.Meal] = []
        
        // Breakfast
        if Bool.random() {
            var breakfastComponents = DateComponents()
            breakfastComponents.year = calendar.component(.year, from: date)
            breakfastComponents.month = calendar.component(.month, from: date)
            breakfastComponents.day = calendar.component(.day, from: date)
            breakfastComponents.hour = 8
            breakfastComponents.minute = Int.random(in: 0...30)
            
            if let breakfastTime = calendar.date(from: breakfastComponents) {
                meals.append(
                    Models.Meal(
                        name: "Breakfast",
                        time: breakfastTime,
                        proteins: Double.random(in: 20...35),
                        carbs: Double.random(in: 40...60),
                        fats: Double.random(in: 10...20),
                        foods: []
                    )
                )
            }
        }
        
        // Lunch
        if Bool.random(probability: 0.9) {
            var lunchComponents = DateComponents()
            lunchComponents.year = calendar.component(.year, from: date)
            lunchComponents.month = calendar.component(.month, from: date)
            lunchComponents.day = calendar.component(.day, from: date)
            lunchComponents.hour = 13
            lunchComponents.minute = Int.random(in: 0...59)
            
            if let lunchTime = calendar.date(from: lunchComponents) {
                meals.append(
                    Models.Meal(
                        name: "Lunch",
                        time: lunchTime,
                        proteins: Double.random(in: 30...50),
                        carbs: Double.random(in: 60...80),
                        fats: Double.random(in: 15...25),
                        foods: []
                    )
                )
            }
        }
        
        // Snack
        if Bool.random(probability: 0.6) {
            var snackComponents = DateComponents()
            snackComponents.year = calendar.component(.year, from: date)
            snackComponents.month = calendar.component(.month, from: date)
            snackComponents.day = calendar.component(.day, from: date)
            snackComponents.hour = 16
            snackComponents.minute = Int.random(in: 0...59)
            
            if let snackTime = calendar.date(from: snackComponents) {
                meals.append(
                    Models.Meal(
                        name: "Snack",
                        time: snackTime,
                        proteins: Double.random(in: 10...20),
                        carbs: Double.random(in: 20...35),
                        fats: Double.random(in: 5...15),
                        foods: []
                    )
                )
            }
        }
        
        // Dinner
        if Bool.random(probability: 0.85) || meals.isEmpty {
            var dinnerComponents = DateComponents()
            dinnerComponents.year = calendar.component(.year, from: date)
            dinnerComponents.month = calendar.component(.month, from: date)
            dinnerComponents.day = calendar.component(.day, from: date)
            dinnerComponents.hour = 19
            dinnerComponents.minute = Int.random(in: 0...59)
            
            if let dinnerTime = calendar.date(from: dinnerComponents) {
                meals.append(
                    Models.Meal(
                        name: "Dinner",
                        time: dinnerTime,
                        proteins: Double.random(in: 30...60),
                        carbs: Double.random(in: 50...90),
                        fats: Double.random(in: 15...30),
                        foods: []
                    )
                )
            }
        }
        
        return meals
    }
    
    // Convert StatsData.Weight to Models.WeightEntry
    private func convertToWeightEntry(_ weight: StatsData.Weight) -> Models.WeightEntry {
        return Models.WeightEntry(date: weight.date, weight: weight.weight, unit: weight.unit)
    }
    
    // Convert StatsData.Steps to Models.StepsEntry
    private func convertToStepsEntry(_ steps: StatsData.Steps) -> Models.StepsEntry {
        return Models.StepsEntry(date: steps.date, steps: steps.count, goal: steps.goal)
    }
    
    // Convert StatsData.Macros to Models.MacrosEntry
    private func convertToMacrosEntry(_ macros: StatsData.Macros) -> Models.MacrosEntry {
        return Models.MacrosEntry(
            id: UUID(),
            date: macros.date,
            proteins: macros.protein,
            carbs: macros.carbs,
            fats: macros.fat,
            proteinGoal: macros.proteinGoal,
            carbGoal: macros.carbsGoal,
            fatGoal: macros.fatGoal,
            micronutrients: [],
            water: 0,
            waterGoal: 2000,
            meals: []
        )
    }
    
    // StatsDataProvider protocol conformance
    func getWeightData() -> [Models.WeightEntry] {
        return weightData.map(convertToWeightEntry)
    }
    
    func getStepsData() -> [Models.StepsEntry] {
        return stepsData.map(convertToStepsEntry)
    }
    
    func getMacrosData() -> [Models.MacrosEntry] {
        return macrosData.map(convertToMacrosEntry)
    }
    
    func fetchMacrosData(completion: @escaping ([Models.MacrosEntry]) -> Void) {
        // For now, return mock data
        let calendar = Calendar.current
        let today = Date()
        
        var entries: [Models.MacrosEntry] = []
        
        // Generate last 7 days of data
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            let entry = Models.MacrosEntry(
                id: UUID(),
                date: date,
                proteins: Double.random(in: 120...180),
                carbs: Double.random(in: 180...250),
                fats: Double.random(in: 50...80),
                proteinGoal: 150,
                carbGoal: 200,
                fatGoal: 65,
                micronutrients: [],
                water: Double.random(in: 1500...2500),
                waterGoal: 2500,
                meals: generateMockMeals(for: date)
            )
            
            entries.append(entry)
        }
        
        completion(entries.reversed())
    }
    
    private func generateMockMeals(for date: Date) -> [Models.Meal] {
        let calendar = Calendar.current
        var meals: [Models.Meal] = []
        
        // Breakfast (8 AM)
        if let breakfastTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date) {
            meals.append(Models.Meal(
                name: "Breakfast",
                time: breakfastTime,
                proteins: Double.random(in: 20...30),
                carbs: Double.random(in: 40...60),
                fats: Double.random(in: 10...20)
            ))
        }
        
        // Lunch (1 PM)
        if let lunchTime = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: date) {
            meals.append(Models.Meal(
                name: "Lunch",
                time: lunchTime,
                proteins: Double.random(in: 40...50),
                carbs: Double.random(in: 60...80),
                fats: Double.random(in: 15...25)
            ))
        }
        
        // Dinner (7 PM)
        if let dinnerTime = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: date) {
            meals.append(Models.Meal(
                name: "Dinner",
                time: dinnerTime,
                proteins: Double.random(in: 35...45),
                carbs: Double.random(in: 50...70),
                fats: Double.random(in: 15...25)
            ))
        }
        
        return meals
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

// Helper extension for random boolean with probability
extension Bool {
    static func random(probability: Double = 0.5) -> Bool {
        return Double.random(in: 0...1) < probability
    }
}

// MARK: - Custom Models for StatsDataManager
struct MacrosDataEntry: Identifiable {
    let id = UUID()
    var date: Date
    var proteins: Double
    var carbs: Double
    var fats: Double
    var water: Double
    var meals: [Models.Meal]
    
    // Goals
    var proteinGoal: Double = 150
    var carbGoal: Double = 250
    var fatGoal: Double = 65
    var waterGoal: Double = 2500
    var calorieGoal: Double = 2200
    
    // Calculated properties
    var calories: Double {
        (proteins * 4) + (carbs * 4) + (fats * 9)
    }
    
    var waterPercentage: Double {
        (water / waterGoal) * 100
    }
    
    func getGoalPercentage(for nutrient: NutrientType) -> Double {
        switch nutrient {
        case .protein:
            return (proteins / proteinGoal) * 100
        case .carbs:
            return (carbs / carbGoal) * 100
        case .fat:
            return (fats / fatGoal) * 100
        }
    }
    
    // Mock data
    static func sampleData() -> MacrosDataEntry {
        let meals = [
            Models.Meal(
                name: "Breakfast",
                time: Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date())!,
                proteins: 25,
                carbs: 45,
                fats: 15,
                foods: []
            ),
            Models.Meal(
                name: "Lunch",
                time: Calendar.current.date(bySettingHour: 13, minute: 15, second: 0, of: Date())!,
                proteins: 40,
                carbs: 65,
                fats: 20,
                foods: []
            ),
            Models.Meal(
                name: "Dinner",
                time: Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date())!,
                proteins: 45,
                carbs: 70,
                fats: 25,
                foods: []
            )
        ]
        
        return MacrosDataEntry(
            date: Date(),
            proteins: 110,
            carbs: 180,
            fats: 60,
            water: 1850,
            meals: meals
        )
    }
}

// MARK: - StatsData Models
// Removed duplicate StatsData enum declaration as it's already defined in StatsModels.swift