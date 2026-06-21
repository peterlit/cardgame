import SwiftUI

/// Wins screen: enter a deal number to play it, plus compressed ranges of solved
/// deals — tap a range to drill into the individual deals with stats and replay.
struct WinsView: View {
    @ObservedObject var game: Game
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
                        Text("\(store.count) deals solved · \(ranges.count) ranges")
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
                TextField("Number 1–\(Game.maxSeed)", text: $dealText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                Button("Play", action: playEntered)
                    .buttonStyle(.borderedProminent)
                    .disabled(Int(dealText.trimmingCharacters(in: .whitespaces)) == nil)
            }
        }
    }

    private func playEntered() {
        guard let n = Int(dealText.trimmingCharacters(in: .whitespaces)), n >= 1 else { return }
        game.deal(seed: n)   // Game.deal clamps to 1...maxSeed
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
        return List(rows, id: \.seed) { row in
            Button {
                game.deal(seed: row.seed)
                dismiss()
            } label: {
                HStack {
                    Text("Deal #\(row.seed)").fontWeight(.semibold)
                    if row.seed == game.seed {
                        Image(systemName: "play.circle.fill").foregroundStyle(Theme.gold)
                    }
                    Spacer()
                    Text("\(row.rec.moves) moves · \(DealFormat.time(row.rec.secs)) · \(row.rec.date.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .navigationTitle(DealFormat.rangeLabel(r))
        .navigationBarTitleDisplayMode(.inline)
    }
}
