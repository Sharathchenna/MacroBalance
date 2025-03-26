//
//  ChartFactory.swift
//  Runner
//
//  Created by Sharath Chenna on 3/21/25.
//

import Foundation
import SwiftUI
import UIKit
import Charts

class ChartFactory {
    func createChart(type: String, data: [Any], parent: UIViewController) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        var hostingController: UIHostingController<AnyView>
        
        switch type {
        case "weight":
            let weightData = data.compactMap { entry -> Models.WeightEntry? in
                guard let dict = entry as? [String: Any],
                      let weightValue = dict["weight"] as? Double,
                      let dateString = dict["date"] as? String,
                      let date = ISO8601DateFormatter().date(from: dateString)
                else { return nil }
                return Models.WeightEntry(date: date, weight: weightValue)
            }
            
            // Get goal weight from UserDefaults or calculate a default goal
            let goalWeight = UserDefaults.standard.double(forKey: "goal_weight")
            let effectiveGoal: Double
            if (goalWeight > 0) {
                effectiveGoal = goalWeight
            } else if let lastWeight = weightData.last?.weight {
                // Default goal is 10% less than current weight
                effectiveGoal = lastWeight * 0.9
                UserDefaults.standard.set(effectiveGoal, forKey: "goal_weight")
            } else {
                effectiveGoal = 0 // No goal if no weight data available
            }
            
            let chartView = WeightChartView(entries: weightData, goalWeight: effectiveGoal)
                .environment(\.colorScheme, parent.traitCollection.userInterfaceStyle == .dark ? .dark : .light)
                .frame(height: 300)
            hostingController = UIHostingController(rootView: AnyView(chartView))
            
        case "steps":
            let stepsData = data.compactMap { entry -> Models.StepsEntry? in
                guard let dict = entry as? [String: Any],
                      let steps = dict["steps"] as? Int,
                      let goal = dict["goal"] as? Int,
                      let dateString = dict["date"] as? String,
                      let date = ISO8601DateFormatter().date(from: dateString)
                else { return nil }
                return Models.StepsEntry(date: date, steps: steps, goal: goal)
            }
            let chartView = StepsChartView(entries: stepsData)
                .environment(\.colorScheme, parent.traitCollection.userInterfaceStyle == .dark ? .dark : .light)
                .frame(height: 300)
            hostingController = UIHostingController(rootView: AnyView(chartView))
            
        case "calories":
             // Parse both CaloriesEntry and MacrosEntry data
            let dateFormatter = ISO8601DateFormatter()
            var caloriesData: [Models.CaloriesEntry] = []
            var macrosDataForCalories: [Models.MacrosEntry] = [] // Need macro data too

            for item in data {
                guard let dict = item as? [String: Any],
                      let dateString = dict["date"] as? String,
                      let date = dateFormatter.date(from: dateString) else { continue }

                // Parse CaloriesEntry specific fields
                if let calories = dict["calories"] as? Double,
                   let goal = dict["goal"] as? Double {
                    let burned = dict["burned"] as? Double ?? 0 // Assuming burned might be present
                    caloriesData.append(Models.CaloriesEntry(date: date, calories: calories, goal: goal, burned: burned))
                }
                
                // Parse MacrosEntry specific fields (needed for breakdown)
                // Use keys consistent with StatsDataManager fetchMacroData
                if let proteins = dict["protein"] as? Double, // Corrected key
                   let carbs = dict["carbs"] as? Double,
                   let fats = dict["fat"] as? Double, // Corrected key
                   let proteinGoal = dict["proteinGoal"] as? Double,
                   let carbGoal = dict["carbGoal"] as? Double,
                   let fatGoal = dict["fatGoal"] as? Double {
                    
                    let water = dict["water"] as? Double ?? 0
                    let waterGoal = dict["waterGoal"] as? Double ?? 2500
                    let fiber = dict["fiber"] as? Double ?? 0
                    // Assuming meals are not passed here for simplicity
                    
                    macrosDataForCalories.append(Models.MacrosEntry(
                        id: UUID(), date: date, proteins: proteins, carbs: carbs, fats: fats,
                        proteinGoal: proteinGoal, carbGoal: carbGoal, fatGoal: fatGoal,
                        micronutrients: [], water: water, waterGoal: waterGoal, meals: nil, fiber: fiber
                    ))
                }
            }
            // Use the new initializer for CaloriesChartView
            let chartView = CaloriesChartView(calorieEntries: caloriesData, macroEntries: macrosDataForCalories)
                .environment(\.colorScheme, parent.traitCollection.userInterfaceStyle == .dark ? .dark : .light)
                .frame(height: 400) // Match height used in CaloriesViewController
            hostingController = UIHostingController(rootView: AnyView(chartView)) // Keep AnyView wrapper
            
        case "macros":
            let macrosData = data.compactMap { entry -> Models.MacrosEntry? in
                guard let dict = entry as? [String: Any],
                      let proteins = dict["proteins"] as? Double,
                      let carbs = dict["carbs"] as? Double,
                      let fats = dict["fats"] as? Double,
                      let proteinGoal = dict["proteinGoal"] as? Double,
                      let carbGoal = dict["carbGoal"] as? Double,
                      let fatGoal = dict["fatGoal"] as? Double,
                      let dateString = dict["date"] as? String,
                      let date = ISO8601DateFormatter().date(from: dateString)
                else { return nil }
                return Models.MacrosEntry(
                    id: UUID(),
                    date: date,
                    proteins: proteins,
                    carbs: carbs,
                    fats: fats,
                    proteinGoal: proteinGoal,
                    carbGoal: carbGoal,
                    fatGoal: fatGoal,
                    micronutrients: [],
                    water: 0,
                    waterGoal: 2500,
                    meals: []
                )
            }
            
            // Use our redesigned modern chart implementation
            let chartView = MacrosChartView(entries: macrosData)
                .environment(\.colorScheme, parent.traitCollection.userInterfaceStyle == .dark ? .dark : .light)
                .frame(height: 380) // Increased height for better visualization
            hostingController = UIHostingController(rootView: AnyView(chartView))
            
        default:
            hostingController = UIHostingController(rootView: AnyView(EmptyView()))
        }
        
        hostingController.view.backgroundColor = .clear
        parent.addChild(hostingController)
        container.addSubview(hostingController.view)
        hostingController.didMove(toParent: parent)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
}
