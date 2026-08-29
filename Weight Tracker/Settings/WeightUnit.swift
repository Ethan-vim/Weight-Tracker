import Foundation

/// The unit weights are shown in. Entries are always stored in kilograms, so this converts at the
/// display and entry boundaries and nothing downstream has to know which unit is selected.
enum WeightUnit: String, CaseIterable, Identifiable {
    case kilograms
    case pounds

    var id: String { rawValue }

    /// Matches the labels on the settings sketch.
    var pickerLabel: String {
        switch self {
        case .kilograms: return "KG"
        case .pounds: return "Pound"
        }
    }

    var suffix: String {
        switch self {
        case .kilograms: return "kg"
        case .pounds: return "lb"
        }
    }

    private static let poundsPerKilogram = 2.20462262

    func fromKilograms(_ kilograms: Double) -> Double {
        switch self {
        case .kilograms: return kilograms
        case .pounds: return kilograms * Self.poundsPerKilogram
        }
    }

    func toKilograms(_ shown: Double) -> Double {
        switch self {
        case .kilograms: return shown
        case .pounds: return shown / Self.poundsPerKilogram
        }
    }
}
