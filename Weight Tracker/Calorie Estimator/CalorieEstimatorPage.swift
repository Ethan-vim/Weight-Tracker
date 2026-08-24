import SwiftUI
import PhotosUI

struct CalorieEstimatorPage: View {
    @Binding var selectedPage: Page

    private enum EstimateState {
        case idle
        case loading
        case loaded(NutritionInfo)
        case failed(String)
    }

    @State private var state: EstimateState = .idle
    @State private var mealPhoto: UIImage?
    @State private var libraryItem: PhotosPickerItem?
    @State private var isShowingCamera = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
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

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            switch state {
            case .idle:
                photoPrompt
            case .loading:
                results(for: nil, message: nil)
            case .loaded(let info):
                results(for: info, message: nil)
            case .failed(let message):
                results(for: nil, message: message)
            }

            Spacer()
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                guard let image = await NutritionService.loadPhoto(from: item) else {
                    state = .failed("That photo could not be opened. Try another one.")
                    return
                }
                await estimate(for: image)
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { image in
                isShowingCamera = false
                guard let image else { return }
                Task { await estimate(for: image) }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Before a photo is chosen

    private var photoPrompt: some View {
        VStack(spacing: 16) {
            photoWell
                .frame(height: 260)

            Text("Take or choose a photo of your meal to estimate its calories and nutrients.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Text("Choose Photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if CameraPicker.isAvailable {
                    Button {
                        isShowingCamera = true
                    } label: {
                        Text("Take Photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .padding(.horizontal)
    }

    private var photoWell: some View {
        ZStack {
            Color(.secondarySystemBackground)

            if let mealPhoto {
                // A fill-scaled image overflows its proposal, so the flexible frame keeps the
                // surrounding layout sized by the well instead of by the photo.
                Image(uiImage: mealPhoto)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 36))
                    Text("Meal Photo")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(.separator), lineWidth: 1)
        }
    }

    // MARK: - After a photo is analyzed

    /// The loading, loaded and failed states share this layout so the page does not jump around
    /// while an estimate is in flight. A nil `info` with no `message` is the loading case.
    private func results(for info: NutritionInfo?, message: String?) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                photoWell
                    .frame(width: 140)

                ZStack {
                    if let info {
                        NutrientPieChart(info: info)
                    } else if message == nil {
                        ProgressView()
                    } else {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 170)

            adviceBand(info: info, message: message)

            Button("Try Another Photo") {
                reset()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.horizontal)
    }

    private func adviceBand(info: NutritionInfo?, message: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message == nil ? "Advice" : "Something Went Wrong")
                .font(.headline)

            if let info {
                Text(info.advice)
                    .font(.subheadline)
            } else if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Estimating calories and nutrients from your photo…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func estimate(for image: UIImage) async {
        mealPhoto = image
        state = .loading

        do {
            state = .loaded(try await NutritionService.getCalories(from: image))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func reset() {
        mealPhoto = nil
        libraryItem = nil
        state = .idle
    }
}

#Preview {
    CalorieEstimatorPage(selectedPage: .constant(.calorieEstimator))
}
