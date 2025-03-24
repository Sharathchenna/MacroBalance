import UIKit
import SwiftUI

// MARK: - Models
struct NutrientInfo {
    let name: String
    let amount: String
    let percentage: Int

    static func defaultVitamins() -> [(String, String, Int)] {
        return [
            ("Vitamin A", "800 mcg", 65),
            ("Vitamin C", "90 mg", 75),
            ("Vitamin D", "15 mcg", 30),
            ("Vitamin E", "15 mg", 55),
            ("Vitamin K", "120 mcg", 40),
            ("Vitamin B6", "1.7 mg", 85),
            ("Vitamin B12", "2.4 mcg", 90),
            ("Folate", "400 mcg", 70)
        ]
    }

    static func defaultMinerals() -> [(String, String, Int)] {
        return [
            ("Calcium", "1000 mg", 60),
            ("Iron", "8 mg", 45),
            ("Magnesium", "420 mg", 50),
            ("Zinc", "11 mg", 65),
            ("Potassium", "3500 mg", 40),
            ("Sodium", "2300 mg", 75),
            ("Phosphorus", "700 mg", 80),
            ("Selenium", "55 mcg", 70)
        ]
    }

    static func defaultOtherNutrients() -> [(String, String, Int)] {
        return [
            ("Fiber", "38 g", 25),
            ("Omega-3", "1.6 g", 30),
            ("Omega-6", "17 g", 70),
            ("Cholesterol", "300 mg", 55),
            ("Sugar", "24 g", 60),
            ("Water", "3.7 L", 85)
        ]
    }
}

class NutrientDetailViewController: UIViewController {
    // MARK: - Properties
    private var macrosEntry: Models.MacrosEntry?
    private var selectedNutrient: NutrientType?
    private let dataManager = StatsDataManager.shared

    // UI Elements
    private var hostingController: UIHostingController<NutrientDetailView>?

    // MARK: - Initialization
    init(macrosEntry: Models.MacrosEntry, nutrientType: NutrientType? = nil) {
        self.macrosEntry = macrosEntry
        self.selectedNutrient = nutrientType
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = selectedNutrient?.displayName ?? "Nutrient Details"

        guard let entry = macrosEntry else {
            showEmptyState()
            return
        }

        // Create and add the SwiftUI view
        let detailView = NutrientDetailView(entry: entry, selectedNutrient: selectedNutrient)
        hostingController = UIHostingController(rootView: detailView)

        if let hostingView = hostingController?.view {
            addChild(hostingController!)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(hostingView)

            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

            hostingController?.didMove(toParent: self)
        }
    }

    private func showEmptyState() {
        let emptyLabel = UILabel()
        emptyLabel.text = "No nutrient data available"
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

// MARK: - SwiftUI View
struct NutrientDetailView: View {
    let entry: Models.MacrosEntry
    let selectedNutrient: NutrientType?

    @State private var selectedTimeRange: TimeRange = .day
    @State private var selectedChart: ChartType = .macroBreakdown

    enum TimeRange: String, CaseIterable, Identifiable {
        case day = "Today"
        case week = "Week"
        case month = "Month"

        var id: String { self.rawValue }
    }

    enum ChartType: String, CaseIterable, Identifiable {
        case macroBreakdown = "Macros"
        case micronutrients = "Micronutrients"
        case mealDistribution = "Meals"

        var id: String { self.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Top selector row
                HStack {
                    Picker("Time", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Spacer()

                    Picker("Chart", selection: $selectedChart) {
                        ForEach(ChartType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)

                // Selected content based on chart type
                Group {
                    switch selectedChart {
                    case .macroBreakdown:
                        macroBreakdownCard
                    case .micronutrients:
                        micronutrientsCard
                    case .mealDistribution:
                        mealDistributionCard
                    }
                }
                .padding(.horizontal)

                // Nutrient-specific details
                if let nutrient = selectedNutrient {
                    nutrientDetailCard(for: nutrient)
                        .padding(.horizontal)
                }

                // Daily targets
                dailyTargetsCard
                    .padding(.horizontal)

                // Health insights
                healthInsightsCard
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - UI Components

    private var macroBreakdownCard: some View {
        VStack(spacing: 16) {
            Text("Macro Breakdown")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Pie chart visualization
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 40)
                    .frame(width: 200, height: 200)

                // Protein arc
                Circle()
                    .trim(from: 0, to: calculateSegment(for: .protein))
                    .stroke(Color.proteinColor, lineWidth: 40)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                // Carbs arc
                Circle()
                    .trim(from: calculateSegment(for: .protein),
                          to: calculateSegment(for: .protein) + calculateSegment(for: .carbs))
                    .stroke(Color.carbColor, lineWidth: 40)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                // Fat arc
                Circle()
                    .trim(from: calculateSegment(for: .protein) + calculateSegment(for: .carbs),
                          to: 1)
                    .stroke(Color.fatColor, lineWidth: 40)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))

                // Center calories
                VStack(spacing: 4) {
                    Text("\(Int(entry.calories))")
                        .font(.system(size: 24, weight: .bold))
                    Text("calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 240)
            .padding(.vertical, 8)

            // Legend
            HStack(spacing: 20) {
                legendItem(color: .proteinColor,
                           label: "Protein",
                           value: "\(Int(entry.proteins))g",
                           percentage: "\(Int(entry.proteinPercentage))%")

                legendItem(color: .carbColor,
                           label: "Carbs",
                           value: "\(Int(entry.carbs))g",
                           percentage: "\(Int(entry.carbsPercentage))%")

                legendItem(color: .fatColor,
                           label: "Fat",
                           value: "\(Int(entry.fats))g",
                           percentage: "\(Int(entry.fatsPercentage))%")
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var micronutrientsCard: some View {
        VStack(spacing: 16) {
            Text("Micronutrients")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(MicronutrientCategory.allCases) { category in
                let nutrients = entry.micronutrients(in: category)
                if !nutrients.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.bottom, 4)

                        ForEach(nutrients) { nutrient in
                            VStack(spacing: 4) {
                                HStack {
                                    Text(nutrient.name)
                                        .font(.subheadline)

                                    Spacer()

                                    Text("\(Int(nutrient.amount))\(nutrient.unit) / \(Int(nutrient.goal))\(nutrient.unit)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                // Progress bar
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(height: 8)
                                            .cornerRadius(4)

                                        Rectangle()
                                            .fill(progressColor(for: nutrient.percentOfGoal))
                                            .frame(width: geometry.size.width * CGFloat(min(nutrient.percentOfGoal / 100, 1.0)), height: 8)
                                            .cornerRadius(4)
                                    }
                                }
                                .frame(height: 8)
                            }
                            .padding(.bottom, 8)
                        }
                    }

                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var mealDistributionCard: some View {
        VStack(spacing: 16) {
            Text("Meal Distribution")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if entry.meals?.isEmpty ?? true {
                Text("No meals recorded for today")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                // Meal breakdown
                VStack(spacing: 20) {
                    ForEach(entry.meals?.sorted(by: { $0.time < $1.time }) ?? []) { meal in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(meal.name)
                                    .font(.system(size: 16, weight: .semibold))

                                Spacer()

                                Text(formatTime(meal.time))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 16) {
                                // Calories
                                VStack {
                                    Text("\(Int(meal.calories))")
                                        .font(.system(size: 20, weight: .bold))
                                    Text("cal")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 70)

                                // Macro bars
                                VStack(alignment: .leading, spacing: 4) {
                                    macroBar(
                                        value: meal.proteins,
                                        total: entry.proteins,
                                        color: .proteinColor,
                                        label: "P: \(Int(meal.proteins))g"
                                    )

                                    macroBar(
                                        value: meal.carbs,
                                        total: entry.carbs,
                                        color: .carbColor,
                                        label: "C: \(Int(meal.carbs))g"
                                    )

                                    macroBar(
                                        value: meal.fats,
                                        total: entry.fats,
                                        color: .fatColor,
                                        label: "F: \(Int(meal.fats))g"
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                    }
                }

                // Calorie distribution by meal pie chart
                HStack {
                    VStack(spacing: 8) {
                        Text("Calorie Distribution")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        ZStack {
                            if let meals = entry.meals, !meals.isEmpty {
                                ForEach(0..<meals.count, id: \.self) { index in
                                    let meal = meals[index]
                                    let startAngle = index == 0 ? 0.0 :
                                        meals[0..<index].reduce(0) { $0 + $1.calories } / entry.calories
                                    let endAngle = meals[0...index].reduce(0) { $0 + $1.calories } / entry.calories

                                    pieSegment(
                                        startAngle: startAngle,
                                        endAngle: endAngle,
                                        color: mealColor(for: index)
                                    )
                                }
                            }

                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 60, height: 60)
                        }
                        .frame(width: 120, height: 120)
                    }

                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        if let meals = entry.meals, !meals.isEmpty {
                            ForEach(0..<meals.count, id: \.self) { index in
                                let meal = meals[index]
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(mealColor(for: index))
                                        .frame(width: 12, height: 12)

                                    Text(meal.name)
                                        .font(.caption)

                                    Spacer()

                                    Text("\(Int(meal.calories)) cal")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.leading)
                }
                .padding(.top, 16)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func nutrientDetailCard(for nutrient: NutrientType) -> some View {
        VStack(spacing: 16) {
            Text("\(nutrient.displayName) Detail")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 24) {
                // Current value vs goal
                HStack(spacing: 30) {
                    VStack(spacing: 4) {
                        Text("Current")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("\(Int(entry.getValue(for: nutrient)))g")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(nutrient.defaultColor)
                    }

                    Divider()
                        .frame(height: 40)

                    VStack(spacing: 4) {
                        Text("Goal")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("\(Int(entry.getGoal(for: nutrient)))g")
                            .font(.system(size: 32, weight: .bold))
                    }

                    Divider()
                        .frame(height: 40)

                    VStack(spacing: 4) {
                        Text("Progress")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("\(Int(entry.getGoalPercentage(for: nutrient)))%")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(progressTextColor(for: entry.getGoalPercentage(for: nutrient)))
                    }
                }

                // Progress visualization
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(nutrient.defaultColor.opacity(0.2))
                            .frame(height: 16)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(
                                        colors: [
                                            nutrient.defaultColor.opacity(0.7),
                                            nutrient.defaultColor
                                        ]
                                    ),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * CGFloat(min(entry.getGoalPercentage(for: nutrient) / 100, 1.0)),
                                height: 16
                            )

                        // Goal indicator
                        if entry.getGoalPercentage(for: nutrient) < 100 {
                            Rectangle()
                                .fill(Color(.systemBackground))
                                .frame(width: 2, height: 24)
                                .position(x: geometry.size.width * CGFloat(1.0), y: 8)
                        }
                    }
                }
                .frame(height: 16)

                // Nutrition facts about this nutrient
                VStack(alignment: .leading, spacing: 10) {
                    Text("Nutrition Facts")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(nutritionFacts(for: nutrient))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var dailyTargetsCard: some View {
        VStack(spacing: 16) {
            Text("Daily Targets")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                targetRow(
                    label: "Protein",
                    current: entry.proteins,
                    goal: entry.proteinGoal,
                    color: .proteinColor,
                    unit: "g"
                )

                targetRow(
                    label: "Carbs",
                    current: entry.carbs,
                    goal: entry.carbGoal,
                    color: .carbColor,
                    unit: "g"
                )

                targetRow(
                    label: "Fat",
                    current: entry.fats,
                    goal: entry.fatGoal,
                    color: .fatColor,
                    unit: "g"
                )

                targetRow(
                    label: "Calories",
                    current: entry.calories,
                    goal: entry.calorieGoal,
                    color: .blue,
                    unit: "cal"
                )

                targetRow(
                    label: "Water",
                    current: entry.water,
                    goal: entry.waterGoal,
                    color: .cyan,
                    unit: "ml"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var healthInsightsCard: some View {
        VStack(spacing: 16) {
            Text("Health Insights")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                insightItem(
                    title: "Protein Intake",
                    description: "Your protein intake is \(proteinInsight())",
                    image: "heart.fill",
                    color: .proteinColor
                )

                insightItem(
                    title: "Carb Distribution",
                    description: "Your carb intake is \(carbInsight())",
                    image: "bolt.fill",
                    color: .carbColor
                )

                insightItem(
                    title: "Fat Balance",
                    description: "Your fat intake is \(fatInsight())",
                    image: "drop.fill",
                    color: .fatColor
                )

                insightItem(
                    title: "Calorie Balance",
                    description: "You're \(calorieInsight())",
                    image: "flame.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Helper Methods

    private func calculateSegment(for nutrient: NutrientType) -> CGFloat {
        let totalCalories = entry.calories
        if totalCalories <= 0 {
            return 0
        }

        let nutrientCalories: Double
        switch nutrient {
        case .protein:
            nutrientCalories = entry.proteins * 4
        case .carbs:
            nutrientCalories = entry.carbs * 4
        case .fat:
            nutrientCalories = entry.fats * 9
        }

        return CGFloat(nutrientCalories / totalCalories)
    }

    private func legendItem(color: Color, label: String, value: String, percentage: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(percentage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func progressColor(for percentage: Double) -> Color {
        if percentage < 25 {
            return .red
        } else if percentage < 50 {
            return .orange
        } else if percentage < 75 {
            return .yellow
        } else if percentage <= 100 {
            return .green
        } else {
            return .blue
        }
    }

    private func macroBar(value: Double, total: Double, color: Color, label: String) -> some View {
        HStack {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(height: 16)
                        .cornerRadius(8)

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value / max(total, 1)), height: 16)
                        .cornerRadius(8)
                }
            }
            .frame(height: 16)

            Text(label)
                .font(.caption)
                .frame(width: 50, alignment: .trailing)
        }
    }

    private func pieSegment(startAngle: Double, endAngle: Double, color: Color) -> some View {
        let startDegrees = startAngle * 360
        let endDegrees = endAngle * 360

        return Path { path in
            path.move(to: CGPoint(x: 60, y: 60))
            path.addArc(
                center: CGPoint(x: 60, y: 60),
                radius: 60,
                startAngle: Angle(degrees: startDegrees - 90),
                endAngle: Angle(degrees: endDegrees - 90),
                clockwise: false
            )
            path.closeSubpath()
        }
        .fill(color)
    }

    private func mealColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
        return colors[index % colors.count]
    }

    private func targetRow(label: String, current: Double, goal: Double, color: Color, unit: String) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)

                Spacer()

                Text("\(Int(current))\(unit) / \(Int(goal))\(unit)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(min(current / goal, 1.0)), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }

    private func insightItem(title: String, description: String, image: String, color: Color) -> some View {
        HStack {
            Image(systemName: image)
                .foregroundColor(.white)
                .padding(10)
                .background(color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func progressTextColor(for percentage: Double) -> Color {
        if percentage < 70 {
            return .red
        } else if percentage < 90 {
            return .orange
        } else {
            return .green
        }
    }

    // MARK: - Insights

    private func proteinInsight() -> String {
        let percentage = entry.getGoalPercentage(for: .protein)
        if percentage < 70 {
            return "below your target. Consider adding more protein-rich foods."
        } else if percentage < 90 {
            return "approaching your target. Good progress!"
        } else if percentage <= 110 {
            return "right on target! Great job!"
        } else {
            return "above your target. Consider reducing protein-rich foods."
        }
    }

    private func carbInsight() -> String {
        let percentage = entry.getGoalPercentage(for: .carbs)
        if percentage < 70 {
            return "below your target. Consider adding more carb-rich foods."
        } else if percentage < 90 {
            return "approaching your target. Good progress!"
        } else if percentage <= 110 {
            return "right on target! Great job!"
        } else {
            return "above your target. Consider reducing carb-rich foods."
        }
    }

    private func fatInsight() -> String {
        let percentage = entry.getGoalPercentage(for: .fat)
        if percentage < 70 {
            return "below your target. Consider adding healthy fats."
        } else if percentage < 90 {
            return "approaching your target. Good progress!"
        } else if percentage <= 110 {
            return "right on target! Great job!"
        } else {
            return "above your target. Consider reducing fat intake."
        }
    }

    private func calorieInsight() -> String {
        let percentage = entry.calorieGoalPercentage
        if percentage < 80 {
            return "under your calorie target by \(Int(entry.calorieGoal - entry.calories)) calories."
        } else if percentage < 95 {
            return "slightly under your calorie target."
        } else if percentage <= 105 {
            return "right at your calorie target!"
        } else if percentage <= 120 {
            return "slightly over your calorie target."
        } else {
            return "over your calorie target by \(Int(entry.calories - entry.calorieGoal)) calories."
        }
    }

    private func nutritionFacts(for nutrient: NutrientType) -> String {
        switch nutrient {
        case .protein:
            return "Protein is essential for muscle building and repair. It helps with hormone production, immune function, and keeping you feeling full for longer. The recommended daily intake is typically 0.8g per kg of body weight for adults."

        case .carbs:
            return "Carbohydrates are your body's main source of energy. They fuel your brain, kidneys, heart, muscles, and central nervous system. Fiber, a type of carb, aids in digestion and helps you feel full."

        case .fat:
            return "Dietary fats are essential for energy, cell growth, hormone production, and nutrient absorption. Healthy fats include monounsaturated and polyunsaturated fats from sources like olive oil, avocados, nuts, and fish."
        }
    }
}

// MARK: - Chips Flow Layout
class ChipsFlowLayout: UIView {
    private var arrangedSubviews: [UIView] = []
    private let spacing: CGFloat = 8

    func addArrangedSubview(_ view: UIView) {
        arrangedSubviews.append(view)
        addSubview(view)
        setNeedsLayout()
    }

    var minimumInteritemSpacing: CGFloat = 8
    var minimumLineSpacing: CGFloat = 8

    override func layoutSubviews() {
        super.layoutSubviews()

        var xOffset: CGFloat = 0
        var yOffset: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in arrangedSubviews {
            view.sizeToFit()
            let viewSize = view.bounds.size

            if xOffset + viewSize.width > bounds.width {
                // Move to next row
                xOffset = 0
                yOffset += rowHeight + minimumLineSpacing
                rowHeight = 0
            }

            view.frame = CGRect(x: xOffset, y: yOffset, width: viewSize.width, height: viewSize.height)

            xOffset += viewSize.width + minimumInteritemSpacing
            rowHeight = max(rowHeight, viewSize.height)
        }

        // Update frame height if needed
        let height = yOffset + rowHeight
        if frame.size.height != height {
            frame.size.height = height
        }
    }

    override var intrinsicContentSize: CGSize {
        layoutSubviews()
        return CGSize(width: UIView.noIntrinsicMetric, height: frame.size.height)
    }
}

// MARK: - MacrosEntry Extension
extension Models.MacrosEntry {
    func getValue(for nutrient: NutrientType) -> Double {
        switch nutrient {
        case .protein: return proteins
        case .carbs: return carbs
        case .fat: return fats
        }
    }

    func getGoal(for nutrient: NutrientType) -> Double {
        switch nutrient {
        case .protein: return proteinGoal
        case .carbs: return carbGoal
        case .fat: return fatGoal
        }
    }

    func getGoalPercentage(for nutrient: NutrientType) -> Double {
        switch nutrient {
        case .protein: return proteinGoalPercentage
        case .carbs: return carbGoalPercentage
        case .fat: return fatGoalPercentage
        }
    }

    func micronutrients(in category: MicronutrientCategory) -> [Models.Micronutrient] {
        return micronutrients.filter { $0.category == category.rawValue }
    }
}
