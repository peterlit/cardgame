import SwiftUI

/// Challenges & Streaks screen — the native mirror of the web Daily overlay: four streaks
/// (Play / Silver / Gold / Flawless), the selected day's tiered challenge card, and a month
/// calendar you can tap to inspect past days. "Play"/"Replay" hands off to game.playChallenge.
struct DailyView: View {
    @ObservedObject var game: Game
    @Environment(\.dismiss) private var dismiss

    /// Which day the card is showing (defaults to today, clamped into the pool).
    @State private var dayView: Int = 0

    private var days: [Int: TierResult] { game.dailyStore.days }
    private var pool: [PoolSeed] { game.pool }

    private let medal = ["bronze": "🥉", "silver": "🥈", "gold": "🥇"]
    private let calCols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    streaksRow
                    dayCard
                    calendar
                }
                .padding()
            }
            .navigationTitle("Daily Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear { dayView = clampedToday }
    }

    private var clampedToday: Int { min(max(0, todayIndex()), max(0, pool.count - 1)) }

    // MARK: streaks

    private var streaksRow: some View {
        let s = streaks(days, todayIndex())
        let items: [(String, String, StreakRun)] =
            [("🔥", "Play", s.play), ("🥈", "Silver", s.silver), ("🥇", "Gold", s.gold), ("🌟", "Flawless", s.flawless)]
        return HStack(spacing: 8) {
            ForEach(items, id: \.1) { ic, label, run in
                VStack(spacing: 2) {
                    Text(ic).font(.system(size: 18))
                    Text("\(run.current)").font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.gold)
                    Text(label).font(.system(size: 11, weight: .semibold))
                    Text("\(run.total) total").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    Text("best \(run.best)").font(.system(size: 10)).foregroundStyle(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))
            }
        }
    }

    // MARK: the selected day's challenge card

    @ViewBuilder private var dayCard: some View {
        let ti = todayIndex()
        if let c = dailyChallenge(dayView, pool) {
            let rec = days[dayView]
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(dayView == ti ? "Today" : dayLabel(dayView))
                        .font(.system(size: 16, weight: .bold))
                    if rec?.flawless == true {
                        Text("🌟 Flawless").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.gold)
                    }
                    Spacer()
                    Text("Deal #\(c.seed)").font(.system(size: 13)).foregroundStyle(.secondary).monospacedDigit()
                }
                VStack(spacing: 8) {
                    tierRow("Bronze", "bronze", "Clear the deal", rec, future: dayView > ti)
                    tierRow("Silver", "silver", c.silver.label, rec, future: dayView > ti)
                    tierRow("Gold", "gold", c.gold.label, rec, future: dayView > ti)
                }
                playButton(day: dayView, ti: ti, rec: rec)
                // "Show me how to win": one line per tier — Bronze clears the deal; Silver/Gold obey
                // that day's objective. Demonstrations (assisted) — never count toward tiers.
                if dayView <= ti, game.hasSolution(c.seed) {
                    Text("Show me how to win:")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 6) {
                        showPill(c.seed, "bronze", "🥉 Clear", "Clear the deal")
                        if game.hasSilverLine(c.seed) { showPill(c.seed, "silver", "🥈 Silver", c.silver.label) }
                        if game.hasGoldLine(c.seed) { showPill(c.seed, "gold", "🥇 Gold", c.gold.label) }
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.10)))
        } else {
            VStack(spacing: 6) {
                Text(dayLabel(dayView)).font(.system(size: 16, weight: .bold))
                Text("No challenge available yet").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(24)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.10)))
        }
    }

    private func tierRow(_ name: String, _ tier: String, _ text: String, _ rec: TierResult?, future: Bool) -> some View {
        let done = rec?[tier] == true
        let color: Color = done ? .green : (future ? .secondary : Theme.red)
        return HStack(spacing: 10) {
            Text(medal[tier] ?? "").font(.system(size: 18))
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 14, weight: .semibold))
                Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(color)
        }
    }

    @ViewBuilder private func playButton(day: Int, ti: Int, rec: TierResult?) -> some View {
        if day > ti {
            Text("Unlocks \(dayLabel(day))")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.12)))
        } else {
            let replay = rec?.bronze == true
            Button {
                game.playChallenge(day)
                dismiss()
            } label: {
                Text(replay ? "Replay to improve ↻" : "Play")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(replay ? Color.gray.opacity(0.18) : Theme.gold))
                    .foregroundStyle(replay ? Theme.ink : Color(hex: 0x3A2B00))
            }
            .buttonStyle(.plain)
        }
    }

    /// A per-tier "show a winning line" button — hands off to the demo (assisted, unscored).
    private func showPill(_ seed: Int, _ tier: String, _ title: String, _ label: String) -> some View {
        Button {
            game.showSolution(seed, tier: tier, label: label)
            dismiss()
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.gold.opacity(0.20)))
                .foregroundStyle(Theme.ink)
        }
        .buttonStyle(.plain)
    }

    // MARK: month calendar

    private var calendar: some View {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        let y = now.year ?? 2026, m = now.month ?? 1
        let ti = todayIndex()
        let first = floorMod(floorMod(daysFromCivil(y, m, 1), 7) + 4, 7)   // 0 = Sunday (matches web; floor-mod matches JS %)
        let dim = daysInMonth(y, m)
        return VStack(spacing: 8) {
            HStack {
                Text(monthLabel(y, m)).font(.system(size: 14, weight: .semibold))
                Spacer()
                HStack(spacing: 10) {
                    ForEach(["bronze", "silver", "gold"], id: \.self) { t in Text(medal[t] ?? "") }
                    Text("🌟 Flawless")
                }.font(.system(size: 11)).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: calCols, spacing: 4) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { d in
                    Text(d).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                // Data-driven ForEach (not the constant-range ForEach(0..<Int)) so a month rollover
                // that changes `first` re-diffs cleanly; negative ids never collide with day cells.
                ForEach(Array(0..<first).map { -($0 + 1) }, id: \.self) { _ in Color.clear.frame(height: 40) }
                ForEach(1...dim, id: \.self) { d in
                    calCell(idx: dayIndexFor(y, m, d), day: d, ti: ti)
                }
            }
        }
    }

    private func calCell(idx: Int, day: Int, ti: Int) -> some View {
        let rec = days[idx]
        let avail = idx >= 0 && idx < pool.count && idx <= ti
        let dots = ["bronze", "silver", "gold"].filter { rec?[$0] == true }
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(idx == dayView ? Theme.gold.opacity(0.28) : Color.gray.opacity(avail ? 0.12 : 0.04))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(idx == ti ? Theme.gold : .clear, lineWidth: 1.5))
            VStack(spacing: 2) {
                Text("\(day)").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(avail ? Color.primary : Color.secondary.opacity(0.5))
                // A flawless day shows a ⭐ in the marker slot (flawless implies all three tiers), so
                // it never overlaps the date; other days show the earned-tier dots.
                if rec?.flawless == true {
                    Text("🌟").font(.system(size: 11)).frame(height: 6)   // same reserved height as the dots row → no date jitter
                } else {
                    HStack(spacing: 2) {
                        ForEach(dots, id: \.self) { t in
                            Circle().fill(dotColor(t)).frame(width: 5, height: 5)
                        }
                    }.frame(height: 6)
                }
            }
        }
        .frame(height: 40)
        .contentShape(Rectangle())
        .onTapGesture { if avail { dayView = idx } }
    }

    private func dotColor(_ tier: String) -> Color {
        switch tier {
        case "bronze": return Color(hex: 0xC98B3A)
        case "silver": return Color(hex: 0x9AA0A6)
        default:       return Color(hex: 0xD9AD55)
        }
    }

    // MARK: date helpers

    private func daysInMonth(_ y: Int, _ m: Int) -> Int {
        let nm = m == 12 ? 1 : m + 1, ny = m == 12 ? y + 1 : y
        return daysFromCivil(ny, nm, 1) - daysFromCivil(y, m, 1)
    }
    private func dateFrom(dayIndex idx: Int) -> Date? {
        var c = DateComponents(); c.year = 2026; c.month = 8; c.day = 12
        let cal = Calendar(identifier: .gregorian)
        return cal.date(from: c).flatMap { cal.date(byAdding: .day, value: idx, to: $0) }
    }
    private func dayLabel(_ idx: Int) -> String {
        guard let d = dateFrom(dayIndex: idx) else { return "" }
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }
    private func monthLabel(_ y: Int, _ m: Int) -> String {
        var c = DateComponents(); c.year = y; c.month = m; c.day = 1
        guard let d = Calendar.current.date(from: c) else { return "" }
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"; return f.string(from: d)
    }
}

/// Subscript sugar so tierRow/calCell can read a tier by its string key (matching the web).
private extension TierResult {
    subscript(_ tier: String) -> Bool {
        switch tier {
        case "bronze": return bronze
        case "silver": return silver
        case "gold": return gold
        case "flawless": return flawless
        default: return false
        }
    }
}

/// Compact live objectives HUD shown over the board during a challenge attempt — Bronze plus the
/// day's Silver and Gold, each marked live (✓ met / ✗ impossible / · still open). UI hint only;
/// the authoritative scoring runs at win via the checkers.
struct DailyHUD: View {
    @ObservedObject var game: Game

    var body: some View {
        if let c = game.liveChallenge {
            let t = game.liveAttempt()
            HStack(spacing: 8) {
                objChip("🥉", "Clear the deal", state: t.won ? .ok : .live)
                objChip("🥈", c.silver.label, state: liveState(c.silver, t))
                objChip("🥇", c.gold.label, state: liveState(c.gold, t))
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Capsule().fill(Color.black.opacity(0.55)))
        }
    }

    private enum ObjState { case ok, no, live }
    private func liveState(_ obj: Objective, _ t: Attempt) -> ObjState {
        if t.won { return evaluate(obj, Attempt(won: true, moves: t.moves, elapsed: t.elapsed,
                                                cellUses: t.cellUses, undos: t.undos,
                                                foundationOrder: t.foundationOrder)) ? .ok : .no }
        if objViolated(obj, t) { return .no }
        // On track: green ✓ as soon as the tier is locked in (guaranteed just by clearing the deal).
        return objSecured(obj, t, up: game.up, down: game.down) ? .ok : .live
    }
    private func objChip(_ medal: String, _ label: String, state: ObjState) -> some View {
        let mark = state == .ok ? "✓" : (state == .no ? "✗" : "·")
        let color: Color = state == .ok ? .green : (state == .no ? Color(hex: 0xE8927C) : .white)
        return HStack(spacing: 3) {
            Text("\(medal)\(mark)").font(.system(size: 11, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(.white).lineLimit(1)
        }
    }
}
