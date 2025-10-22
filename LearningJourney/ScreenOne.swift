//
//  ScreenOne.swift
//  LearningJourney
//
//  Created by Noura Alshathry on 21/10/2025.
//


import SwiftUI

// MARK: - Environment key for ActivityViewModel (iOS 17 style)
private struct ActivityViewModelKey: EnvironmentKey {
    static let defaultValue: ActivityViewModel = ActivityViewModel()
}

extension EnvironmentValues {
    var activityVM: ActivityViewModel {
        get { self[ActivityViewModelKey.self] }
        set { self[ActivityViewModelKey.self] = newValue }
    }
}

extension ActivityViewModel {
    /// Clears all activity so a new or changed goal starts fresh.
    func resetForNewGoal() {
        logs.removeAll()
        lastLogAt = nil
        // Clear persisted state as well
        UserDefaults.standard.removeObject(forKey: "activity.logs")
        UserDefaults.standard.removeObject(forKey: "activity.lastLogAt")
    }
}
struct ScreenOne: View {
    @State private var vm = ActivityViewModel()

    @State private var topic: String = ""
    @State private var selectedDuration: LearningDuration? = nil
    @State private var navigate = false

    @State private var attempted = false

    private let flameCircleSize: CGFloat = 109     // matches visual spec
    private let chipSize = CGSize(width: 97, height: 48)   // Week/Month/Year
    private let startSize = CGSize(width: 182, height: 48) // Start learning

    private var isTopicValid: Bool { !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isDurationValid: Bool { selectedDuration != nil }
    private var formValid: Bool { isTopicValid && isDurationValid }

    private enum LearningDuration: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        var id: String { rawValue }
    }

    private enum Palette {
        static let orange = Color("AppPrimary")            // primary orange
        static let chipBG = Color("AppSecondary")            // unselected chip background
        static let stroke = Color.white.opacity(0.15)         // hairline strokes
        static let label  = Color.white
        static let sub    = Color(hex: "#8E8E93")            // iOS placeholder grey
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {

                ZStack {
                    Circle()
                        .glassEffect(.clear.tint(.appCircle))
                        .frame(width: flameCircleSize, height: flameCircleSize)
                        .allowsHitTesting(false)

                    Image("flame")
                        .resizable()
                        .scaledToFit()
                        .frame(width: flameCircleSize * 0.36, height: flameCircleSize * 0.36)
                }
             
                
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Hello Learner")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Palette.label)
                    Text("This app will help you learn everyday!")
                        .foregroundColor(Palette.sub)
                        .font(.footnote)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Text("I want to learn")
                            .foregroundColor(Palette.label)
                            .font(.headline)
                        if attempted && !isTopicValid {
                            Text("*")
                                .font(.headline)
                                .foregroundColor(.red)
                                .accessibilityLabel("Required field")
                        }
                    }

                    TextField(text: $topic, prompt: Text("Swift").foregroundColor(Palette.sub)) { EmptyView() }
                        .foregroundStyle(Palette.orange)
                        .tint(.gray)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    Rectangle()
                        .fill(Palette.stroke)
                        .frame(height: 1)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Text("I want to learn it in a")
                            .foregroundColor(Palette.label)
                            .font(.headline)
                        if attempted && !isDurationValid {
                            Text("*")
                                .font(.headline)
                                .foregroundColor(.red)
                                .accessibilityLabel("Required field")
                        }
                    }

                    HStack(spacing: 12) {
                        chip(.week)
                        chip(.month)
                        chip(.year)
                    }
                }
                .padding(.top, 8)

                Spacer(minLength: 20)

                HStack {
                    Spacer()
                    Button {
                        attempted = true
                        guard formValid else { return }
                        persistSelections()
                        navigate = true
                    } label: {
                        Text("Start learning")
                            .glassEffect(.clear.tint(.appPrimary))
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 182, height: 48)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    Spacer()
                }


                
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigate) {
                ScreenTwo()
            }
        }
        .environment(\.activityVM, vm)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func chip(_ value: LearningDuration) -> some View {
        let selected = (value == selectedDuration)
        Button {
            selectedDuration = value; attempted = false
        } label: {
            Text(value.rawValue)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 80, height: 40)
        }
        .buttonStyle(.glassProminent)
        .tint(selected ? Palette.orange : Color.clear)
        .frame(width: chipSize.width, height: chipSize.height)
        .buttonBorderShape(.capsule)
    }

    // Saves topic and duration for later use in the app
    private func persistSelections() {
        guard isTopicValid, let duration = selectedDuration else { return }
        let previousTitle = UserDefaults.standard.string(forKey: "activity.goalTitle") ?? ""
        let previousDuration = UserDefaults.standard.string(forKey: "activity.duration") ?? "week"
        let newTitle = topic
        let newDuration = duration.rawValue.lowercased()

        // If the learning goal or duration changes, reset streak/logs per spec.
        if previousTitle != newTitle || previousDuration != newDuration {
            vm.resetForNewGoal()
        }

        UserDefaults.standard.set(newTitle, forKey: "activity.goalTitle")
        UserDefaults.standard.set(newDuration, forKey: "activity.duration")

        // Current app logic: week quota; can be expanded later.
        vm.quotaMode = .week
    }
}

#Preview {
    ScreenOne()
        .environment(\.activityVM, ActivityViewModel())
}
