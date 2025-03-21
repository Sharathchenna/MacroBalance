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
    // Create weight chart
    func createWeightChart(data: [[String: Any]], parent: UIViewController?) -> UIView {
        print("[ChartFactory] Creating weight chart with \(data.count) entries")
        
        // Convert data to strongly typed model
        let weightEntries = data.compactMap { entry -> WeightEntry? in
            guard let weight = entry["weight"] as? Double,
                  let dateString = entry["date"] as? String else {
                print("[ChartFactory] Failed to parse weight entry - missing fields: \(entry)")
                return nil
            }
            
            // Try different date formats for parsing the date
            let date = parseDate(dateString)
            guard let validDate = date else {
                print("[ChartFactory] Failed to parse date for weight entry: \(dateString)")
                return nil
            }
            
            return WeightEntry(date: validDate, weight: weight)
        }
        
        print("[ChartFactory] Parsed \(weightEntries.count) weight entries")
        
        // Sort entries by date
        let sortedEntries = weightEntries.sorted { $0.date < $1.date }
        
        // Create SwiftUI chart view
        let chartView = WeightChartView(entries: sortedEntries)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        
        // Wrap with hosting controller
        let hostingController = UIHostingController(rootView: AnyView(chartView))
        
        print("[ChartFactory] Created hosting controller for weight chart")
        
        // Configure the hosting controller view
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add as child view controller if parent is available
        if let parent = parent {
            print("[ChartFactory] Adding weight chart to parent view controller")
            parent.addChild(hostingController)
            hostingController.didMove(toParent: parent)
        } else {
            print("[ChartFactory] No parent view controller available for weight chart")
        }
        
        return hostingController.view
    }
    
    // Create steps chart
    func createStepsChart(data: [[String: Any]], parent: UIViewController?) -> UIView {
        print("[ChartFactory] Creating steps chart with \(data.count) entries")
        
        // Convert data to strongly typed model
        let stepsEntries = data.compactMap { entry -> StepsEntry? in
            guard let steps = entry["steps"] as? Int,
                  let goal = entry["goal"] as? Int,
                  let dateString = entry["date"] as? String else {
                print("[ChartFactory] Failed to parse steps entry - missing fields: \(entry)")
                return nil
            }
            
            // Try different date formats for parsing the date
            let date = parseDate(dateString)
            guard let validDate = date else {
                print("[ChartFactory] Failed to parse date for steps entry: \(dateString)")
                return nil
            }
            
            return StepsEntry(date: validDate, steps: steps, goal: goal)
        }
        
        print("[ChartFactory] Parsed \(stepsEntries.count) steps entries")
        
        // Sort entries by date
        let sortedEntries = stepsEntries.sorted { $0.date < $1.date }
        
        // Create SwiftUI chart view
        let chartView = StepsChartView(entries: sortedEntries)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        
        // Wrap with hosting controller
        let hostingController = UIHostingController(rootView: AnyView(chartView))
        
        print("[ChartFactory] Created hosting controller for steps chart")
        
        // Configure the hosting controller view
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add as child view controller if parent is available
        if let parent = parent {
            print("[ChartFactory] Adding steps chart to parent view controller")
            parent.addChild(hostingController)
            hostingController.didMove(toParent: parent)
        } else {
            print("[ChartFactory] No parent view controller available for steps chart")
        }
        
        return hostingController.view
    }
    
    // Create calories chart
    func createCaloriesChart(data: [[String: Any]], parent: UIViewController?) -> UIView {
        print("[ChartFactory] Creating calories chart with \(data.count) entries")
        
        // Convert data to strongly typed model
        let caloriesEntries = data.compactMap { entry -> CaloriesEntry? in
            guard let calories = entry["calories"] as? Double,
                  let goal = entry["goal"] as? Double,
                  let dateString = entry["date"] as? String else {
                print("[ChartFactory] Failed to parse calories entry - missing fields: \(entry)")
                return nil
            }
            
            // Try different date formats for parsing the date
            let date = parseDate(dateString)
            guard let validDate = date else {
                print("[ChartFactory] Failed to parse date for calories entry: \(dateString)")
                return nil
            }
            
            return CaloriesEntry(date: validDate, calories: calories, goal: goal)
        }
        
        print("[ChartFactory] Parsed \(caloriesEntries.count) calories entries")
        
        // Sort entries by date
        let sortedEntries = caloriesEntries.sorted { $0.date < $1.date }
        
        // Create SwiftUI chart view
        let chartView = CaloriesChartView(entries: sortedEntries)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        
        // Wrap with hosting controller
        let hostingController = UIHostingController(rootView: AnyView(chartView))
        
        print("[ChartFactory] Created hosting controller for calories chart")
        
        // Configure the hosting controller view
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add as child view controller if parent is available
        if let parent = parent {
            print("[ChartFactory] Adding calories chart to parent view controller")
            parent.addChild(hostingController)
            hostingController.didMove(toParent: parent)
        } else {
            print("[ChartFactory] No parent view controller available for calories chart")
        }
        
        return hostingController.view
    }
    
    // Create macros chart
    func createMacrosChart(data: [[String: Any]], parent: UIViewController?) -> UIView {
        print("[ChartFactory] Creating macros chart with \(data.count) entries")
        
        // Convert data to strongly typed model
        let macrosEntries = data.compactMap { entry -> MacrosEntry? in
            guard let proteins = entry["proteins"] as? Double,
                  let carbs = entry["carbs"] as? Double,
                  let fats = entry["fats"] as? Double,
                  let proteinGoal = entry["proteinGoal"] as? Double,
                  let carbGoal = entry["carbGoal"] as? Double,
                  let fatGoal = entry["fatGoal"] as? Double,
                  let dateString = entry["date"] as? String else {
                print("[ChartFactory] Failed to parse macros entry - missing fields: \(entry)")
                return nil
            }
            
            // Try different date formats for parsing the date
            let date = parseDate(dateString)
            guard let validDate = date else {
                print("[ChartFactory] Failed to parse date for macros entry: \(dateString)")
                return nil
            }
            
            return MacrosEntry(
                date: validDate,
                proteins: proteins,
                carbs: carbs,
                fats: fats,
                proteinGoal: proteinGoal,
                carbGoal: carbGoal,
                fatGoal: fatGoal
            )
        }
        
        print("[ChartFactory] Parsed \(macrosEntries.count) macros entries")
        
        // Sort entries by date
        let sortedEntries = macrosEntries.sorted { $0.date < $1.date }
        
        // Create SwiftUI chart view
        let chartView = MacrosChartView(entries: sortedEntries)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        
        // Wrap with hosting controller
        let hostingController = UIHostingController(rootView: AnyView(chartView))
        
        print("[ChartFactory] Created hosting controller for macros chart")
        
        // Configure the hosting controller view
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // Add as child view controller if parent is available
        if let parent = parent {
            print("[ChartFactory] Adding macros chart to parent view controller")
            parent.addChild(hostingController)
            hostingController.didMove(toParent: parent)
        } else {
            print("[ChartFactory] No parent view controller available for macros chart")
        }
        
        return hostingController.view
    }
    
    // Helper method to parse dates in multiple formats
    private func parseDate(_ dateString: String) -> Date? {
        // Try ISO8601 with milliseconds
        let iso8601Full = ISO8601DateFormatter()
        if let date = iso8601Full.date(from: dateString) {
            return date
        }
        
        // Try ISO8601 without milliseconds
        let iso8601Simple = ISO8601DateFormatter()
        iso8601Simple.formatOptions = [.withInternetDateTime]
        if let date = iso8601Simple.date(from: dateString) {
            return date
        }
        
        // Try YYYY-MM-DD format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        // Try YYYY-MM-dd'T'HH:mm:ss format
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        // Try YYYY-MM-dd'T'HH:mm:ss.SSS format
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        print("[ChartFactory] Could not parse date: \(dateString)")
        return nil
    }
}

