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
final class ThemeManager {
    // MARK: - Types
    enum LabelType {
        case h1, h2, h3, body1, body2, caption
    }
    
    private enum FontSize {
        static let h1: CGFloat = 24
        static let h2: CGFloat = 20
        static let h3: CGFloat = 18
        static let body1: CGFloat = 16
        static let body2: CGFloat = 14
        static let caption: CGFloat = 13
    }
    
    private enum Constants {
        static let cardCornerRadius: CGFloat = 20
        static let buttonCornerRadius: CGFloat = 12
        static let shadowOpacity: Float = 1.0
        static let shadowRadius: CGFloat = 16
        static let shadowYOffset: CGFloat = 6
    }
    
    // MARK: - Singleton
    static let shared = ThemeManager()
    
    // Private initialization to enforce singleton
    private init() {
        setupThemeChangeObserver()
    }
    
    deinit {
        if let observer = userInterfaceStyleObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Theme Detection
    private var _isDarkMode: Bool?
    private var userInterfaceStyleObserver: NSObjectProtocol?
    
    private func setupThemeChangeObserver() {
        if #available(iOS 13.0, *) {
            userInterfaceStyleObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?._isDarkMode = nil
            }
        }
    }
    
    var isDarkMode: Bool {
        if let cachedMode = _isDarkMode {
            return cachedMode
        }
        
        let darkMode = {
            if #available(iOS 13.0, *) {
                return UITraitCollection.current.userInterfaceStyle == .dark
            }
            return false
        }()
        
        _isDarkMode = darkMode
        return darkMode
    }
    
    // MARK: - Theme Colors
    // Light Theme Colors
    private lazy var lightScaffoldBackground = UIColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 1.0)
    private lazy var lightCardBackground = UIColor.white
    private lazy var lightDateNavigatorBackground = UIColor(red: 0.94, green: 0.91, blue: 0.87, alpha: 1.0)
    private lazy var lightTextPrimary = UIColor.black
    private lazy var lightTextSecondary = UIColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
    private lazy var lightAccentPrimary = UIColor(red: 0.3, green: 0.69, blue: 0.31, alpha: 1.0)
    
    // Dark Theme Colors
    private lazy var darkScaffoldBackground = UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1.0)
    private lazy var darkCardBackground = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)
    private lazy var darkDateNavigatorBackground = UIColor(red: 0.17, green: 0.17, blue: 0.17, alpha: 1.0)
    private lazy var darkTextPrimary = UIColor.white
    private lazy var darkTextSecondary = UIColor(red: 0.67, green: 0.67, blue: 0.67, alpha: 1.0)
    private lazy var darkAccentPrimary = UIColor(red: 0.5, green: 0.78, blue: 0.52, alpha: 1.0)
    
    // MARK: - Caching
    private var colorCache = [String: UIColor]()
    private var fontCache = [String: UIFont]()
    
    func clearCache() {
        _isDarkMode = nil
        colorCache.removeAll()
        fontCache.removeAll()
    }
    
    // MARK: - Public Color Accessors
    var scaffoldBackground: UIColor {
        return getCachedColor(key: "scaffoldBackground") {
            isDarkMode ? darkScaffoldBackground : lightScaffoldBackground
        }
    }
    
    var cardBackground: UIColor {
        return getCachedColor(key: "cardBackground") {
            isDarkMode ? darkCardBackground : lightCardBackground
        }
    }
    
    var dateNavigatorBackground: UIColor {
        return getCachedColor(key: "dateNavigatorBackground") {
            isDarkMode ? darkDateNavigatorBackground : lightDateNavigatorBackground
        }
    }
    
    var textPrimary: UIColor {
        return getCachedColor(key: "textPrimary") {
            isDarkMode ? darkTextPrimary : lightTextPrimary
        }
    }
    
    var textSecondary: UIColor {
        return getCachedColor(key: "textSecondary") {
            isDarkMode ? darkTextSecondary : lightTextSecondary
        }
    }
    
    var accentPrimary: UIColor {
        return getCachedColor(key: "accentPrimary") {
            isDarkMode ? darkAccentPrimary : lightAccentPrimary
        }
    }
    
    private func getCachedColor(key: String, provider: () -> UIColor) -> UIColor {
        let cacheKey = "\(key)_\(isDarkMode ? "dark" : "light")"
        if let cachedColor = colorCache[cacheKey] {
            return cachedColor
        }
        
        let color = provider()
        colorCache[cacheKey] = color
        return color
    }
    
    // MARK: - Font Styles
    func fontH1() -> UIFont {
        return getCachedFont(key: "h1") {
            UIFont(name: "Inter-Bold", size: FontSize.h1) ?? UIFont.systemFont(ofSize: FontSize.h1, weight: .bold)
        }
    }
    
    func fontH2() -> UIFont {
        return getCachedFont(key: "h2") {
            UIFont(name: "Inter-SemiBold", size: FontSize.h2) ?? UIFont.systemFont(ofSize: FontSize.h2, weight: .semibold)
        }
    }
    
    func fontH3() -> UIFont {
        return getCachedFont(key: "h3") {
            UIFont(name: "Inter-SemiBold", size: FontSize.h3) ?? UIFont.systemFont(ofSize: FontSize.h3, weight: .semibold)
        }
    }
    
    func fontBody1() -> UIFont {
        return getCachedFont(key: "body1") {
            UIFont(name: "Inter-Regular", size: FontSize.body1) ?? UIFont.systemFont(ofSize: FontSize.body1, weight: .regular)
        }
    }
    
    func fontBody2() -> UIFont {
        return getCachedFont(key: "body2") {
            UIFont(name: "Inter-Regular", size: FontSize.body2) ?? UIFont.systemFont(ofSize: FontSize.body2, weight: .regular)
        }
    }
    
    func fontCaption() -> UIFont {
        return getCachedFont(key: "caption") {
            UIFont(name: "Inter-Medium", size: FontSize.caption) ?? UIFont.systemFont(ofSize: FontSize.caption, weight: .medium)
        }
    }
    
    private func getCachedFont(key: String, provider: () -> UIFont) -> UIFont {
        if let cachedFont = fontCache[key] {
            return cachedFont
        }
        
        let font = provider()
        fontCache[key] = font
        return font
    }
    
    // MARK: - Chart Theme
    func applyChartTheme(to chart: BarLineChartViewBase) {
        chart.backgroundColor = cardBackground
        
        let secondaryWithAlpha = textSecondary.withAlphaComponent(0.3)
        let gridColor = textSecondary.withAlphaComponent(0.1)
        
        // Apply x-axis properties
        chart.xAxis.labelTextColor = textSecondary
        chart.xAxis.axisLineColor = secondaryWithAlpha
        chart.xAxis.gridColor = gridColor
        
        // Apply left y-axis properties
        chart.leftAxis.labelTextColor = textSecondary
        chart.leftAxis.axisLineColor = secondaryWithAlpha
        chart.leftAxis.gridColor = gridColor
        
        // Apply right y-axis properties
        chart.rightAxis.labelTextColor = textSecondary
        chart.rightAxis.axisLineColor = secondaryWithAlpha
        chart.rightAxis.gridColor = gridColor
        
        // Set legend properties
        chart.legend.textColor = textPrimary
        chart.legend.font = fontCaption()
    }
    
    // Fix for PieChartView
    func applyChartTheme(to chart: PieChartView) {
        // Only set the background color and avoid accessing any other properties
        chart.backgroundColor = cardBackground
        
        // Avoid accessing other properties that might not exist in this version of DGCharts
    }
    
    // MARK: - UI Element Styling
    func styleCardView(_ view: UIView) {
        view.backgroundColor = cardBackground
        view.layer.cornerRadius = Constants.cardCornerRadius
        
        // Only apply shadow if it doesn't already have one
        if view.layer.shadowOpacity == 0 {
            view.layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
            view.layer.shadowOffset = CGSize(width: 0, height: Constants.shadowYOffset)
            view.layer.shadowRadius = Constants.shadowRadius
            view.layer.shadowOpacity = Constants.shadowOpacity
            
            // Optimize shadow rendering
            view.layer.shouldRasterize = true
            view.layer.rasterizationScale = UIScreen.main.scale
        }
    }
    
    func styleButton(_ button: UIButton, isPrimary: Bool = true) {
        button.backgroundColor = isPrimary ? accentPrimary : cardBackground
        button.setTitleColor(isPrimary ? UIColor.white : textPrimary, for: .normal)
        button.titleLabel?.font = fontBody2()
        button.layer.cornerRadius = Constants.buttonCornerRadius
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
}

// MARK: - Color Extensions
extension UIColor {
    // Static cached colors for macros
    static let proteinColor = UIColor(red: 0.98, green: 0.76, blue: 0.34, alpha: 1.0)
    static let carbColor = UIColor(red: 0.35, green: 0.78, blue: 0.71, alpha: 1.0)
    static let fatColor = UIColor(red: 0.56, green: 0.27, blue: 0.68, alpha: 1.0)
    static let calorieColor = UIColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 1.0)
    static let waterColor = UIColor(red: 0.0, green: 0.48, blue: 0.8, alpha: 1.0)
    
    // Optimized brightness adjustment
    func adjustBrightness(by amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        
        if self.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return UIColor(hue: h, saturation: s, brightness: min(max(b + amount, 0), 1), alpha: a)
        }
        return self
    }
    
    // Utility method for creating colors with alpha
    func withAlpha(_ alpha: CGFloat) -> UIColor {
        return self.withAlphaComponent(alpha)
    }
}

// MARK: - SwiftUI Color Extensions
extension Color {
    // SwiftUI color equivalents
    static var proteinColor: Color { Color(UIColor.proteinColor) }
    static var carbColor: Color { Color(UIColor.carbColor) }
    static var fatColor: Color { Color(UIColor.fatColor) }
    static var calorieColor: Color { Color(UIColor.calorieColor) }
    static var waterColor: Color { Color(UIColor.waterColor) }
}

// MARK: - Value Formatters
final class MacroPercentValueFormatter: NSObject, ValueFormatter {
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        formatter.numberStyle = .percent
        formatter.multiplier = 1
        return formatter
    }()
    
    func stringForValue(
        _ value: Double,
        entry: ChartDataEntry,
        dataSetIndex: Int,
        viewPortHandler: ViewPortHandler?
    ) -> String {
        if let pieEntry = entry as? PieChartDataEntry,
           let total = (entry.data as? [String: Any])?["total"] as? Double,
           total > 0 {
            return numberFormatter.string(from: NSNumber(value: value / total)) ?? "\(Int((value / total) * 100))%"
        } else {
            return numberFormatter.string(from: NSNumber(value: value / 100)) ?? "\(Int(value))%"
        }
    }
}