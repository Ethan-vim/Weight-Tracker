import SwiftUI
import SwiftData
import Charts

struct WeightGraphView: View {
    let weights: [WeightItem]
    @Binding var selectedEntry: WeightItem?

    private var yDomain: ClosedRange<Double> {
        guard !weights.isEmpty else { return 0...200 }
        let values = weights.map { Double($0.weight) }
        let minWeight = values.min() ?? 0
        let maxWeight = values.max() ?? 0
        let padding = max((maxWeight - minWeight) * 0.1, 5)
        return (minWeight - padding)...(maxWeight + padding)
    }

    var body: some View {
        Group {
            if weights.isEmpty {
                ContentUnavailableView(
                    "No Entries Yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Save a weight to see your graph.")
                )
            } else {
                chart
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            // Decorative only, so it must not swallow taps meant for the chart.
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.separator), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .padding(.horizontal)
    }

    private var chart: some View {
        Chart(weights) { item in
            LineMark(
                x: .value("Date", item.date),
                y: .value("Weight", item.weight)
            )
            .interpolationMethod(.linear)
            .foregroundStyle(Color.accentColor.opacity(0.8))

            PointMark(
                x: .value("Date", item.date),
                y: .value("Weight", item.weight)
            )
            .symbolSize(isSelected(item) ? 140 : 70)
            .foregroundStyle(isSelected(item) ? Color.accentColor : Color.blue)
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let weight = value.as(Double.self) {
                        Text(weight, format: .number.precision(.fractionLength(0)))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                selectNearestEntry(to: value.location, proxy: proxy, geometry: geometry)
                            }
                    )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedEntry?.persistentModelID)
        .padding()
    }

    private func isSelected(_ item: WeightItem) -> Bool {
        selectedEntry?.persistentModelID == item.persistentModelID
    }

    private func selectNearestEntry(to location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }

        let plotOrigin = geometry[plotFrame].origin
        let tapPoint = CGPoint(x: location.x - plotOrigin.x, y: location.y - plotOrigin.y)

        var nearestEntry: WeightItem?
        var nearestDistance = CGFloat.infinity

        for item in weights {
            guard
                let x = proxy.position(forX: item.date),
                let y = proxy.position(forY: item.weight)
            else { continue }

            let distance = hypot(x - tapPoint.x, y - tapPoint.y)
            if distance < nearestDistance {
                nearestDistance = distance
                nearestEntry = item
            }
        }

        // Ignore taps that land far from any dot so empty areas don't change selection.
        guard nearestDistance <= 44, let nearestEntry else { return }
        selectedEntry = nearestEntry
    }
}

#Preview {
    WeightGraphView(weights: [], selectedEntry: .constant(nil))
}
