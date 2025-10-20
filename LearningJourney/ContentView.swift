//
//  ContentView.swift
//  LearningJourney
//
//  Created by Noura Alshathry on 16/10/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = ActivityViewModel()

    @State private var topic: String = ""
    @State private var selectedDuration: LearningDuration = .week
    @State private var navigate = false

    private enum LearningDuration: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        var id: String { rawValue }
    }

    private enum Palette {
        static let orange = Color(hex: "#FF9230")
        static let card   = Color(white: 0.12)
        static let stroke = Color.white.opacity(0.10)
        static let label  = Color.white
        static let sub    = Color.white.opacity(0.7)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {

                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.25))
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .frame(width: 96, height: 96)
                        .overlay(
                            Circle().stroke(Palette.orange.opacity(0.7), lineWidth: 1)
                        )
                        .shadow(color: Palette.orange.opacity(0.25), radius: 22, x: 0, y: 8)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(Palette.orange)
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
                    Text("I want to learn")
                        .foregroundColor(Palette.label)
                        .font(.headline)

                    TextField("Swift", text: $topic)
                        .foregroundColor(Palette.sub)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    Rectangle()
                        .fill(Palette.stroke)
                        .frame(height: 1)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("I want to learn it in a")
                        .foregroundColor(Palette.label)
                        .font(.headline)

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
                        persistSelections()
                        navigate = true
                    } label: {
                        Text("Start learning")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 240)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Palette.orange.opacity(0.45))
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                            )
                            .overlay(
                                Capsule().stroke(Palette.orange.opacity(0.9), lineWidth: 1)
                            )
                            .shadow(color: Palette.orange.opacity(0.25), radius: 10, x: 0, y: 4)
                    }
                    Spacer()
                }

            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigate) {
                ScreenTwo()
                    .environmentObject(vm)
            }
        }
        .environmentObject(vm)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func chip(_ value: LearningDuration) -> some View {
        Button {
            selectedDuration = value
        } label: {
            Text(value.rawValue)
                .font(.callout.weight(.semibold))
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(
                    Capsule()
                        .fill(value == selectedDuration ? Palette.orange.opacity(0.85) : Color.black.opacity(0.22))
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                )
                .overlay(
                    Capsule()
                        .stroke(Palette.stroke, lineWidth: value == selectedDuration ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value.rawValue) duration")
    }

    private func persistSelections() {
        UserDefaults.standard.set(topic, forKey: "activity.goalTitle")
        UserDefaults.standard.set(selectedDuration.rawValue.lowercased(), forKey: "activity.duration")

        switch selectedDuration {
        case .week:
            vm.quotaMode = .week
        case .month:
            vm.quotaMode = .week
        case .year:
            vm.quotaMode = .week
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ActivityViewModel())
}
