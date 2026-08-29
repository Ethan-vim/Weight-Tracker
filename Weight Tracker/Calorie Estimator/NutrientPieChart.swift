import SwiftUI
import Charts

struct NutrientPieChart: View {
    let info: NutritionInfo

    private struct Nutrient: Identifiable {
        let name: String
        let dailyValuePercent: Double
        /// Fraction of the summed daily values, so the slice angles stay proportional.
        let share: Double

        var id: String { name }
        var label: String { "\(name) \(dailyValuePercent.formatted(.number.precision(.fractionLength(0))))%" }
    }

    private var nutrients: [Nutrient] {
        let values = [
            ("Protein", info.proteinPercent),
            ("Carbs", info.carbsPercent),
            ("Fat", info.fatPercent),
            ("Fiber", info.fiberPercent)
        ]

        // Daily values are independent percentages that do not add up to 100, so slices are sized
        // by each nutrient's share of the total rather than by the raw percentage.
        let total = values.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return [] }

        return values.map { name, percent in
            Nutrient(name: name, dailyValuePercent: percent, share: percent / total)
        }
    }

    var body: some View {
        if nutrients.isEmpty {
            Text("No nutrient breakdown")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart(nutrients) { nutrient in
            SectorMark(
                angle: .value("Share", nutrient.share),
                innerRadius: .ratio(0.55),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(by: .value("Nutrient", nutrient.label))
        }
        // Beside the meal photo there is not enough width for a trailing legend.
        .chartLegend(position: .bottom, spacing: 6)
        .chartBackground { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    let plot = geometry[plotFrame]
                    VStack(spacing: 0) {
                        Text(info.calories, format: .number)
                            .font(.headline)
                        Text("kcal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .position(x: plot.midX, y: plot.midY)
                }
            }
        }
    }
}

#Preview {
    NutrientPieChart(
        info: NutritionInfo(
            calories: 640,
            proteinPercent: 42,
            carbsPercent: 28,
            fatPercent: 35,
            fiberPercent: 12,
            advice: "Add a side salad."
        )
    )
    .frame(height: 180)
}
