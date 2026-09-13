import SwiftUI

/// How-to-play rules (ported from the web prototype).
struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // The two foundation ROWS are the game's central twist, and nothing used to say
                    // which row was which — an Ace dragged to the down row just snapped back
                    // (ux/WF-1:foundation-rows-unlabelled). The board now hints it with an A/K in
                    // each empty slot; this names it in words.
                    rule("Goal", "Move all 52 cards to the foundations. Each suit has two foundations — an up pile (A, 2, 3 …) and a down pile (K, Q, J …). They build toward each other and meet in the middle; you choose where each suit splits. On the board the TOP foundation row is the up pile and the row beneath it is the down pile: empty slots show a faint A or K to say which card starts there.")
                    rule("The catch", "The up and down halves of a suit can never cross. A 7 or 8 has no home until the ends climb to reach it — plan around it.")
                    rule("Tableau", "Build in alternating colours, one rank at a time, in either direction — a pile can run down (red on black) or up. Pick a direction when you start a pile; you can't reverse it partway. Move a tidy run — cards already stacked by that rule — as a group if you have enough free cells and empty columns.")
                    rule("Free cells", "Three single-card parking spots.")
                    // The old sentence promised "Tap a card to send it to its best spot" with no precondition,
                    // and on a fresh deal most cards are buried — a novice following it read the
                    // resulting silence as a broken tap (ux/WF-10:controls-overpromises-tap). Name the
                    // precondition AND the refusal cue. The precondition is the engine's exactly
                    // (Game.smartMove → isSeqHead): the run below the tapped card must reach the
                    // BOTTOM of its pile — "heads a tidy run" alone let a tap on a tidy pair with
                    // unrelated cards beneath it wiggle against the copy's promise (round 2).
                    rule("Controls", "Tap a card with nothing below it — or one whose tidy run reaches the bottom of its pile — to send it to its best spot: a foundation if it fits, otherwise onto another card, an empty column, or a free cell. The run beneath it moves with it. A card that can't move, or has nowhere to go, just wiggles. To place a card or run somewhere specific, drag it there instead. Everything is face-up — it's pure skill.")
                    // Both automation pills are ON by default and neither was documented anywhere
                    // in the app, so a novice met an unexplained mid-game "Ready to finish" prompt
                    // (ux/WF-10:automation-undocumented).
                    rule("Automation", "Two toolbar pills say what the app does on its own; tap either to cycle it.\n\nAuto-play (On/Off): after each of your moves the app sends home any card that is provably safe to send — one that can never be needed to hold another card. It never makes a choice you could regret. Turn it Off to place every card yourself.\n\nAuto-finish (Ask/Off/On): once every remaining card can go home, the deal is decided. Ask (the default) offers \"Ready to finish\" once — choose \"Not yet\" and it won't ask again this game, and a gold Finish pill stays in the toolbar. Off never asks and leaves the Finish pill to you. On plays the cascade the moment the board is decided. Finishing this way still counts as your win, with the moves and time you already have.")
                    about
                }
                .padding()
            }
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func rule(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline).foregroundStyle(Theme.gold)
            Text(body).font(.subheadline).foregroundStyle(.primary)
        }
    }

    /// About / copyright footer — app name, version, and ownership notice.
    private var about: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().padding(.vertical, 6)
            Text("About").font(.headline).foregroundStyle(Theme.gold)
            Text("Causeway · v\(Self.appVersion)")
                .font(.subheadline).foregroundStyle(.primary)
            Text("© 2026 Whimsical Distractions. All rights reserved.")
                .font(.caption).foregroundStyle(.secondary)
            Text("An original two-ended-foundation solitaire.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// "1.0 (1)" from the bundle's marketing version + build number.
    static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
