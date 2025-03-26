import SwiftUI
import UIKit // Import UIKit for UIViewRepresentable

// MARK: - UIViewRepresentable Wrappers

struct MacrosSummaryViewRepresentable: UIViewRepresentable {
    var entry: Models.MacrosEntry?

    func makeUIView(context: Context) -> MacrosSummaryView {
        return MacrosSummaryView()
    }

    func updateUIView(_ uiView: MacrosSummaryView, context: Context) {
        uiView.configure(with: entry)
    }
}

struct MacrosDistributionChartViewRepresentable: UIViewRepresentable {
    var entry: Models.MacrosEntry?

    func makeUIView(context: Context) -> MacrosDistributionChartView {
        return MacrosDistributionChartView()
    }

    func updateUIView(_ uiView: MacrosDistributionChartView, context: Context) {
        uiView.configure(with: entry)
    }
}


// MARK: - Main Macros View

struct MacrosView: View {
    @State private var entries: [Models.MacrosEntry] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Macros Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.horizontal, .bottom]) // Add bottom padding to title

                if let latestEntry = entries.last {
                    // Use a Group to potentially add more views related to the latest entry
                    Group {
                        MacrosSummaryViewRepresentable(entry: latestEntry) // Use Representable
                            // Padding applied to the Group below

                        MacrosDistributionChartViewRepresentable(entry: latestEntry) // Use Representable
                            .frame(height: 250) // Frame can be applied to Representable
                            // Padding applied to the Group below
                        
                        // Consider removing fixed height or making it more dynamic if needed
                        // MacrosChartView(entries: [latestEntry]) // Assuming this is also UIKit? Needs representable if so.
                        //     .padding(.horizontal) 
                    }
                    .padding(.horizontal) // Apply horizontal padding to the Group containing the representables
                } else {
                    Text("No macro data available for the selected period.") // More informative text
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 200) // Adjust frame
                }
                
                // Add a spacer to push content up if scroll view is not full
                Spacer() 
            }
            .padding(.vertical) // Keep vertical padding for the VStack
        }
        .onAppear {
            // You would load your data here
            loadSampleData()
        }
    }
    
    private func loadSampleData() {
        // Sample data for demonstration
        let entry = Models.MacrosEntry(
            id: UUID(),
            date: Date(),
            proteins: 120,
            carbs: 180,
            fats: 60,
            proteinGoal: 140,
            carbGoal: 220,
            fatGoal: 70,
            micronutrients: [],
            water: 1500,
            waterGoal: 2500,
            meals: []
        )
        
        self.entries = [entry]
    }
}

struct MacrosView_Previews: PreviewProvider {
    static var previews: some View {
        MacrosView()
    }
}
