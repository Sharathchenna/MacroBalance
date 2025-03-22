//
//  WeightChart.swift
//  Runner
//
//  Created by Sharath Chenna on 3/21/25.
//

import SwiftUI
import Charts

struct WeightChartView: View {
    let entries: [WeightEntry]
    @Environment(\.colorScheme) var colorScheme
    
    var chartColor: Color {
        colorScheme == .dark ? Color.blue : Color.blue.opacity(0.8)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading) {
                Chart {
                    ForEach(entries) { entry in
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(chartColor.gradient)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(chartColor.opacity(0.2).gradient)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: yAxisDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if let date = value.as(Date.self) {
                            AxisGridLine()
                            AxisValueLabel {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let weight = value.as(Double.self) {
                                Text(String(format: "%.1f", weight))
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(height: geometry.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    var yAxisDomain: ClosedRange<Double> {
        if entries.isEmpty {
            return 50.0...100.0
        }
        
        let weights = entries.map { $0.weight }
        let minWeight = weights.min() ?? 50.0
        let maxWeight = weights.max() ?? 100.0
        let buffer = (maxWeight - minWeight) * 0.1
        
        return (minWeight - buffer)...(maxWeight + buffer)
    }
}

