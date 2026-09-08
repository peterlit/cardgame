import SwiftUI
import UniformTypeIdentifiers

/// Challenges & Streaks screen — the native mirror of the web Daily overlay: four streaks
/// (Play / Silver / Gold / Flawless), the selected day's tiered challenge card, and a month
/// calendar you can tap to inspect past days. "Play"/"Replay" hands off to game.playChallenge.
struct DailyView: View {
    @ObservedObject var game: Game
    @Environment(\.dismiss) private var dismiss

    /// Which day the card is showing (defaults to today, clamped into the pool).
    @State private var dayView: Int = 0

    /// Which MONTH the grid is drawing, as year*12 + (month-1); 0 = not yet set (see onAppear).
    /// Separate from `dayView`: the grid used to be hard-wired to `Date()`, so on the 1st of a month
    /// every earlier day — including an attempt still inside its ⏰ grace — became unreachable, with
    /// no control to go back.
    @State private var calMonth: Int = 0

    // Stats backup (Export/Import) — a local, iCloud-free way to save/restore progress.
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDoc = StatsBackupDocument(data: Data())
    @State private var backupNote: String?

    /// The day index of an UNAVAILABLE calendar cell the player just tapped (nil = none). A future
    /// day's cell used to swallow the tap silently — no highlight, no tint, no message — so it was
    /// indistinguishable from a broken calendar, while the "Unlocks <date>" copy the app already
    /// ships lives on the day card, which an unavailable day can never reach
    /// (ux/WF-13:future-day-tap-no-feedback).
    @State private var lockedDay: Int?

    /// A board-replacing request parked behind the "you have a game in progress" confirmation
    /// (nil = no confirmation showing).
    ///
    /// Every route out of this sheet that re-deals the board goes through here. Before round 1 only
    /// the demo pills confirmed, and only for a daily attempt — so the DAY CARD'S OWN `Play` threw
    /// away a live attempt silently (ux/WF-5, ux/WF-13) and a demo pill threw away a live CASUAL
    /// game silently (ux/WF-6). Three reports, one shape: the app guarded the rare path and not the
    /// common ones.
    private enum PendingAction {
        case demo(seed: Int, tier: String, label: String, day: Int)
        case play(day: Int)
    }
    @State private var pending: PendingAction?

    /// Is there a real, unfinished game that a re-deal would destroy? (See `Game.hasLiveGame` — it
    /// lives on the model because only the model can see `boardComplete`.)
    private var hasLiveGame: Bool { game.hasLiveGame }

    /// Copy for the confirmation. A daily attempt is replayable, a casual game is not — so the
    /// daily-specific promise ("you can replay the challenge afterwards") must NOT be reused for a
    /// casual game, whose loss really is final.
    private var confirmTitle: String {
        game.challengeDay != nil ? "End your daily attempt?" : "Discard the game in progress?"
    }
    private var confirmMessage: String {
        let cause: String
        switch pending {
        case .demo:  cause = "Watching a demo re-deals the board"
        case .play:  cause = "Starting this challenge re-deals the board"
        case .none:  cause = "This re-deals the board"
        }
        // A zero-move board reaches this dialog only through a live ⏰ grace (Game.hasLiveGame):
        // nothing has been played, so the clause naming the cost is dropped rather than printing
        // "your 0 moves" (bug/Game.swift:grace-forfeited-without-confirm-at-zero-moves).
        let lead = game.moveCount == 0 ? cause
            : "\(cause), so your \(game.moveCount) move\(game.moveCount == 1 ? "" : "s") and your time will be discarded"
        // The ⏰ grace is the one loss "you can replay the challenge afterwards" does not cover:
        // the tiers come back, the same-day award never does (ux/WF-14:replay-forfeits-grace-silently).
        if game.graceLive, let day = game.challengeDay {
            let d = dayLabel(day)
            return "\(lead). You began \(d)'s challenge on the day itself — starting over "
                 + "makes it an attempt begun today, and \(d) can never earn ⏰ Same-day again."
        }
        return game.challengeDay != nil
            ? "\(lead). You can replay the challenge afterwards."
            : "\(lead). This game is not a challenge, so there is no way back to it."
    }
    private var confirmVerb: String {
        if case .demo = pending { return "Show demo" }
        return "Start over"
    }

    private var days: [Int: TierResult] { game.dailyStore.days }
    private var pool: [PoolDay] { game.pool }

    private let medal = ["bronze": "🥉", "silver": "🥈", "gold": "🥇"]
    private let calCols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    streaksRow
                    dayCard
                    calendar
                    backupSection
                }
                .padding()
            }
            .navigationTitle("Daily Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear { dayView = clampedToday; calMonth = monthNo(of: clampedToday) }
        // onCancellation overloads (iOS 17+): the completion handler isn't called on an
        // interactive cancel, so acknowledge cancel explicitly instead of leaving stale text.
        .fileExporter(isPresented: $showExporter, document: exportDoc, contentTypes: [.json],
                      defaultFilename: exportFilename) { result in
            backupNote = { if case .failure = result { return "Export failed." } else { return "Stats exported." } }()
        } onCancellation: {
            backupNote = "Export cancelled."
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            importStats(result)
        } onCancellation: {
            backupNote = "Import cancelled."
        }
        // Both a demo (Game.showSolution → deal) and the day card's Play (Game.playChallenge →
        // deal) replace the board, which would silently discard whatever is in progress — confirm
        // first for BOTH, and for a casual game as well as a daily attempt. Mirrors the web's
        // confirm(). The confirmed action still re-deals: "Play" must remain a restart, else the
        // alert's own "you can replay the challenge afterwards" would be false. playChallenge()
        // routes through deal(), which resets telemetry, so a restart can never keep the previous
        // attempt's banked moves/time.
        .alert(confirmTitle, isPresented: Binding(
            get: { pending != nil },
            set: { if !$0 { pending = nil } })
        ) {
            Button(confirmVerb, role: .destructive) {
                switch pending {
                case .demo(let seed, let tier, let label, let day):
                    game.showSolution(seed, tier: tier, label: label, day: day)
                case .play(let day):                       game.playChallenge(day)
                case .none:                                return
                }
                pending = nil
                dismiss()
            }
            Button("Keep playing", role: .cancel) { pending = nil }
        } message: {
            Text(confirmMessage)
        }
    }

    private var clampedToday: Int { min(max(0, todayIndex()), max(0, pool.count - 1)) }

    // MARK: streaks

    /// Four streak cards. Each shows THREE numbers, so each number carries its own caption: the
    /// tier name moves ABOVE the headline (where it names the card, not a number) and the headline
    /// gets an explicit "day streak" caption underneath — previously the big number was the only
    /// unlabelled figure on the sheet and the word "streak" appeared nowhere near it
    /// (ux/WF-5:streak-card-headline-unlabelled).
    private var streaksRow: some View {
        let s = streaks(days, todayIndex())
        let items: [(String, String, StreakRun)] =
            [("🔥", "Play", s.play), ("⏰", "Same-day", s.onTime), ("🥈", "Silver", s.silver),
             ("🥇", "Gold", s.gold), ("🌟", "Flawless", s.flawless)]
        return VStack(spacing: 6) {
            // Three columns, not one row of five: five cards across truncate their labels on a phone.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(items, id: \.1) { ic, label, run in
                    VStack(spacing: 1) {
                        HStack(spacing: 3) {
                            Text(ic).font(.system(size: 13))
                            Text(label).font(.system(size: 11, weight: .semibold))
                        }
                        .lineLimit(1).minimumScaleFactor(0.7)
                        Text("\(run.current)").font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.gold)
                        Text("day streak").font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                        Text("\(run.total) total").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        Text("best \(run.best)").font(.system(size: 10)).foregroundStyle(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(label): current streak \(run.current) days, \(run.total) days total, best \(run.best) days")
                }
            }
            Text("A streak counts consecutive days holding that medal. Flawless = 🥉🥈🥇 all three earned in a single run of that day's deal. Same-day = the deal cleared on its own date — replaying a past day never earns it.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
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
                    // Ungrouped, through DealFormat.seed: `Text("Deal #\(c.seed)")` interpolates into a
                    // LocalizedStringKey, which GROUPS the digits, so this card said "Deal #691,039"
                    // while the board pill and every Wins surface said "691039" for the same deal
                    // (bug/WF-13:daily-card-seed-grouped).
                    Text("Deal #" + DealFormat.seed(c.seed)).font(.system(size: 13)).foregroundStyle(.secondary).monospacedDigit()
                }
                VStack(spacing: 8) {
                    tierRow("Bronze", "bronze", "Clear the deal", rec, future: dayView > ti)
                    tierRow("Silver", "silver", c.silver.label, rec, future: dayView > ti)
                    tierRow("Gold", "gold", c.gold.label, rec, future: dayView > ti)
                }
                // What the day has cost so far — the banked best against the solver's par, and the
                // moves of every clear behind it.
                clearsLine(rec, par: c.par)
                // ⏰ is earned by clearing the day on its own date — said plainly where the player
                // decides to play, so a past-day replay can't silently fail to earn it.
                onTimeLine(rec: rec, day: dayView, ti: ti)
                playButton(day: dayView, ti: ti, rec: rec)
                // "Show me how to win": one line per tier — Bronze clears the deal; Silver/Gold obey
                // that day's objective. Demonstrations (assisted) — never count toward tiers.
                if dayView <= ti, game.hasSolution(c.seed) {
                    Text("Show me how to win:")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    // Two columns: with Flawless there are up to four pills, and one row of four
                    // truncates their labels on a narrow phone.
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                              spacing: 6) {
                        showPill(c.seed, "bronze", "🥉 Clear", "Clear the deal")
                        if game.hasSilverLine(c.seed) { showPill(c.seed, "silver", "🥈 Silver", c.silver.label) }
                        if game.hasGoldLine(c.seed) { showPill(c.seed, "gold", "🥇 Gold", c.gold.label) }
                        if game.hasFlawlessLine(c.seed) {
                            showPill(c.seed, "flawless", "🌟 Flawless", "🥉🥈🥇 all three in a single run")
                        }
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
        // Red means "you attempted this day and missed the tier". A day with NO record has never
        // been cleared, so it gets the same neutral marker a future day gets — a fresh install used
        // to open on three red circles, reading as "you already failed today"
        // (ux/WF-5:unattempted-objective-shows-red). `rec != nil` is exactly "a won attempt was
        // recorded": dailyStore.record() only runs at a win, and every win banks Bronze.
        let attempted = rec != nil
        let color: Color = done ? .green : (future || !attempted ? .secondary : Theme.red)
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

    /// "Cleared 3× · fewest 96 moves · fastest 5:41 · par 72" — the day's banked bests, put next
    /// to the solver's par so the move count means something. The minima are INDEPENDENT — 80
    /// moves in one run and 5:00 in another must never fuse into "best 80 moves in 5:00", a run
    /// that never happened (skeptical-review R11) — and the count caps honestly: the run log
    /// keeps `runLogMax` deduplicated entries, so a fuller log reads "20+×", not a fake total.
    /// Built as a plain String on purpose: `Text("... \(m) moves")` interpolates through
    /// LocalizedStringKey and would GROUP the digits, the same trap the deal number fell into
    /// (bug/WF-13:daily-card-seed-grouped).
    private func clearsSummary(_ r: TierResult, par: Int) -> String {
        let count = r.runs.count >= runLogMax ? "\(runLogMax)+" : "\(r.runs.count)"
        var parts = [r.runs.count > 1 ? "Cleared \(count)×" : "Cleared"]
        if let m = r.moves { parts.append("fewest \(m) moves") }
        if let e = r.elapsed { parts.append("fastest " + DealFormat.time(e)) }
        parts.append("par \(par)")
        return parts.joined(separator: " · ")
    }

    /// The per-day clear log. Only a WIN writes a record (dailyStore.record() runs at the win), so
    /// `rec != nil && bronze` is exactly "this day has been solved". A record banked before the run
    /// log existed decodes with `runs == []` and simply shows its best — never a "Cleared 0×".
    @ViewBuilder private func clearsLine(_ rec: TierResult?, par: Int) -> some View {
        if let r = rec, r.bronze {
            VStack(alignment: .leading, spacing: 2) {
                Text(clearsSummary(r, par: par))
                    .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                if r.runs.count > 1 {
                    Text("Moves each run: " + r.runs.map { String($0.moves) }.joined(separator: " · "))
                        .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)   // wrap a long history, never truncate
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("daily.clears")
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
            let daySuffix = day == ti ? "" : " \(dayLabel(day))"
            Button {
                if hasLiveGame {
                    pending = .play(day: day)
                } else {
                    game.playChallenge(day)
                    dismiss()
                }
            } label: {
                // Name the day ON the button: when the sheet is scrolled to the calendar, the card
                // header that identifies the selected day is above the fold while this button is
                // still on screen, so a mis-tapped 44x33 pt cell would otherwise start the wrong
                // day's deal with nothing on screen to catch it (ux/WF-13:selected-day-invisible-at-play).
                Text(replay ? "Replay\(daySuffix) to improve ↻" : "Play\(daySuffix)")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 10).fill(replay ? Color.gray.opacity(0.18) : Theme.gold))
                    .foregroundStyle(replay ? Theme.ink : Color(hex: 0x3A2B00))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("daily.play")
        }
    }

    /// The ⏰ same-day line on the day card: earned / today's invitation / a live grace / a past-day
    /// explainer. The grace branch matters: a past day whose attempt is still IN PROGRESS and began
    /// on that day is inside isOnTime's window (start day D, win day D+1), so the plain "earned on
    /// the day itself" line would be a lie that talks the player out of a win they can still have.
    /// It says "resume" on purpose — Replay re-stamps the start day to today and really does forfeit
    /// the grace. Web twin: renderDailyCard's `graceLive` in index.html.
    @ViewBuilder private func onTimeLine(rec: TierResult?, day: Int, ti: Int) -> some View {
        let run = streaks(days, todayIndex()).onTime
        let graceLive = game.challengeDay == day && game.challengeStartDay == day && ti == day + 1
        if rec?.onTime == true {
            Text("⏰ Cleared on the day")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if day == ti {
            Text(run.current > 0 ? "⏰ Win today to keep your \(run.current)-day same-day streak"
                                 : "⏰ Win today to start a same-day streak")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if graceLive {
            Text("⏰ Resume your attempt today and it still counts")
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("⏰ Same-day is earned on the day itself")
                .font(.system(size: 12)).foregroundStyle(.secondary.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// A per-tier "show a winning line" button — hands off to the demo (assisted, unscored).
    /// The demo re-deals the board, so with ANY game in progress (daily attempt or casual, moves
    /// made, not yet won) it must CONFIRM before silently throwing it away. Deliberately no
    /// restore-the-attempt-after-the-demo: resuming a demo-touched flow is exactly the
    /// "finish the app's own line" scoring hole the demo teardown exists to close.
    private func showPill(_ seed: Int, _ tier: String, _ title: String, _ label: String) -> some View {
        // `dayView` rides along so leaving the demo can re-bind THAT day's challenge instead of
        // dropping the player on a casual deal of its seed (Game.endDemo,
        // ux/WF-6:demo-exit-drops-challenge-binding).
        let day = dayView
        return Button {
            if hasLiveGame {
                pending = .demo(seed: seed, tier: tier, label: label, day: day)
            } else {
                game.showSolution(seed, tier: tier, label: label, day: day)
                dismiss()
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.gold.opacity(0.20)))
                .foregroundStyle(Theme.ink)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("daily.demo.\(tier)")
    }

    // MARK: stats backup (local export / import)

    private var backupSection: some View {
        VStack(spacing: 8) {
            Text("BACKUP").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
            // The FIRST UIDocumentPicker presentation in a process blocks the main thread for
            // ~1–1.8 s (system cost; recurs each cold launch, and pre-warming it would just move
            // the stall into the Daily sheet's open). So acknowledge the tap immediately — flip
            // the note to "Opening Files…" — and present on a later runloop turn so that frame
            // actually reaches the screen before the freeze.
            HStack(spacing: 10) {
                Button {
                    let backup = StatsBackup.make(daily: game.dailyStore.days, wins: game.winStore.wins)
                    exportDoc = StatsBackupDocument(data: backup.encoded())
                    backupNote = "Opening Files…"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showExporter = true }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("daily.export")
                Button {
                    backupNote = "Opening Files…"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showImporter = true }
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("daily.import")
            }
            .font(.system(size: 14, weight: .semibold))
            .buttonStyle(.bordered)
            .tint(Theme.gold)
            Text(backupNote ?? "Save your streaks & solved deals to a file, or restore them. Importing merges — it never erases progress.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var exportFilename: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return "Causeway-Stats-\(f.string(from: Date()))"
    }

    private func pl(_ n: Int, _ noun: String) -> String { "\(n) \(noun)\(n == 1 ? "" : "s")" }

    /// Merge an imported backup into the live stores (never destructive) and report the result.
    /// (Cancel is handled by the importer's onCancellation, so a nil/empty selection here is a
    /// genuine failure, not a user cancel.)
    private func importStats(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { backupNote = "Import failed."; return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let backup = StatsBackup.decode(data) else {
            backupNote = "That file isn't a Causeway stats backup."
            return
        }
        // Sanitize before merging so a hand-edited or corrupt file can't inject phantom days/deals or
        // poison a best score: keep only keys THIS APP CAN LEGITIMATELY PRODUCE, and drop
        // non-positive moves/times.
        //
        // The bounds must be the app's real output range, not a convenient subset — a too-narrow
        // pair silently ate the app's OWN untouched export once already (bug/WF-11). So:
        //   days  → 0 ... max(today, pool.count) + 2 : every index dailyChallenge() can resolve,
        //           plus a small grace for clock skew. (A backup taken later in the month restores
        //           onto a device whose clock says earlier, so bound by the POOL, not just today.)
        //   wins  → 1 ... Game.maxSeed               : every seed the app can deal.
        // Anything outside those is a hand-edited/corrupt key and is still dropped.
        //
        // FIRST, though: a `daily` map is only meaningful against the challenge calendar it was
        // earned on. Day indices name a pool entry, and the Aug-30 recut re-picked every day, so a
        // pre-recut record for "day 12" credits a different deal's Gold. DailyStore.load() already
        // drops a pre-v3 LOCAL store for exactly that reason — this import path was the last door
        // left open, and a legacy file walked through it with zero entries skipped, fabricating a
        // 10-day Gold streak (bug/WF-11:legacy-backup-defeats-daily-v3-wipe). Exports now stamp
        // their generation; a file that cannot prove it (any pre-stamp export, including ones this
        // app itself wrote) takes the degraded path below — deals in, days out, reason stated.
        let poolMatches = backup.dailyRecordsMatchThisPool
        let dayMax = max(todayIndex(), DailyData.pool.count) + 2
        let dayMin = 0
        let validDaily = !poolMatches ? [:] : backup.dailyInts
            .filter { (dayMin...dayMax).contains($0.key) }
            .mapValues { r in
                // `runs` rides along: it is the per-day clear log, and the backup file carries it
                // (TierResult is Codable). Dropping it here would make the feature's primary use
                // case — restoring onto a new device — silently return every solved day with an
                // empty history, since DailyStore.merge folds through mergeRuns(local, imported).
                // Same sanitising rule as moves/elapsed: a run with a non-positive count or time is
                // not something this app can have written, so it is dropped rather than displayed.
                TierResult(bronze: r.bronze, silver: r.silver, gold: r.gold, flawless: r.flawless,
                           onTime: r.onTime,
                           moves: (r.moves ?? 0) > 0 ? r.moves : nil,
                           elapsed: (r.elapsed ?? 0) > 0 ? r.elapsed : nil,
                           runs: Array(r.runs.filter { $0.moves > 0 && $0.elapsed > 0 }.suffix(runLogMax)))
            }
        let validWins = backup.winsInts.filter {
            (1...Game.maxSeed).contains($0.key) && $0.value.moves > 0 && $0.value.secs > 0
        }
        let addedDays = game.dailyStore.merge(validDaily)
        let addedDeals = game.winStore.merge(validWins)
        // Report the two kinds separately: "Skipped 2 invalid entries" told the player nothing
        // about WHAT was dropped, which is the whole question when a restore loses progress.
        let skippedDays = poolMatches ? backup.daily.count - validDaily.count : 0
        let skippedDeals = backup.wins.count - validWins.count
        var note = "Imported — merged \(pl(validDaily.count, "day")) (\(addedDays) new) and \(pl(validWins.count, "deal")) (\(addedDeals) new)."
        if skippedDays + skippedDeals > 0 {
            let parts = [skippedDays > 0 ? pl(skippedDays, "day") : nil,
                         skippedDeals > 0 ? pl(skippedDeals, "deal") : nil].compactMap { $0 }
            note += " Skipped \(parts.joined(separator: " and ")) this app can't have produced."
        }
        // The older-calendar case gets its OWN sentence: those days weren't malformed, they were
        // earned on a calendar where each date held a different deal, so crediting them would be
        // crediting challenges that were never played. Deal numbers are pool-independent and come
        // across regardless.
        if !poolMatches && !backup.daily.isEmpty {
            note += " Skipped \(pl(backup.daily.count, "day")) of challenge history from an older"
                  + " challenge calendar — those dates hold different deals now. Your solved deals"
                  + " came across."
        }
        backupNote = note
    }

    // MARK: month calendar

    private var calendar: some View {
        // The month drawn is `calMonth`, NOT today's month — see monthStep.
        let shown = calMonth == 0 ? monthNo(of: clampedToday) : calMonth
        let y = shown / 12, m = shown % 12 + 1
        let range = calMonthRange
        let ti = todayIndex()
        let first = floorMod(floorMod(daysFromCivil(y, m, 1), 7) + 4, 7)   // 0 = Sunday (matches web; floor-mod matches JS %)
        let dim = daysInMonth(y, m)
        return VStack(spacing: 8) {
            // The month title and its arrows own the first row; the legend gets its own line below.
            // They shared a row until the arrows arrived, at which point the legend lost ~68 pt and
            // truncated "⏰ Same-day" to "Sam…" — the one marker the legend exists to name.
            HStack(spacing: 2) {
                monthArrow("chevron.left", "Previous month", by: -1, enabled: shown > range.lowerBound)
                Text(monthLabel(y, m)).font(.system(size: 14, weight: .semibold))
                    .accessibilityIdentifier("daily.cal.month")
                monthArrow("chevron.right", "Next month", by: 1, enabled: shown < range.upperBound)
                Spacer()
            }
            HStack {
                // Five marker types are drawn in the grid; the legend used to name four. The ⏰
                // corner pip — a bare 5 pt gold dot — was the unnamed one, and it is drawn in the
                // same colour and size as the gold TIER dot, so it had to be shown AS a dot here
                // rather than as the ⏰ glyph alone (ux/WF-14:calendar-pip-unlabelled).
                HStack(spacing: 8) {
                    ForEach(["bronze", "silver", "gold"], id: \.self) { t in Text(medal[t] ?? "") }
                    Text("🌟 Flawless")
                    HStack(spacing: 3) {
                        Circle().fill(Theme.gold).frame(width: 5, height: 5)
                        Text("⏰ Same-day")
                    }
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
            }
            LazyVGrid(columns: calCols, spacing: 4) {
                // All three ForEach blocks below are siblings inside ONE LazyVGrid, so their ids share
                // an identity space and MUST be disjoint. Two bugs have come from getting this wrong:
                //   1. \.self on the weekday letters — "T"/"S" duplicate Tue/Sun, collapsing two
                //      header columns to blank.
                //   2. the fix for (1) used \.offset (0...6), which then collided with the day cells'
                //      ids (1...31) and silently blanked days 1-6 of EVERY month.
                // Prefixed string ids keep the three spaces provably distinct.
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { i, d in
                    Text(d).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .id("hdr-\(i)")
                }
                // Data-driven ForEach (not the constant-range ForEach(0..<Int)) so a month rollover
                // that changes `first` re-diffs cleanly.
                ForEach(Array(0..<first).map { "pad-\($0)" }, id: \.self) { _ in Color.clear.frame(height: 40) }
                ForEach(Array(1...dim).map { "day-\($0)" }, id: \.self) { key in
                    let d = Int(key.dropFirst(4)) ?? 1
                    calCell(idx: dayIndexFor(y, m, d), day: d, ti: ti)
                }
            }
            // The answer to a tap on an unavailable cell, said next to the calendar rather than on
            // the day card (which an unavailable day can never open).
            if let locked = lockedDay {
                Text(lockedNote(locked, ti: ti))
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("daily.lockednote")
            }
        }
    }

    /// Why an unavailable calendar cell can't be opened: not yet its date, or outside the seeded
    /// calendar entirely.
    private func lockedNote(_ idx: Int, ti: Int) -> String {
        idx > ti && dailyChallenge(idx, pool) != nil
            ? "🔒 \(dayLabel(idx)) unlocks on the day itself — come back then."
            : "No challenge on \(dayLabel(idx))."
    }

    private func calCell(idx: Int, day: Int, ti: Int) -> some View {
        let rec = days[idx]
        let avail = idx >= 0 && idx <= ti && dailyChallenge(idx, pool) != nil   // only the seeded month
        // A seeded day that simply hasn't arrived yet — distinct from "no challenge here at all",
        // and the only one worth a lock glyph (ux/WF-13:future-day-tap-no-feedback).
        let locked = idx > ti && dailyChallenge(idx, pool) != nil
        let dots = ["bronze", "silver", "gold"].filter { rec?[$0] == true }
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(idx == dayView ? Theme.gold.opacity(0.28)
                                     : Color.gray.opacity(avail ? 0.12 : (idx == lockedDay ? 0.14 : 0.04)))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(idx == ti ? Theme.gold
                                            : (idx == lockedDay ? Color.secondary.opacity(0.5) : .clear),
                                  lineWidth: 1.5))
            // ⏰ earned on the day itself: a corner pip, clear of the today ring and the tier dots.
            if rec?.onTime == true {
                Circle().fill(Theme.gold).frame(width: 5, height: 5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(3)
            }
            VStack(spacing: 2) {
                Text("\(day)").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(avail ? Color.primary : Color.secondary.opacity(0.5))
                // A flawless day shows a ⭐ in the marker slot (flawless implies all three tiers), so
                // it never overlaps the date; other days show the earned-tier dots.
                if rec?.flawless == true {
                    Text("🌟").font(.system(size: 11)).frame(height: 6)   // same reserved height as the dots row → no date jitter
                } else if locked {
                    // A standing affordance, so "not yet" is legible without tapping at all.
                    Text("🔒").font(.system(size: 8)).frame(height: 6).opacity(0.55)
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
        .onTapGesture {
            // An unavailable cell now ANSWERS the tap instead of swallowing it.
            if avail { dayView = idx; lockedDay = nil } else { lockedDay = idx }
        }
        // The label below is only reachable if the ZStack IS an accessibility element: without
        // `.combine` the cell exposes its children instead, so VoiceOver announced every day as a
        // bare number — no month, no earned tiers, no lock state — and no query could ever find the
        // cell by its label (tests/RegressionDailyCalendarTests.swift:cell-locator-never-matched).
        // The cell is tappable, so it also announces AS a button.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(locked ? "\(dayLabel(idx)), locked until that date" : dayLabel(idx))
        // The STABLE per-day locator the UI tests scroll toward. Labels shift with lock state and
        // wording; the identifier never does (skeptical-review R10; filed since round 2 as
        // bug/DailyView:calendar-cells-have-no-identifier).
        .accessibilityIdentifier("daily.cal.\(idx)")
    }

    private func dotColor(_ tier: String) -> Color {
        switch tier {
        case "bronze": return Color(hex: 0xC98B3A)
        case "silver": return Color(hex: 0x9AA0A6)
        default:       return Color(hex: 0xD9AD55)
        }
    }

    // MARK: month navigation

    /// year*12 + (month-1) for a day index — the grid's month key.
    private func monthNo(of idx: Int) -> Int {
        let c = civilOf(idx)
        return c.year * 12 + (c.month - 1)
    }

    /// The months the calendar may show: exactly those the seeded pool spans. Navigating outside
    /// them would only ever draw a grid of dead cells.
    private var calMonthRange: ClosedRange<Int> {
        let last = max(0, pool.count - 1)
        return monthNo(of: 0)...max(monthNo(of: 0), monthNo(of: last))
    }

    /// Step the grid a month at a time, clamped to the pool. `dayView` is left alone: which day the
    /// card shows and which month the grid draws are independent, exactly as tapping a cell in a
    /// past month leaves the grid where it is.
    private func monthArrow(_ icon: String, _ label: String, by delta: Int, enabled: Bool) -> some View {
        Button {
            let r = calMonthRange
            calMonth = min(r.upperBound, max(r.lowerBound, (calMonth == 0 ? monthNo(of: clampedToday) : calMonth) + delta))
            lockedDay = nil
        } label: {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .frame(width: 34, height: 32)          // a real tap target, not a 13pt glyph
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 0.75 : 0.22)
        .accessibilityLabel(label)
        .accessibilityIdentifier(delta < 0 ? "daily.cal.prev" : "daily.cal.next")
    }

    // MARK: date helpers

    private func daysInMonth(_ y: Int, _ m: Int) -> Int {
        let nm = m == 12 ? 1 : m + 1, ny = m == 12 ? y + 1 : y
        return daysFromCivil(ny, nm, 1) - daysFromCivil(y, m, 1)
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
        case "onTime": return onTime
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
            // A player chasing Silver/Gold must be able to READ Silver/Gold while playing:
            // try the compact one-line row first (it fits in landscape), and when it can't fit
            // untruncated — portrait's ~402pt one-lined all three chips and cut Silver/Gold to
            // "Win in 103 moves or…" — stack the chips with fully wrapped labels instead.
            // (The web HUD wraps via flex-wrap for the same reason.)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { chips(c, t, oneLine: true) }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                VStack(alignment: .leading, spacing: 3) { chips(c, t, oneLine: false) }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.55)))
            }
        }
    }

    @ViewBuilder private func chips(_ c: Challenge, _ t: Attempt, oneLine: Bool) -> some View {
        // Name the day when it isn't today's: a catch-up day played from the calendar put its
        // objectives on the board with nothing anywhere saying WHICH day they belong to, so the
        // Daily sheet's "Today" card (a different deal, with its own medals) read as the state of
        // the challenge in progress (ux/WF-5:board-hud-omits-challenge-day).
        if c.dayIndex != todayIndex() {
            Text(dayLabel(c.dayIndex))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.gold)
                .lineLimit(1).fixedSize()
                .accessibilityIdentifier("hud.day")
        }
        objChip("🥉", "Clear the deal", state: t.won ? .ok : .live, oneLine: oneLine)
        objChip("🥈", c.silver.label, state: liveState(c.silver, t), oneLine: oneLine)
        objChip("🥇", c.gold.label, state: liveState(c.gold, t), oneLine: oneLine)
    }

    private enum ObjState { case ok, no, live }
    private func liveState(_ obj: Objective, _ t: Attempt) -> ObjState {
        if t.won { return evaluate(obj, Attempt(won: true, moves: t.moves, elapsed: t.elapsed,
                                                cellUses: t.cellUses, undos: t.undos,
                                                foundationOrder: t.foundationOrder,
                                                maxRunMoved: t.maxRunMoved)) ? .ok : .no }
        if objViolated(obj, t) { return .no }
        // On track: green ✓ as soon as the tier is locked in (guaranteed just by clearing the deal).
        return objSecured(obj, t, up: game.up, down: game.down) ? .ok : .live
    }
    private func objChip(_ medal: String, _ label: String, state: ObjState, oneLine: Bool) -> some View {
        let mark = state == .ok ? "✓" : (state == .no ? "✗" : "·")
        let color: Color = state == .ok ? .green : (state == .no ? Color(hex: 0xE8927C) : .white)
        return HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("\(medal)\(mark)").font(.system(size: 11, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(.white)
                .lineLimit(oneLine ? 1 : nil)
                .fixedSize(horizontal: false, vertical: true)   // wrap, never truncate, when stacked
        }
    }
}

/// Carries the stats-backup JSON as a `.json` file for `.fileExporter` / `.fileImporter`.
struct StatsBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
