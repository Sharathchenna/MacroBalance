import Foundation
import DGCharts
import SwiftUI

#if canImport(UIKit)
import UIKit
#else
import AppKit
typealias UIColor = NSColor
#endif

// MARK: - Theme Manager
class ThemeManager {
    static let shared = ThemeManager()
    
    // Whether the app is in dark mode
    var isDarkMode: Bool {
        if #available(iOS 13.0, *) {
            return UITraitCollection.current.userInterfaceStyle == .dark
        }
        return false
    }
    
    // MARK: - Theme Colors
    
    // Light Theme Colors
    private let lightScaffoldBackground = UIColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1.0) // #F8F7F3
    private let lightCardBackground = UIColor.white
    private let lightDateNavigatorBackground = UIColor(red: 0.94, green: 0.91, blue: 0.87, alpha: 1.0) // #F0E9DF
    private let lightTextPrimary = UIColor.black
    private let lightTextSecondary = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0) // #666666
    private let lightAccentPrimary = UIColor(red: 0.3, green: 0.69, blue: 0.31, alpha: 1.0) // #4CAF50
    
    // Dark Theme Colors
    private let darkScaffoldBackground = UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1.0) // #121212
    private let darkCardBackground = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0) // #1E1E1E
    private let darkDateNavigatorBackground = UIColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1.0) // #2C2C2C
    private let darkTextPrimary = UIColor.white
    private let darkTextSecondary = UIColor(red: 0.67, green: 0.67, blue: 0.67, alpha: 1.0) // #AAAAAA
    private let darkAccentPrimary = UIColor(red: 0.5, green: 0.78, blue: 0.52, alpha: 1.0) // #81C784
    
    // MARK: - Public Color Accessors
    
    var scaffoldBackground: UIColor {
        return isDarkMode ? darkScaffoldBackground : lightScaffoldBackground
    }
    
    var cardBackground: UIColor {
        return isDarkMode ? darkCardBackground : lightCardBackground
    }
    
    var dateNavigatorBackground: UIColor {
        return isDarkMode ? darkDateNavigatorBackground : lightDateNavigatorBackground
    }
    
    var textPrimary: UIColor {
        return isDarkMode ? darkTextPrimary : lightTextPrimary
    }
    
    var textSecondary: UIColor {
        return isDarkMode ? darkTextSecondary : lightTextSecondary
    }
    
    var accentPrimary: UIColor {
        return isDarkMode ? darkAccentPrimary : lightAccentPrimary
    }
    
    // MARK: - Font Styles
    
    func fontH1() -> UIFont {
        return UIFont(name: "Inter-Bold", size: 24) ?? UIFont.systemFont(ofSize: 24, weight: .bold)
    }
    
    func fontH2() -> UIFont {
        return UIFont(name: "Inter-SemiBold", size: 20) ?? UIFont.systemFont(ofSize: 20, weight: .semibold)
    }
    
    func fontH3() -> UIFont {
        return UIFont(name: "Inter-SemiBold", size: 18) ?? UIFont.systemFont(ofSize: 18, weight: .semibold)
    }
    
    func fontBody1() -> UIFont {
        return UIFont(name: "Inter-Regular", size: 16) ?? UIFont.systemFont(ofSize: 16, weight: .regular)
    }
    
    func fontBody2() -> UIFont {
        return UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .regular)
    }
    
    func fontCaption() -> UIFont {
        return UIFont(name: "Inter-Medium", size: 13) ?? UIFont.systemFont(ofSize: 13, weight: .medium)
    }
    
    // MARK: - Chart Theme
    
    func applyChartTheme(to chart: BarLineChartViewBase) {
        chart.backgroundColor = cardBackground
        
        // X-Axis
        chart.xAxis.labelTextColor = textSecondary
        chart.xAxis.axisLineColor = textSecondary.withAlphaComponent(0.3)
        chart.xAxis.gridColor = textSecondary.withAlphaComponent(0.1)
        
        // Left Y-Axis
        chart.leftAxis.labelTextColor = textSecondary
        chart.leftAxis.axisLineColor = textSecondary.withAlphaComponent(0.3)
        chart.leftAxis.gridColor = textSecondary.withAlphaComponent(0.1)
        
        // Right Y-Axis
        chart.rightAxis.labelTextColor = textSecondary
        chart.rightAxis.axisLineColor = textSecondary.withAlphaComponent(0.3)
        chart.rightAxis.gridColor = textSecondary.withAlphaComponent(0.1)
        
        // Legend
        chart.legend.textColor = textPrimary
        chart.legend.font = fontCaption()
    }
    
    func applyChartTheme(to chart: DGCharts.PieChartView) {
        chart.backgroundColor = cardBackground
        
        // Legend
        chart.legend.textColor = textPrimary
        chart.legend.font = fontCaption()
    }
    
    // MARK: - UI Element Styling
    
    func styleCardView(_ view: UIView) {
        view.backgroundColor = cardBackground
        view.layer.cornerRadius = 20
        view.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 6)
        view.layer.shadowRadius = 16
        view.layer.shadowOpacity = 1
    }
    
    func styleButton(_ button: UIButton, isPrimary: Bool = true) {
        button.backgroundColor = isPrimary ? accentPrimary : cardBackground
        button.setTitleColor(isPrimary ? UIColor.white : textPrimary, for: .normal)
        button.titleLabel?.font = fontBody2()
        button.layer.cornerRadius = 12
    }
    
    func styleLabel(_ label: UILabel, type: LabelType) {
        switch type {
        case .h1:
            label.font = fontH1()
            label.textColor = textPrimary
        case .h2:
            label.font = fontH2()
            label.textColor = textPrimary
        case .h3:
            label.font = fontH3()
            label.textColor = textPrimary
        case .body1:
            label.font = fontBody1()
            label.textColor = textPrimary
        case .body2:
            label.font = fontBody2()
            label.textColor = textPrimary
        case .caption:
            label.font = fontCaption()
            label.textColor = textSecondary
        }
    }
    
    enum LabelType {
        case h1, h2, h3, body1, body2, caption
    }
}

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