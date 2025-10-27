import SwiftUI

struct ScreenFour: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.activityVM) private var vm

    @State private var topic: String = ""
    @State private var selectedDuration: String = "week"
    @State private var attempted = false

    private enum Palette {
        static let orange = Color("AppPrimary")
        static let chipBG = Color("AppSecondary")
        static let stroke = Color.white.opacity(0.15)
        static let label  = Color.white
        static let sub    = Color(hex: "#8E8E93")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .glassEffect(.clear, in: .circle)
                .tint(.appPrimary)

                Spacer()

                Text("Learning Goal")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    saveChanges()
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .glassEffect(.clear, in: .circle)
                .tint(.appPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Color.clear)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Group {
                        Text("I want to learn")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Palette.label)

                        // Input styled to match design: dark rounded capsule with inset text
                        ZStack {
                            Capsule()
                                .fill(Color.card.opacity(0.18))
                                .frame(height: 48)

                            TextField("Swift", text: $topic)
                                .foregroundColor(Palette.orange)
                                .tint(Palette.orange)
                                .padding(.horizontal, 18)
                                .frame(height: 48)
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)
                        }
                    }
                    .padding(.top, 6)

                    Group {
                        HStack(spacing: 6) {
                            Text("I want to learn it in a")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Palette.label)

                            if attempted && selectedDuration.isEmpty {
                                Text("*")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .accessibilityLabel("Required field")
                            }
                        }

                        HStack(spacing: 12) {
                            durationChip("week")
                            durationChip("month")
                            durationChip("year")
                        }
                        .padding(.top, 6)
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(Color.black.ignoresSafeArea())
        }
        .onAppear(perform: loadCurrent)
        .preferredColorScheme(.dark)
    }

    private func durationChip(_ value: String) -> some View {
        let selected = (value == selectedDuration)
        return Button {
            selectedDuration = value
            attempted = false
        } label: {
            Text(value.capitalized)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 97, height: 48)
        }
        .buttonStyle(.glassProminent)
        .glassEffect(.regular, in: .capsule)
        .tint(selected ? Color("AppPrimary") : Color("AppSecondary").opacity(0.12))
        .buttonBorderShape(.capsule)
    }

    private func loadCurrent() {
        topic = UserDefaults.standard.string(forKey: "activity.goalTitle") ?? ""
        selectedDuration = UserDefaults.standard.string(forKey: "activity.duration") ?? "week"
    }

    private func saveChanges() {
        let prevTitle = UserDefaults.standard.string(forKey: "activity.goalTitle") ?? ""
        let prevDuration = UserDefaults.standard.string(forKey: "activity.duration") ?? "week"
        let newTitle = topic
        let newDuration = selectedDuration

        if prevTitle != newTitle || prevDuration != newDuration {
            vm.resetForNewGoal()
        }

        UserDefaults.standard.set(newTitle, forKey: "activity.goalTitle")
        UserDefaults.standard.set(newDuration, forKey: "activity.duration")
    }
}

#Preview {
    ScreenFour()
        .environment(\.activityVM, ActivityViewModel())
}
