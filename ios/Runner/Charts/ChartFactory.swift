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
            let weightData = data.compactMap { entry -> WeightEntry? in
                guard let dict = entry as? [String: Any],
                      let weightValue = dict["weight"] as? Double,
                      let dateString = dict["date"] as? String,
                      let date = ISO8601DateFormatter().date(from: dateString)
                else { return nil }
                return WeightEntry(date: date, weight: weightValue)
            }
            let chartView = WeightChartView(entries: weightData)
                .environment(\.colorScheme, parent.traitCollection.userInterfaceStyle == .dark ? .dark : .light)
                .frame(height: 300)
            hostingController = UIHostingController(rootView: AnyView(chartView))
            
        case "steps":
            let stepsData = data.compactMap { entry -> StepsEntry? in
                guard let dict = entry as? [String: Any],
                      let steps = dict["steps"] as? Int,
                      let goal = dict["goal"] as? Int,
                      let dateString = dict["date"] as? String,
                      let date = ISO8601DateFormatter().date(from: dateString)
                else { return nil }
                return StepsEntry(date: date, steps: steps, goal: goal)
            }
            let chartView = StepsChartView(entries: stepsData)
                .environment(\.colorScheme, parent.traitCollection.userInterfaceStyle == .dark ? .dark : .light)
                .frame(height: 300)
            hostingController = UIHostingController(rootView: AnyView(chartView))
            
        case "calories":
            let caloriesData = data.compactMap { entry -> CaloriesEntry? in
                guard let dict = entry as? [String: Any],
                      let calories = dict["calories"] as? Double,
                      let goal = dict["goal"] as? Double,
                      let dateString = dict["date"] as? String,
                      let date = ISO8601DateFormatter().date(from: dateString)
                else { return nil }
                return CaloriesEntry(date: date, calories: calories, goal: goal)
            }
            let chartView = CaloriesChartView(entries: caloriesData)
                .environment(\.colorScheme, parent.traitCollection.userInterfaceStyle == .dark ? .dark : .light)
                .frame(height: 300)
            hostingController = UIHostingController(rootView: AnyView(chartView))
            
        case "macros":
            let macrosData = data.compactMap { entry -> MacrosEntry? in
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
                return MacrosEntry(
                    date: date,
                    proteins: proteins,
                    carbs: carbs,
                    fats: fats,
                    proteinGoal: proteinGoal,
                    carbGoal: carbGoal,
                    fatGoal: fatGoal
                )
            }
            let chartView = MacrosChartView(entries: macrosData)
                .environment(\.colorScheme, parent.traitCollection.userInterfaceStyle == .dark ? .dark : .light)
                .frame(height: 300)
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

