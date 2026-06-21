import SwiftUI

/// Wins screen: compressed ranges of solved deals, tap a range to drill into the
/// individual deals with stats, tap a deal to replay it.
struct WinsView: View {
    @ObservedObject var game: Game
    @Environment(\.dismiss) private var dismiss

    private var store: WinStore { game.winStore }
    private let cols = [GridItem(.adaptive(minimum: 78), spacing: 8)]

    var body: some View {
        NavigationStack {
            Group {
                if store.count == 0 {
                    ContentUnavailableView("No wins yet", systemImage: "trophy",
                                           description: Text("Go solve a deal!"))
                } else {
                    ScrollView {
                        let ranges = store.ranges()
                        Text("\(store.count) deals solved · \(ranges.count) ranges")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(.top, 4)
                        LazyVGrid(columns: cols, spacing: 8) {
                            ForEach(ranges, id: \.lowerBound) { r in
                                NavigationLink {
                                    rangeDetail(r)
                                } label: {
                                    Text(DealFormat.rangeLabel(r))
                                        .font(.system(size: 14, weight: .semibold))
                                        .monospacedDigit()
                                        .padding(.vertical, 8).frame(maxWidth: .infinity)
                                        .background(RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.gray.opacity(0.15)))
                                        .overlay(RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(currentInRange(r) ? Theme.gold : .clear, lineWidth: 2))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Deals won")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
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
