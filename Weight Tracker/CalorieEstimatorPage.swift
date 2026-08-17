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
                    .frame(width: 60, height: 28)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    CalorieEstimatorPage(selectedPage: .constant(.calorieEstimator))
}
