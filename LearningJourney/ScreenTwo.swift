//
//  ScreenTwo.swift
//  LearningJourney
//
//  Created by Noura Alshathry on 19/10/2025.
//

import SwiftUI
import Combine
import Observation

private enum Palette {
    static let bg = Color.black
    static let card = Color(white: 0.12)
    static let stroke = Color.white.opacity(0.08)
    static let label = Color.white
}


extension Color {
    static let card: Color = Color.clear
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r,g,b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (r,g,b) = (1,1,0)
        }
        self = Color(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: 1)
    }
}

// MARK: - Model
enum DayState: String, Codable { case none, learned, frozen }

@Observable
final class ActivityViewModel {
    var month: Date = Date()
    var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    // Use string-keyed logs
    var logsByKey: [String: DayState] = [:]
    var lastLogAt: Date? = nil

    enum QuotaMode { case week }
    var quotaMode: QuotaMode = .week

    var periodRange: (start: Date, end: Date) {
        let now = Date()
        let start = cal.dateInterval(of: .weekOfYear, for: now)!.start
        let end = cal.date(byAdding: .weekOfYear, value: 1, to: start)!
        return (start, end)
    }

    var periodFreezeLimit: Int { 2 }
    
    let maxFreezesPerMonth = 8
    private let cal = Calendar.current

    // Formatter for day keys ("yyyy-MM-dd")
    private let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = .current
        f.timeZone = .current
        f.locale   = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: Calendar.current.startOfDay(for: date))
    }

    private func date(fromDayKey key: String) -> Date? {
        guard let d = dayKeyFormatter.date(from: key) else { return nil }
        return Calendar.current.startOfDay(for: d)
    }

    init() {
        load()
        month = beginningOfMonth(for: selectedDay)
        ensureFreshAfterFirstGoal()
    }

    var daysGrid: [Date?] {
        let start = beginningOfMonth(for: month)
        let range = cal.range(of: .day, in: .month, for: start)!
        let firstWeekdayIndex = (cal.component(.weekday, from: start) + 6) % 7
        let blanks = Array(repeating: Optional<Date>.none, count: firstWeekdayIndex)
        let days = range.compactMap { day -> Date? in
            cal.date(byAdding: .day, value: day - 1, to: start)
        }
        return blanks + days
    }

  
    func weekDays(containing date: Date) -> [Date] {
        let startOfDay = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: startOfDay)
        let sunday = cal.date(byAdding: .day, value: -(weekday - 1), to: startOfDay) ?? startOfDay
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: sunday) }
    }

    var learnedCountThisMonth: Int {
        monthDates.compactMap { state(for: $0) == .learned ? 1 : nil }.count
    }
    var frozenCountThisMonth: Int {
        monthDates.compactMap { state(for: $0) == .frozen ? 1 : nil }.count
    }

    var learnedCountThisWeek: Int {
        let (start, end) = periodRange
        return logsByKey
            .compactMap { (k, v) -> (Date, DayState)? in
                guard let d = date(fromDayKey: k) else { return nil }
                return (d, v)
            }
            .filter { $0.0 >= start && $0.0 < end && $0.1 == .learned }
            .count
    }

    var frozenCountThisPeriod: Int {
        let (start, end) = periodRange
        return logsByKey
            .compactMap { (k, v) -> (Date, DayState)? in
                guard let d = date(fromDayKey: k) else { return nil }
                return (d, v)
            }
            .filter { $0.0 >= start && $0.0 < end && $0.1 == .frozen }
            .count
    }

    var freezesLeft: Int { max(0, periodFreezeLimit - frozenCountThisPeriod) }

    func isToday(_ date: Date) -> Bool {
        cal.isDateInToday(date)
    }

    func state(for date: Date) -> DayState {
        let key = dayKey(for: date)
        return logsByKey[key] ?? .none
    }

    func select(_ date: Date?) {
        guard let date else { return }
        guard Calendar.current.isDateInToday(date) else { return }
        selectedDay = cal.startOfDay(for: date)
    }

    func prevWeek() {
        if let d = cal.date(byAdding: .day, value: -7, to: selectedDay) {
            selectedDay = cal.startOfDay(for: d)
            month = beginningOfMonth(for: selectedDay)
        }
    }
    func nextWeek() {
        if let d = cal.date(byAdding: .day, value: 7, to: selectedDay) {
            selectedDay = cal.startOfDay(for: d)
            month = beginningOfMonth(for: selectedDay)
        }
    }

    func logLearned() {
        set(.learned, for: selectedDay)
        lastLogAt = Date()
        save()
    }

    func logFrozen() {
        guard freezesLeft > 0 else { return }
        set(.frozen, for: selectedDay)
        lastLogAt = Date()
        save()
    }

    private func set(_ state: DayState, for date: Date) {
        let key = dayKey(for: date)
        logsByKey[key] = state
        save()
    }

    var streakCount: Int {
        let today = cal.startOfDay(for: Date())
        if let last = lastLogAt, Date().timeIntervalSince(last) > 32 * 3600 {
            return 0
        }
        var count = 0
        var cursor = today
        while true {
            let state = self.state(for: cursor)
            if state == .none { break }
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    // MARK: - Persistence
    private func save() {
        // Persist as [String: String]
        let dict = Dictionary(uniqueKeysWithValues: logsByKey.map { ($0.key, $0.value.rawValue) })
        UserDefaults.standard.set(dict, forKey: "activity.logs")

        if let last = lastLogAt {
            UserDefaults.standard.set(last.timeIntervalSince1970, forKey: "activity.lastLogAt")
        } else {
            UserDefaults.standard.removeObject(forKey: "activity.lastLogAt")
        }
    }

    /// Clear all activity so a new/changed goal starts fresh
    func resetForNewGoal() {
        logsByKey.removeAll()
        lastLogAt = nil
        UserDefaults.standard.removeObject(forKey: "activity.logs")
        UserDefaults.standard.removeObject(forKey: "activity.lastLogAt")
        save()
    }

    /// If a goal title exists but no creation timestamp was stored yet,
    /// treat this as the first goal creation and start with a clean slate.
    func ensureFreshAfterFirstGoal() {
        let hasTitle = UserDefaults.standard.string(forKey: "activity.goalTitle") != nil
        let created = UserDefaults.standard.double(forKey: "activity.goalCreatedAt")
        if hasTitle && created == 0 {
            resetForNewGoal()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "activity.goalCreatedAt")
        }
    }

    private func load() {
        if let dict = UserDefaults.standard.dictionary(forKey: "activity.logs") as? [String: String] {
            var out: [String: DayState] = [:]
            for (k, v) in dict {
                if let s = DayState(rawValue: v) {
                    out[k] = s
                }
            }
            logsByKey = out

            let ts = UserDefaults.standard.double(forKey: "activity.lastLogAt")
            if ts > 0 { lastLogAt = Date(timeIntervalSince1970: ts) }
        }
    }

    private func beginningOfMonth(for date: Date) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: date))!
    }
    private var monthDates: [Date] {
        let start = beginningOfMonth(for: month)
        let range = cal.range(of: .day, in: .month, for: start) ?? 1..<31
        return range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: start).map { cal.startOfDay(for: $0) } }
    }

    var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"
        return f.string(from: selectedDay)
    }
}

// MARK: - View
struct ScreenTwo: View {
    @Environment(\.activityVM) var vm

    let weekdayShort = ["SUN","MON","TUE","WED","THU","FRI","SAT"]
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // Month/Year wheel picker state
    @State private var showingMonthPicker = false
    @State private var pickerMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var pickerYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showCalendar = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerBar

                calendarCard

                primaryCTA

                secondaryCTA

                footerText
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Palette.bg.ignoresSafeArea())
        .sheet(isPresented: $showingMonthPicker) {
            VStack(spacing: 12) {
                Text("Select Month & Year")
                    .font(.headline)
                    .padding(.top, 8)

                HStack(spacing: 0) {
                    // Month wheel
                    Picker("Month", selection: $pickerMonth) {
                        ForEach(1...12, id: \.self) { m in
                            Text(monthName(m))
                                .tag(m)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.wheel)

                    // Year wheel (current year - 20 .. current year + 5)
                    Picker("Year", selection: $pickerYear) {
                        ForEach(yearsRange(), id: \.self) { y in
                            Text(verbatim: String(y)).tag(y)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.wheel)
                }
                .frame(maxHeight: 220)

                Button {
                    // Apply selection -> jump to first day of chosen month
                    var comp = DateComponents()
                    comp.year = pickerYear
                    comp.month = pickerMonth
                    comp.day = 1
                    if let d = Calendar.current.date(from: comp) {
                        let start = Calendar.current.startOfDay(for: d)
                        vm.selectedDay = start
                        vm.month = start
                    }
                    showingMonthPicker = false
                } label: {
                    Text("Done")
                        .glassEffect(.clear.tint(.appPrimary))
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.appPrimary))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 12)
            }
            .presentationDetents([.height(340)])
        }
        .navigationDestination(isPresented: $showCalendar) {
            ScreenThree()
                .environment(vm)                       // Observation-style environment
                .environment(\.activityVM, vm)         // keep existing key available too
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .onReceive(minuteTimer) { now in
            if !Calendar.current.isDate(vm.selectedDay, inSameDayAs: now) {
                vm.select(now)
            }
            // Safety net: ensure freshness in case arriving from ScreenOne
            vm.ensureFreshAfterFirstGoal()
        }
    }

    private var headerBar: some View {
        HStack {
            Text("Activity")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(Palette.label)
            Spacer()
            HStack(spacing: 14) {
                Button {
                    showCalendar = true
                } label: {
                    Image(systemName: "calendar")
                }
                .buttonStyle(.glass)
                .glassEffect(.regular, in: .circle)
                .tint(.appPrimary)
                Image(systemName: "clock.arrow.circlepath")
            }
            .font(.title2)
            .foregroundColor(Palette.label.opacity(0.9))
        }
    }

    // MARK: - Calendar card broken into smaller helpers (avoids type-check timeout)
    private var calendarHeader: some View {
        HStack {
            Button {
                // seed picker with current selected month/year
                let comp = Calendar.current.dateComponents([.year, .month], from: vm.selectedDay)
                pickerMonth = comp.month ?? pickerMonth
                pickerYear  = comp.year  ?? pickerYear
                showingMonthPicker = true
            } label: {
                HStack(spacing: 6) {
                    Text(vm.monthTitle.uppercased())
                        .font(.headline)
                        .foregroundColor(Palette.label)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(Palette.label.opacity(0.9))
                }
            }

            Spacer()

            Button(action: vm.prevWeek) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.glass)
            .glassEffect(.regular, in: .circle)
            .tint(.appPrimary)

            Button(action: vm.nextWeek) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.glass)
            .glassEffect(.regular, in: .circle)
            .tint(.appPrimary)
        }
    }

    private var weekdayRow: some View {
        HStack {
            ForEach(weekdayShort, id: \.self) { w in
                Text(w)
                    .font(.caption2)
                    .foregroundColor(Palette.label.opacity(0.7))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var weekStrip: some View {
        HStack(spacing: 12) {
            ForEach(vm.weekDays(containing: vm.selectedDay), id: \.self) { date in
                DayButton(date: date)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // Small reusable day button view to reduce expression complexity
    private struct DayButton: View {
        @Environment(\.activityVM) var vm
        let date: Date
        private let cal = Calendar.current

        var body: some View {
            Button {
                vm.select(date)
            } label: {
                ZStack {
                    let state = vm.state(for: date)
                    let isSelected = cal.isDate(vm.selectedDay, inSameDayAs: date)

                    Circle()
                        .fill(
                            state == .learned ? Color.appPrimary :
                            state == .frozen  ? Color.appCon :
                            (isSelected ? Color.appPrimary : Color.clear)
                        )
                        .frame(width: 36, height: 36)

                    if state == .none && !isSelected {
                        Circle().stroke(Palette.stroke, lineWidth: 1).frame(width: 36, height: 36)
                    } else if isSelected {
                        Circle().stroke(Color.white.opacity(0.25), lineWidth: 2).frame(width: 36, height: 36)
                    }

                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(isSelected || state != .none ? .white : Palette.label.opacity(0.9))
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            calendarHeader

            weekdayRow

            weekStrip

            Divider().background(Palette.stroke)

            VStack(alignment: .leading, spacing: 10) {
                Text("Learning Activity")
                    .font(.subheadline)
                    .foregroundColor(Palette.label)

                HStack(spacing: 12) {
                    metricBadge(bg: .appCircle, icon: "flame.fill", value: vm.learnedCountThisWeek, label: "Days Learned", iconColor: .appPrimary)
                    metricBadge(bg: .appCon, icon: "cube.fill", value: vm.frozenCountThisPeriod, label: "Days Freezed", iconColor: .appCon)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.card)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.stroke))
        )
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let state = vm.state(for: date)
        let isSelected = Calendar.current.isDate(vm.selectedDay, inSameDayAs: date)

        Button {
            vm.select(date)
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.appPrimary :
                          state == .learned ? Color.appPrimary :
                          state == .frozen ? Color.appSecondary :
                          Color.card.opacity(0.001))
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(isSelected || state != .none ? .white : Palette.label.opacity(0.8))
            }
            .frame(height: 34)
        }
        .buttonStyle(.plain)
    }

    private var metricsSection: some View {
        HStack(spacing: 14) {
            metricCard(icon: "flame.fill", value: vm.learnedCountThisWeek, noun: "Learned")
            metricCard(icon: "cube.fill", value: vm.frozenCountThisPeriod, noun: "Freezed")
        }
    }

    private func metricCard(icon: String, value: Int, noun: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)").font(.title2.weight(.bold))
                Text("\(value == 1 ? "Day" : "Days") \(noun)")
                    .font(.caption).opacity(0.9)
            }
            Spacer(minLength: 0)
        }
        .foregroundColor(Palette.label)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.card)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.stroke))
        )
    }

    private var primaryCTA: some View {
        let state = vm.state(for: vm.selectedDay)
        let enabled = (state == .none) && Calendar.current.isDateInToday(vm.selectedDay)

        return Button {
            vm.logLearned()
        } label: {
            Text(
                state == .none ? "Log as\nLearned" :
                state == .learned ? "Learned\nToday" :
                "Day\nFreezed"
            )
            .multilineTextAlignment(.center)
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 270, height: 270)
            .contentShape(Circle())
        }
        .buttonStyle(.glass)
        .glassEffect(.regular, in: Circle())
        .tint(.appPrimary)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.95)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 6)
    }

    private var secondaryCTA: some View {
        let state = vm.state(for: vm.selectedDay)
        let canFreeze = (state == .none) && vm.freezesLeft > 0 && Calendar.current.isDateInToday(vm.selectedDay)

        return Button {
            vm.logFrozen()
        } label: {
            Text("Log as Freezed")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.glass)
        .glassEffect(.regular, in: Capsule())
        .tint(canFreeze ? .appSecondary : Color.card)
        .disabled(!canFreeze)
    }

    private var footerText: some View {
        Text("\(vm.periodFreezeLimit - vm.freezesLeft) out of \(vm.periodFreezeLimit) Freezes used")
            .font(.footnote)
            .foregroundColor(.white.opacity(0.8))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 6)
    }
}

#Preview {
    NavigationStack {
        ScreenTwo()
            .environment(\.activityVM, ActivityViewModel())
    }
}

    private func monthName(_ m: Int) -> String {
        let f = DateFormatter()
        return f.monthSymbols[(max(1, min(12, m)) - 1)]
    }

    private func yearsRange() -> [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 20)...(current + 5))
    }

    // Helper for colored metric badges in calendarCard
    private func metricBadge(bg: Color, icon: String, value: Int, label: String, iconColor: Color = .white) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)").font(.headline.weight(.bold)).foregroundStyle(.white)
                Text("\(value == 1 ? "Day" : "Days") \(label.split(separator: " ").last!)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(bg)
        )
    }
