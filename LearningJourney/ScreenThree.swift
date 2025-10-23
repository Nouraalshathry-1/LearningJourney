//
//  ScreenThree.swift
//  LearningJourney
//
//  Created by Noura Alshathry on 22/10/2025.
//

import SwiftUI

// MARK: - Month grid (All activities)
struct ScreenThree: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.activityVM) var vm

    @State private var scrollID: Date? = nil

    private var todayID: Date { Calendar.current.startOfDay(for: Date()) }

    private let cal = Calendar.current

    private let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = .current
        f.timeZone = .current
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func earliestLoggedDate() -> Date? {
        let dates = vm.logsByKey.keys.compactMap { dayKeyFormatter.date(from: $0) }
        return dates.min()
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Spacer height ~= header height so first title starts below it
                    Color.clear.frame(height: 56)
                    ForEach(monthsSpan(), id: \.self) { month in
                        MonthSection(month: month)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollPosition(id: $scrollID, anchor: .center)
            .onAppear {
                var t = Transaction()
                t.animation = nil
                withTransaction(t) {
                    scrollID = todayID
                }
            }
            .onChange(of: monthsSpan().hashValue) {
                var t = Transaction()
                t.animation = nil
                withTransaction(t) {
                    scrollID = todayID
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            ZStack {
                // Centered title
                Text("All activities")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)

                // Left-aligned back button
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .buttonStyle(.glass)
                            .glassEffect(.clear, in: .circle)
                            .tint(.appPrimary)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .frame(height: 56)
            .background(.clear)
        }
        .navigationBarBackButtonHidden(true)
        .preferredColorScheme(.dark)
    }

    // MARK: Month computations

    /// First day of the month for a date.
    private func firstOfMonth(_ d: Date) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: d))!
    }

    /// Best-effort guess for the goal start date.
    /// Priority: stored `activity.goalStartAt` (if any) → earliest logged day → today.
    private func goalStartGuess() -> Date {
        let ts = UserDefaults.standard.double(forKey: "activity.goalStartAt")
        if ts > 0 { return Date(timeIntervalSince1970: ts) }
        if let earliest = earliestLoggedDate() { return earliest }
        return Date()
    }

    /// Goal duration in **months**, inferred from stored "activity.duration".
    /// week → 1 month window, month → 1 month, year → 12 months.
    private func goalDurationMonths() -> Int {
        let raw = (UserDefaults.standard.string(forKey: "activity.duration") ?? "").lowercased()
        switch raw {
        case "year":  return 12
        case "month": return 1
        case "week":  fallthrough
        default:      return 1
        }
    }

    /// Months to display: 5 months before the goal start month through 5 months after the goal end month.
    private func monthsSpan() -> [Date] {
        let start = firstOfMonth(goalStartGuess())
        let end   = firstOfMonth(cal.date(byAdding: .month, value: goalDurationMonths(), to: start) ?? start)

        var visibleStart = firstOfMonth(cal.date(byAdding: .month, value: -5, to: start) ?? start)
        var visibleEnd   = firstOfMonth(cal.date(byAdding: .month, value:  5, to: end)   ?? end)

        // Guarantee the span includes today's month
        let todayMonth = firstOfMonth(Date())
        if todayMonth < visibleStart { visibleStart = todayMonth }
        if todayMonth > visibleEnd   { visibleEnd   = todayMonth }

        var out: [Date] = []
        var cursor = visibleStart
        while cursor <= visibleEnd {
            out.append(cursor)
            cursor = cal.date(byAdding: .month, value: 1, to: cursor) ?? cursor
            if out.count > 36 { break }
        }
        return out
    }
}

// MARK: - A month block (title + weekday row + 7xN day grid)
private struct MonthSection: View {
    @Environment(\.activityVM) var vm

    let month: Date

    private let cal = Calendar.current
    private let weekSymbols = ["SUN","MON","TUE","WED","THU","FRI","SAT"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(monthTitle(month))
                .font(.title.weight(.bold))
                .foregroundStyle(.white.opacity(0.95))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Week headers
            HStack {
                ForEach(weekSymbols, id: \.self) { s in
                    Text(s)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 7), spacing: 12) {
                ForEach(gridDays(), id: \.self) { cell in
                    if let date = cell {
                        DayBubble(date: date)
                            .id(Calendar.current.startOfDay(for: date))
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
    }

    private func monthTitle(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        return df.string(from: d)
    }

    /// Dates for the month with leading blanks to align Sunday start
    private func gridDays() -> [Date?] {
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let range = cal.range(of: .day, in: .month, for: start)!
        let firstWeekday = (cal.component(.weekday, from: start) + 6) % 7 // 0..6 with Sunday = 0
        var out = Array(repeating: Optional<Date>.none, count: firstWeekday)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: start) {
                out.append(cal.startOfDay(for: d))
            }
        }
        return out
    }
}

// MARK: - A single day circle with state coloring
private struct DayBubble: View {
    @Environment(\.activityVM) var vm
    private let cal = Calendar.current

    let date: Date

    var body: some View {
        let state = vm.state(for: date)
        let isToday = cal.isDateInToday(date)

        ZStack {
            // Fill according to state
            Circle()
                .fill(fillColor(for: state))
                .frame(width: 36, height: 36)
                .overlay(
                    // Stroke: subtle ring for today if not logged; stronger if selected state
                    Circle().strokeBorder(strokeColor(for: state, isToday: isToday), lineWidth: ringWidth(for: state, isToday: isToday))
                )

            Text("\(cal.component(.day, from: date))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textColor(for: state))
        }
        .accessibilityLabel(accessibilityText(for: state))
    }

    private func fillColor(for state: DayState) -> Color {
        switch state {
        case .learned: return Color("AppPrimary")
        case .frozen:  return Color("AppSecondary")
        case .none:    return .clear
        }
    }
    private func textColor(for state: DayState) -> Color {
        switch state {
        case .learned, .frozen: return .white
        case .none:             return .white.opacity(0.90)
        }
    }
    private func strokeColor(for state: DayState, isToday: Bool) -> Color {
        if state != .none { return .white.opacity(0.15) }
        return isToday ? Color.white.opacity(0.18) : Color.white.opacity(0.08)
    }
    private func ringWidth(for state: DayState, isToday: Bool) -> CGFloat {
        if state != .none { return 1.0 }
        return isToday ? 1.2 : 1.0
    }
    private func accessibilityText(for state: DayState) -> String {
        let day = cal.component(.day, from: date)
        switch state {
        case .learned: return "Day \(day), learned"
        case .frozen:  return "Day \(day), frozen"
        case .none:    return "Day \(day), not logged"
        }
    }
}

#Preview {
    let vm = ActivityViewModel()
    return NavigationStack {
        ScreenThree()
    }
    .environment(\.activityVM, vm)
}
