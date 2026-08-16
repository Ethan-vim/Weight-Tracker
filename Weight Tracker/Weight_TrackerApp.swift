import SwiftUI
import SwiftData

enum Page {
    case main
    case calorieEstimator
}

@main
struct Weight_TrackerApp: App {
    @State private var selectedPage: Page = .main

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            WeightItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            switch selectedPage {
            case .main:
                ContentView(selectedPage: $selectedPage)
            case .calorieEstimator:
                CalorieEstimatorPage(selectedPage: $selectedPage)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
