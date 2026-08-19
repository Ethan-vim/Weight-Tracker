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
        // Proportional padding keeps the dots clear of the border at any zoom level; the small
        // floors only matter when every entry has the same weight, which has no span to scale.
        // The top pad is lighter than the bottom because the x-axis date labels already take up
        // room below the plot, which otherwise makes the headroom look bigger than the footroom.
        let span = maxWeight - minWeight
        let bottomPadding = max(span * 0.15, 0.5)
        let topPadding = max(span * 0.07, 0.25)
        return (minWeight - bottomPadding)...(maxWeight + topPadding)
    }

    private var yAxisTicks: [Double] {
        let domain = yDomain
        // Clamped to 0.1 so two adjacent ticks can never render as the same one-decimal label.
        let step = max(niceStep(for: domain.upperBound - domain.lowerBound, targetCount: 5), 0.1)
        let firstTick = (domain.lowerBound / step).rounded(.up) * step
        let ticks = firstTick <= domain.upperBound
            ? Array(stride(from: firstTick, through: domain.upperBound, by: step))
            : [domain.lowerBound]

        // Rounding a domain floor in (-step, 0) up to a tick yields IEEE negative zero, which
        // formats as "-0.0". Comparison ignores the sign of zero, so this swaps in +0.0.
        return ticks.map { $0 == 0 ? 0 : $0 }
    }

    private var xDomain: ClosedRange<Date> {
        let oneDay: TimeInterval = 60 * 60 * 24
        let dates = weights.map(\.date)
        // `weights` arrives sorted, but min/max keeps the domain correct if that ever changes.
        guard let first = dates.min(), let last = dates.max() else {
            let now = Date()
            return now.addingTimeInterval(-oneDay)...now.addingTimeInterval(oneDay)
        }
        let span = last.timeIntervalSince(first)
        // Padding stops the first/last labels from being clipped by the plot edge, and keeps the
        // end dots off the border. A zero span (one entry, or several on the same date) has no
        // proportion to work from, so it falls back to a fixed window.
        let padding: TimeInterval = span > 0 ? span * 0.08 : oneDay
        return first.addingTimeInterval(-padding)...last.addingTimeInterval(padding)
    }

    private var xAxisTicks: [Date] {
        let dates = weights.map(\.date)
        guard let first = dates.min(), let last = dates.max() else { return [] }
        let span = last.timeIntervalSince(first)
        // Every entry shares one date, so there is only one meaningful label to show.
        guard span > 0 else { return [first] }
        // First and last recordings as the endpoints, evenly spaced values in between. These are
        // deliberately not aligned to the recorded dates - even spacing is what reads best.
        let intervals = 3
        let calendar = Calendar.current
        var ticks = [first]

        for step in 1..<intervals {
            let candidate = first.addingTimeInterval(span * Double(step) / Double(intervals))
            // A span of a couple of days puts several ticks on one day; skip those so the axis
            // never prints the same label twice.
            let alreadyShown = (ticks + [last]).contains { calendar.isDate($0, inSameDayAs: candidate) }
            if !alreadyShown { ticks.append(candidate) }
        }

        if !calendar.isDate(first, inSameDayAs: last) { ticks.append(last) }
        return ticks
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
            .foregroundStyle(Color.accentColor.opacity(0.45))
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            PointMark(
                x: .value("Date", item.date),
                y: .value("Weight", item.weight)
            )
            .symbolSize(isSelected(item) ? 140 : 70)
            .foregroundStyle(isSelected(item) ? Color.accentColor : Color.blue)
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: xDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxisTicks) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let weight = value.as(Double.self) {
                        Text(weight, format: .number.precision(.fractionLength(1)))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: xAxisTicks) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(
                    format: .dateTime.month(.abbreviated).day(),
                    anchor: labelAnchor(at: value.index, of: value.count)
                )
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

    /// Rounds a raw axis step up to the nearest 1, 2, 5 or 10 within its own order of magnitude,
    /// so ticks land on readable values. The magnitude exponent goes negative for tight ranges,
    /// which is what produces 0.1 / 0.2 / 0.5 steps.
    private func niceStep(for span: Double, targetCount: Int) -> Double {
        // log10 is undefined at or below zero, so a degenerate span gets no step at all.
        guard span > 0, targetCount > 0 else { return 0 }

        let rough = span / Double(targetCount)
        let magnitude = pow(10, log10(rough).rounded(.down))
        let normalized = rough / magnitude

        let snapped: Double
        switch normalized {
        case ..<1.5: snapped = 1
        case ..<3: snapped = 2
        case ..<7: snapped = 5
        default: snapped = 10
        }

        return snapped * magnitude
    }

    /// Keeps the outermost x-axis labels inside the plot. A centred end label overflows the plot
    /// edge and gets truncated, so the first label grows rightwards from its tick and the last
    /// grows leftwards; that holds at any label width, unlike widening the date domain.
    private func labelAnchor(at index: Int, of count: Int) -> UnitPoint {
        guard count > 1 else { return .top }

        switch index {
        case 0: return .topLeading
        case count - 1: return .topTrailing
        default: return .top
        }
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
