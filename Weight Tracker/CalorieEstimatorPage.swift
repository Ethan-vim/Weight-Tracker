import SwiftUI

struct CalorieEstimatorPage: View {
    @Binding var selectedPage: Page

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text("Calorie Estimator")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                selectedPage = .main
            } label: {
                Text("Back")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding()
        }
    }
}

#Preview {
    CalorieEstimatorPage(selectedPage: .constant(.calorieEstimator))
}
