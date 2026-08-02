import Foundation
import SwiftData

@Model
class WeightItem {
    var weight: Float = 0
    var date: Date = Date()
    
    init(weight: Float) {
        self.weight = weight
    }
}
