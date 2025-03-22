import SwiftUI
import Charts

struct MacroTrendChartView: View {
    let entries: [MacrosEntry]
    @State private var selectedMetric = 0
    
    // Animation state
    @State private var animateChart = false
    
    // Color constants
    private let proteinColor = Color(red: 0.98, green: 0.76, blue: 0.34) // Golden yellow
    private let carbsColor = Color(red: 0.35, green: 0.78, blue: 0.71) // Teal green
    private let fatColor = Color(red: 0.56, green: 0.27, blue: 0.68) // Purple
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Segmented control for selecting metric
            Picker("Metric", selection: $selectedMetric) {
                Text("% of Total").tag(0)
                Text("Grams").tag(1)
                Text("vs. Goal").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)
            
            // Chart visualization
            chartView
                .frame(height: 200)
                .padding(.top, 8)
            
            // Legend
            HStack(spacing: 20) {
                legendItem(color: proteinColor, label: "Protein")
                legendItem(color: carbsColor, label: "Carbs")
                legendItem(color: fatColor, label: "Fat")
            }
            .padding(.horizontal, 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animateChart = true
            }
        }
    }
    
    private var chartView: some View {
        Group {
            if #available(iOS 16.0, *) {
                modernChart
            } else {
                legacyChart
            }
        }
    }
    
    @available(iOS 16.0, *)
    private var modernChart: some View {
        Chart {
            ForEach(entries.indices, id: \.self) { index in
                let entry = entries[index]
                let dateString = formatDate(entry.date)
                
                // Protein
                LineMark(
                    x: .value("Date", dateString),
                    y: .value("Value", yValue(for: entry, nutrient: .protein))
                )
                .foregroundStyle(proteinColor)
                .symbol(Circle().strokeBorder(lineWidth: 1.5))
                .symbolSize(30)
                .opacity(animateChart ? 1.0 : 0.0)
                .interpolationMethod(.catmullRom)
                
                // Carbs
                LineMark(
                    x: .value("Date", dateString),
                    y: .value("Value", yValue(for: entry, nutrient: .carbs))
                )
                .foregroundStyle(carbsColor)
                .symbol(Circle().strokeBorder(lineWidth: 1.5))
                .symbolSize(30)
                .opacity(animateChart ? 1.0 : 0.0)
                .interpolationMethod(.catmullRom)
                
                // Fat
                LineMark(
                    x: .value("Date", dateString),
                    y: .value("Value", yValue(for: entry, nutrient: .fat))
                )
                .foregroundStyle(fatColor)
                .symbol(Circle().strokeBorder(lineWidth: 1.5))
                .symbolSize(30)
                .opacity(animateChart ? 1.0 : 0.0)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel(centered: true) {
                    if let stringValue = value.as(String.self) {
                        Text(stringValue)
                            .font(.caption)
                            .rotationEffect(.degrees(-45))
                    }
                }
            }
        }
    }
    
    private var legacyChart: some View {
        // Fallback for iOS 15 and below
        GeometryReader { geometry in
            // Calculate chart dimensions
            let width = geometry.size.width
            let height = geometry.size.height
            let availableWidth = width - 40
            let stepX = availableWidth / CGFloat(max(1, entries.count - 1))
            
            VStack {
                ZStack(alignment: .bottomLeading) {
                    // Y axis
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1, height: height - 40)
                    
                    // X axis
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: width - 20, height: 1)
                    
                    // Protein line
                    drawLine(
                        entries: entries,
                        nutrient: .protein,
                        stepX: stepX,
                        height: height - 40,
                        color: proteinColor
                    )
                    
                    // Carbs line
                    drawLine(
                        entries: entries,
                        nutrient: .carbs,
                        stepX: stepX,
                        height: height - 40,
                        color: carbsColor
                    )
                    
                    // Fat line
                    drawLine(
                        entries: entries,
                        nutrient: .fat,
                        stepX: stepX,
                        height: height - 40,
                        color: fatColor
                    )
                    
                    // Date labels
                    HStack(spacing: 0) {
                        ForEach(entries.indices, id: \.self) { index in
                            Text(formatDateShort(entries[index].date))
                                .font(.system(size: 8))
                                .frame(width: stepX)
                                .rotationEffect(.degrees(-45))
                        }
                    }
                    .offset(y: height - 20)
                }
            }
            .padding(.leading, 20)
        }
    }
    
    @ViewBuilder
    private func drawLine(entries: [MacrosEntry], nutrient: NutrientType, stepX: CGFloat, height: CGFloat, color: Color) -> some View {
        let maxValue = getMaxValue(for: nutrient)
        
        Path { path in
            for (index, entry) in entries.enumerated() {
                let value = yValue(for: entry, nutrient: nutrient)
                let x = stepX * CGFloat(index) + 20 // Add 20 for left padding
                let y = height - (height * CGFloat(value) / CGFloat(maxValue))
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        .opacity(animateChart ? 1 : 0)
        .animation(Animation.easeInOut(duration: 1.0).delay(0.3), value: animateChart)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // Helper methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d/M"
        return formatter.string(from: date)
    }
    
    private func yValue(for entry: MacrosEntry, nutrient: NutrientType) -> Double {
        switch selectedMetric {
        case 0: // Percentage
            switch nutrient {
            case .protein:
                return entry.proteinPercentage
            case .carbs:
                return entry.carbsPercentage
            case .fat:
                return entry.fatsPercentage
            }
            
        case 1: // Grams
            switch nutrient {
            case .protein:
                return entry.proteins
            case .carbs:
                return entry.carbs
            case .fat:
                return entry.fats
            }
            
        case 2: // vs. Goal
            switch nutrient {
            case .protein:
                return min(entry.proteins / entry.proteinGoal, 1.0) * 100
            case .carbs:
                return min(entry.carbs / entry.carbGoal, 1.0) * 100
            case .fat:
                return min(entry.fats / entry.fatGoal, 1.0) * 100
            }
            
        default:
            return 0
        }
    }
    
    private func getMaxValue(for nutrient: NutrientType) -> Double {
        var maxValue = 0.0
        
        for entry in entries {
            let value = yValue(for: entry, nutrient: nutrient)
            maxValue = max(maxValue, value)
        }
        
        // Add 10% padding to max value
        return maxValue * 1.1
    }
    
    enum NutrientType {
        case protein, carbs, fat
    }
}

// MARK: - Preview
struct MacroTrendChartView_Previews: PreviewProvider {
    static var previews: some View {
        MacroTrendChartView(entries: [
            MacrosEntry(date: Date().addingTimeInterval(-6 * 86400), proteins: 120, carbs: 230, fats: 60),
            MacrosEntry(date: Date().addingTimeInterval(-5 * 86400), proteins: 130, carbs: 210, fats: 65),
            MacrosEntry(date: Date().addingTimeInterval(-4 * 86400), proteins: 140, carbs: 240, fats: 55),
            MacrosEntry(date: Date().addingTimeInterval(-3 * 86400), proteins: 135, carbs: 225, fats: 60),
            MacrosEntry(date: Date().addingTimeInterval(-2 * 86400), proteins: 145, carbs: 215, fats: 70),
            MacrosEntry(date: Date().addingTimeInterval(-1 * 86400), proteins: 150, carbs: 200, fats: 65),
            MacrosEntry(date: Date(), proteins: 140, carbs: 220, fats: 60)
        ])
        .previewLayout(.fixed(width: 375, height: 300))
        .padding()
        .background(Color(.secondarySystemBackground))
    }
}