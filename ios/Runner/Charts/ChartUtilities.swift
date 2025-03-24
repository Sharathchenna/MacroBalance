import Foundation
import DGCharts
import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
typealias UIColor = NSColor
#endif

// MARK: - Color Extensions
extension UIColor {
    static var proteinColor: UIColor {
        return UIColor(red: 0.98, green: 0.76, blue: 0.34, alpha: 1.0) // Golden Yellow
    }
    
    static var carbColor: UIColor {
        return UIColor(red: 0.35, green: 0.78, blue: 0.71, alpha: 1.0) // Teal
    }
    
    static var fatColor: UIColor {
        return UIColor(red: 0.56, green: 0.27, blue: 0.68, alpha: 1.0) // Purple
    }
    
    static var calorieColor: UIColor {
        return UIColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 1.0) // Bright Blue
    }
    
    static var waterColor: UIColor {
        return UIColor(red: 0.0, green: 0.48, blue: 0.8, alpha: 1.0) // Blue
    }
}

extension Color {
    static var proteinColor: Color {
        Color(UIColor.proteinColor)
    }
    
    static var carbColor: Color {
        Color(UIColor.carbColor)
    }
    
    static var fatColor: Color {
        Color(UIColor.fatColor)
    }
    
    static var calorieColor: Color {
        Color(UIColor.calorieColor)
    }
    
    static var waterColor: Color {
        Color(UIColor.waterColor)
    }
}

// MARK: - UIColor Extensions
extension UIColor {
    func adjustBrightness(by amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if self.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return UIColor(hue: h, saturation: s, brightness: b + amount, alpha: a)
        }
        return self
    }
}

// MARK: - Value Formatters
class MacroPercentValueFormatter: NSObject, ValueFormatter {
    func stringForValue(_ value: Double,
                       entry: ChartDataEntry,
                       dataSetIndex: Int,
                       viewPortHandler: ViewPortHandler?) -> String {
        if let pieEntry = entry as? PieChartDataEntry,
           let total = (entry.data as? [String: Any])?["total"] as? Double,
           total > 0 {
            return String(format: "%.0f%%", (value / total) * 100)
        } else {
            return String(format: "%.0f%%", value)
        }
    }
}