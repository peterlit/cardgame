import SwiftUI

/// Wins screen: enter a deal number to play it, plus compressed ranges of solved
/// deals — tap a range to drill into the individual deals with stats and replay.
struct WinsView: View {
    @ObservedObject var game: Game
    /// Board replacement is the SESSION's decision, not this sheet's: the callback lands in
    /// ContentView.requestDealFromDismissal, whose confirmation protects a live attempt. This
    /// sheet used to call game.deal directly — the one route that could silently destroy a live
    /// game and its ⏰ grace (skeptical-review R4).
    let playDeal: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var dealText = ""

    private var store: WinStore { game.winStore }
    private let cols = [GridItem(.adaptive(minimum: 78), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dealEntry

                    if store.count == 0 {
                        Text("No wins yet — go solve one!")
                            .foregroundStyle(.secondary).padding(.top, 24)
                    } else {
                        let ranges = store.ranges()
                        Text("\(store.count) deal\(store.count == 1 ? "" : "s") solved · \(ranges.count) range\(ranges.count == 1 ? "" : "s")")
                            .font(.subheadline).foregroundStyle(.secondary)
                        LazyVGrid(columns: cols, spacing: 8) {
                            ForEach(ranges, id: \.lowerBound) { r in
                                NavigationLink { rangeDetail(r) } label: { rangeChip(r) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Deals won")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    // Enter any deal number and play it.
    private var dealEntry: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Play a deal").font(.headline)
            HStack(spacing: 8) {
                TextField("Number \(DealFormat.seedRangeHint)", text: $dealText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                Button("Play", action: playEntered)
                    .buttonStyle(.borderedProminent)
                    .disabled(enteredSeed == nil)
            }
            // Say WHY Play is dead. The only statement of the legal range is the field's
            // placeholder, which the typed text replaces — so an out-of-range entry left a greyed
            // button, no message, and nothing on screen naming the bound
            // (ux/WF-9:deal-entry-out-of-range-silent). Shown only once something has been typed,
            // so the empty field (Play legitimately disabled, nothing wrong yet) stays quiet.
            if let problem = entryProblem {
                Text(problem)
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.red)
                    .accessibilityIdentifier("wins.dealentry.problem")
            }
        }
    }

    /// Why the typed deal number can't be played (nil = nothing typed, or it's fine).
    private var entryProblem: String? {
        let typed = dealText.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty, enteredSeed == nil else { return nil }
        return "Deal numbers run \(DealFormat.seedRangeHint)."
    }

    /// The typed deal number, or nil when it is empty / not a number / out of range. The field
    /// used to advertise "Number 1–1,000,000" while nothing enforced it
    /// (bug/WinsView:deal-entry-range-not-enforced); the bound is now `Game.maxSeed`, the single
    /// ceiling the whole app shares.
    private var enteredSeed: Int? {
        guard let n = Int(dealText.trimmingCharacters(in: .whitespaces)),
              n >= 1, n <= Game.maxSeed else { return nil }
        return n
    }

    private func playEntered() {
        guard let n = enteredSeed else { return }
        playDeal(n)
        dismiss()
    }

    private func rangeChip(_ r: ClosedRange<Int>) -> some View {
        Text(DealFormat.rangeLabel(r))
            .font(.system(size: 14, weight: .semibold)).monospacedDigit()
            .padding(.vertical, 8).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(currentInRange(r) ? Theme.gold : .clear, lineWidth: 2))
    }

    private func currentInRange(_ r: ClosedRange<Int>) -> Bool { r.contains(game.seed) }

    private func rangeDetail(_ r: ClosedRange<Int>) -> some View {
        let rows = store.records(in: r)
        return List {
            Section {
                ForEach(rows, id: \.seed) { row in
                    Button {
                        playDeal(row.seed)
                        dismiss()
                    } label: {
                        HStack {
                            // Ungrouped, like the range chip / navigation title above it and the
                            // board's Deal # pill. `Text("Deal #\(row.seed)")` interpolates into a
                            // LocalizedStringKey, which GROUPS the digits — so one screen showed the
                            // same deal as "561325499" and "Deal #561,325,499"
                            // (ux/WinsView:seed-format-inconsistent).
                            Text("Deal #" + DealFormat.seed(row.seed)).fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            if row.seed == game.seed {
                                Image(systemName: "play.circle.fill").foregroundStyle(Theme.gold)
                            }
                            Spacer()
                            Text("\(row.rec.moves) moves · \(DealFormat.time(row.rec.secs)) · \(row.rec.date.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                        .contentShape(Rectangle())
                    }
                    // A Button in a List takes the accent tint over its WHOLE label, which dragged
                    // the .secondary stats to 1.42:1 against white and the title to 2.09:1 — the
                    // only content this screen exists to show was unreadable
                    // (bug/WinsView:row-text-contrast). `.plain` restores the system label colours
                    // (primary ≈ 16:1, secondary ≈ 4.6:1); the row stays tappable via contentShape,
                    // the gold "currently playing" marker keeps its explicit tint, and the footer
                    // below states the affordance the tint used to imply.
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("Tap a deal to play it again.")
            }
        }
        .navigationTitle(DealFormat.rangeLabel(r))
        .navigationBarTitleDisplayMode(.inline)
    }
}
