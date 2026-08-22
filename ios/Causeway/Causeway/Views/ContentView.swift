import SwiftUI

/// A card/run being dragged: its source and how far the finger has moved (board coords).
private struct DragInfo: Equatable {
    var source: Spot
    var translation: CGSize
}

/// A drop target's live frame in the board coordinate space, collected via preferences.
private struct DropZoneFrame: Equatable {
    var target: DropTarget
    var rect: CGRect
}
/// Measured height of the landscape rail's pill stack, so the rail can tell when it is taller
/// than its viewport and show a "there is more below" cue (ux/WF-12:rail-hides-howtoplay).
private struct RailContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
private struct DropZonesKey: PreferenceKey {
    static var defaultValue: [DropZoneFrame] = []
    static func reduce(value: inout [DropZoneFrame], nextValue: () -> [DropZoneFrame]) {
        value.append(contentsOf: nextValue())
    }
}

/// A brief horizontal wiggle — the "this card can't move" refusal cue. `shakes` is a monotone
/// counter shared by all cards; animating it +1 sweeps sin through 3π and lands back at zero
/// translation (sin(k·3π) = 0 for every integer k), so cards always rest exactly on their fan
/// position. `amplitude` (not animatable) gates the cue to the one touched card — everyone else
/// runs the same sweep at amplitude 0, which keeps each card's animatable value continuous and
/// avoids a newly-touched card animating through the counter's full accumulated history.
private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var amplitude: CGFloat
    var animatableData: CGFloat { get { shakes } set { shakes = newValue } }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amplitude * sin(shakes * .pi * 3), y: 0))
    }
}

struct ContentView: View {
    @StateObject private var game = Game()
    @Namespace private var ns
    @Environment(\.scenePhase) private var scenePhase

    @State private var showWins = false
    @State private var showDeal = false
    @State private var showRules = false
    @State private var showDaily = false
    @State private var dealText = ""

    // Manual drag-and-drop (see cardGesture): source+offset while dragging, and the live
    // frames of every drop target in the "board" coordinate space for hit-testing on drop.
    @State private var drag: DragInfo?
    @State private var dropZones: [DropZoneFrame] = []
    // Portrait board-shrink latch: the tallest column count that has been *seen* this deal.
    // portraitFitCardW sizes the shared board card width from max(live, latched), so within a
    // deal the card size is monotone — a column crossing the threshold shrinks the board once
    // per new maximum, and a later move/undo that shortens the column can't grow it back (which
    // would make the whole board pulse and re-flow on single-card moves). Reset on every deal
    // boundary (game.dealGeneration) and on a full undo back to move 0. Landscape ignores it:
    // its cardW already re-sizes live.
    @State private var shrinkLatchCount = 0
    // Portrait board-height latch — the same monotone-within-a-deal contract as
    // shrinkLatchCount, in the other direction: the SMALLEST portrait board height seen this
    // deal. The height feeding portraitFitCardW is card-size-independent but NOT constant:
    // the toolbar's FlowLayout can gain/drop a whole row when the Finish pill appears
    // mid-deal, and the demo bar's wrapping headline changes per step — unlatched, that
    // wobble would rescale a shrunk board up AND down (exactly the pulse shrinkLatchCount
    // exists to prevent, arriving through the height input). Holding the minimum keeps the
    // shrink monotone. Reset alongside shrinkLatchCount on every deal boundary
    // (game.dealGeneration — moveCount alone misses deal→deal hops where it never left 0) so a
    // HUD/demo bar arriving or leaving with a NEW deal re-latches at that deal's correct
    // height, and additionally whenever the CONTAINER size changes (rotation, any window
    // resize): the latch is only meaningful for the geometry it was measured in, and the
    // chrome wobble it guards against (Finish pill row, demo headline wrap) never changes the
    // root size, so this reset can't reintroduce the pulse.
    @State private var latchedBoardH: CGFloat = 0
    // Refusal cue for touching a card that cannot move (not a run head): which spot is
    // shaking and a monotone trigger the ShakeEffect animates on. Deliberately NOT fired for
    // movable cards whose smart-move finds no target — tap is the primary control and cueing
    // every fruitless tap would be noise; the cue answers only "did the app register my touch
    // on this un-liftable card?".
    @State private var shakeSpot: Spot?
    @State private var shakeTrigger: CGFloat = 0
    /// Height of the landscape rail's pill stack — see landscapeRail.
    @State private var railContentH: CGFloat = 0
    private let tapSlop: CGFloat = 8   // finger travel under this = a tap, not a drag

    /// The typed deal number, or nil when the field is empty / not a number / outside the range
    /// the engine can actually deal. Gates the alert's `Play`.
    ///
    /// Previously this was a bare `if let n = Int(dealText) { game.deal(seed: n) }` against a field
    /// advertising "1–1,000,000": `Game.deal` silently clamped 5,000,000,000 to 4,294,967,295 and
    /// dealt a DIFFERENT board from the one typed, with no message (bug/WF-7). The bound is
    /// `maxValidSeed`, NOT `maxSeed`: `maxSeed` is only the random-deal ceiling, and the
    /// daily/sandbox pools legitimately deal seeds far above it — clamping the entry there would
    /// make a won sandbox deal (e.g. #872,465,152, which the Wins list shows) untypeable.
    private var enteredSeed: Int? {
        guard let n = Int(dealText.trimmingCharacters(in: .whitespaces)),
              n >= 1, n <= Game.maxValidSeed else { return nil }
        return n
    }

    private let outerPad: CGFloat = 6
    private let gap: CGFloat = 4
    private let landscapeRailW: CGFloat = 118   // fixed width of the landscape left button rail

    var body: some View {
        GeometryReader { geo in
            // Landscape stacks the controls in a narrow LEFT rail, then foundations (2 rows) with the
            // free cells directly beneath them, then the tableau filling the rest of the width — three
            // side-by-side columns. Moving the toolbar off the top (into the rail) and the free cells
            // under the foundations (12-across, not 15) frees vertical + horizontal room so the cards
            // grow. The rail and foundations run PARALLEL to the tableau (each owns the full height
            // independently), which is what makes it fit iPhone landscape's short height. Portrait keeps
            // its exact, well-tested stacked layout. The tableau/foundations never scroll (a ScrollView
            // would fight the cards' minimumDistance:0 drag); the rail DOES scroll (it holds no cards).
            let landscape = geo.size.width > geo.size.height
            let portraitCardW = floor((geo.size.width - outerPad * 2 - gap * 7) / 8)
            let landscapeFan: CGFloat = 0.34   // roomier tableau fan now the tableau owns the height
            // Height available to the landscape board (rail · foundations · tableau) once the slim
            // header and any HUD/demo bar are removed. Bounds the rail's ScrollView so no control ever
            // clips off the bottom (which it would on short/notched phones and whenever the HUD shows).
            let landscapeHudBar: CGFloat = landscape && (game.challengeDay != nil || game.demoing || game.demoDoneMessage != nil) ? 50 : 0
            // Chrome above the board = topPad 6 + header (~40) + two 12pt VStack gaps ≈ 70; use 72 so
            // the rail's bounded viewport stays clear of the home-indicator zone on short phones.
            let landscapeBoardH = max(150, geo.size.height - 72 - (landscapeHudBar > 0 ? landscapeHudBar + 12 : 0))
            let cardW: CGFloat = {
                guard landscape else { return portraitCardW }
                // Size for the CURRENT tallest column (min 8 so a fresh 7-card deal nearly fills the
                // height and the cards are big); if play grows a column past that, cards shrink to keep
                // it on-screen rather than clipping.
                let reserve = max(8, game.tableau.map(\.count).max() ?? 7)
                let units = 1 + landscapeFan * CGFloat(reserve - 1)          // tallest tableau column, card-heights
                let heightCardW = floor(landscapeBoardH / (Theme.cardAspect * units))
                // Width: left rail + 4 foundation columns + 8 tableau columns (= 12 card-widths).
                let widthCardW = floor((geo.size.width - outerPad * 2 - landscapeRailW - gap * 13 - 20) / 12)
                return max(30, min(widthCardW, heightCardW))
            }()
            let overlapFactor: CGFloat = landscape ? landscapeFan : 0.40
            let overlap = (cardW * Theme.cardAspect * overlapFactor).rounded()

            ZStack {
                SummerBackground().equatable()   // never changes; skip re-rasterizing its blur layers

                VStack(alignment: .leading, spacing: 12) {
                    header
                    if !landscape { toolbar }   // landscape moves the controls into the left rail
                    if game.demoing || game.demoDoneMessage != nil {
                        demoBar                // "Show me how to win" status + Stop/Done
                    } else if game.challengeDay != nil {
                        DailyHUD(game: game)   // live objectives while playing a challenge
                    }
                    if landscape {
                        // Three columns: controls rail (left) · foundations + free cells · tableau
                        // (fills the rest, full height). No scroll.
                        HStack(alignment: .top, spacing: 10) {
                            landscapeRail(boardH: landscapeBoardH)
                            foundationsAndCells(cardW: cardW)
                                .zIndex(dragInUpper ? 10 : 0)          // a dragged free-cell card floats over the tableau
                            tableauArea(cardW: cardW, overlap: overlap, maxH: landscapeBoardH)
                                .zIndex(dragColumn != nil ? 10 : 1)   // a dragged run floats over the side columns
                        }
                        Spacer(minLength: 0)
                    } else {
                        // Portrait: the upper row and the tableau SHARE one card size — when a long
                        // column forces a shrink, foundations, free cells and tableau all rescale
                        // together (a split-size board reads wrong and makes matchedGeometryEffect
                        // flights jump sizes mid-flight). This outer GeometryReader spans exactly
                        // those two areas, and everything above it (header/toolbar/HUD) is
                        // card-size-independent, so portraitFitCardW is a one-shot pure function of
                        // its height — no measure→resize feedback loop. Card-size-independent is
                        // not constant, though (Finish pill row, demo headline wrap), so the
                        // height is latched to its per-deal minimum — see latchedBoardH.
                        GeometryReader { bg in
                            let liveH = bg.size.height
                            let boardH = latchedBoardH > 0 ? min(liveH, latchedBoardH) : liveH
                            let w = portraitFitCardW(totalH: boardH, widthCardW: cardW,
                                                     tallest: max(game.tableau.map(\.count).max() ?? 0, shrinkLatchCount))
                            let pOverlap = w < cardW ? (overlap * w / cardW).rounded() : overlap
                            VStack(alignment: .leading, spacing: 12) {
                                upperArea(cardW: w)
                                    .zIndex(dragInUpper ? 10 : 0)      // a dragged free-cell card floats over the foundations/tableau
                                // The inner GeometryReader is greedy, so it takes the remaining height
                                // (replacing the old trailing Spacer) and hands the tableau its true
                                // on-screen bound for column()'s exact-fit fan compression.
                                GeometryReader { tg in
                                    tableauArea(cardW: w, overlap: pOverlap, maxH: tg.size.height)
                                        // Shrunk, the tableau is narrower than the full-width upper row:
                                        // centre it. Unshrunk it spans the full width, so .leading keeps
                                        // the exact pre-shrink alignment (no few-pt centring offset).
                                        .frame(maxWidth: .infinity, alignment: w < cardW ? .center : .leading)
                                }
                                .zIndex(dragInUpper ? 0 : 1)           // ...otherwise the tableau floats over the upper row
                            }
                            // Maintain the height latch. `initial: true` covers re-entering
                            // portrait (this GeometryReader leaves the hierarchy in landscape,
                            // so plain onChange would miss the height it comes back with).
                            // Body already uses min(liveH, latch), so a shrink applies the
                            // same frame it happens — this only records it for later frames.
                            .onChange(of: liveH, initial: true) { _, h in
                                guard h > 0 else { return }   // transient zero-size sizing pass
                                latchedBoardH = latchedBoardH > 0 ? min(latchedBoardH, h) : h
                            }
                        }
                    }
                }
                .padding(.horizontal, outerPad)
                .padding(.top, 6)

                if game.won { winOverlay }

                if DebugFlags.memoryHUD {
                    VStack { Spacer(); MemoryHUD().padding(.bottom, 6) }   // TESTING ONLY
                }
            }
            .coordinateSpace(name: "board")
            // The height latch is a function of THIS container size; any size change (rotation —
            // including any interpolated intermediate frames SwiftUI may deliver mid-animation,
            // which the `landscape` test can classify as portrait near-square — or a future
            // resizable-window target) invalidates it. The next portrait liveH re-latches
            // immediately, and the chrome wobble the latch exists for never changes the root
            // size, so unlatching here can't cause pulsing. shrinkLatchCount is
            // size-independent (a card count), so it stays.
            .onChange(of: geo.size) { _, _ in latchedBoardH = 0 }
            .onPreferenceChange(DropZonesKey.self) { dropZones = $0 }
            .foregroundStyle(Theme.ink)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { game.persist() }   // capture latest board + elapsed before eviction
        }
        .onChange(of: game.dealGeneration) { _, _ in
            // New deal (any path — New game, Replay, demo Stop/Done, Daily play, deal alert):
            // both latches belong to the deal that just ended, and its chrome (demo bar, Daily
            // HUD, Finish pill) may not exist on the new one. moveCount can't mark this
            // boundary: a deal→deal hop with no move in between writes 0 over 0 and onChange
            // (value comparison) never fires.
            shrinkLatchCount = 0; latchedBoardH = 0
        }
        .onChange(of: game.moveCount) { _, count in
            // Maintain the portrait shrink latches (every board mutation changes moveCount).
            if count == 0 { shrinkLatchCount = 0; latchedBoardH = 0 }   // full undo to move 0: re-latch both
            else { shrinkLatchCount = max(shrinkLatchCount, game.tableau.map(\.count).max() ?? 0) }
            // Self-heal a drag whose card was torn down mid-gesture by an async autoplay step
            // (its view — and gesture — vanish, so onEnded never fires, leaving `drag` stuck at
            // an elevated zIndex). Only clear when the source no longer holds its card, so an
            // unrelated autoplay never cancels a legitimate in-flight drag (whose source still
            // holds the card until the drop mutates the board).
            if let d = drag, !dragSourceHoldsCard(d.source) { drag = nil }
        }
        .sheet(isPresented: $showWins) { WinsView(game: game) }
        .sheet(isPresented: $showDaily) { DailyView(game: game) }
        .sheet(isPresented: $showRules) { RulesView() }
        // Two actions ONLY (side-by-side row): with three, landscape's auto-raised number pad
        // (~170pt of a 402pt height) pushed Random/Cancel below the visible alert with no scroll
        // hint, leaving destructive "Play" as the only visible exit. A "Random" action here was
        // redundant anyway — the always-visible "New game" pill is the same call.
        .alert("Play a deal", isPresented: $showDeal) {
            TextField(DealFormat.seedRangeHint, text: $dealText).keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Play") {
                if let n = enteredSeed { withAnimation { game.deal(seed: n) } }
            }
            .disabled(enteredSeed == nil)
        } message: { Text("Enter a deal number (\(DealFormat.seedRangeHint)) to play that exact deal.") }
        .alert("Ready to finish", isPresented: $game.promptAutoFinish) {
            Button("Finish") { withAnimation { game.runAutoFinish() } }
            Button("Not yet", role: .cancel) { game.deferAutoFinish() }
        } message: { Text("Every remaining card can go home. Send them all now?") }
    }

    /// Landscape LEFT rail — the toolbar controls as a narrow vertical column of full-width pills,
    /// so the top of the screen is freed for a taller board. Same actions as the portrait `toolbar`.
    /// Scrolls inside `boardH` so the bottom controls stay reachable on short phones / while the HUD
    /// bar is showing (the rail holds no cards, so scrolling can't fight a card drag).
    private func landscapeRail(boardH: CGFloat) -> some View {
        // Does the pill stack overflow the viewport? With the daily HUD (or the demo bar) on screen
        // the viewport drops to ~248 pt against a ~285 pt stack, and the clipped edge landed exactly
        // on a pill boundary: the LAST pill ("How to play") was drawn 0% — no partial pill, no fade,
        // and iOS hides the scroll indicator at rest, so the rules looked simply absent
        // (ux/WF-12:rail-hides-howtoplay). When it overflows, give up 18 pt of the viewport to a
        // persistent chevron cue that sits BELOW the scrolling area, so it can never cover a pill.
        // No feedback loop: the stack's height depends only on the fixed rail width and the pill
        // set, never on the viewport height, so shrinking the viewport cannot change `overflows`.
        let overflows = railContentH > boardH
        let cueH: CGFloat = 18
        return VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {   // indicator flags the rare short-phone/HUD scroll
                VStack(spacing: 6) {
                    // Same "toolbar.*" identifiers as the portrait toolbar: only one of the two
                    // hierarchies exists at a time, so UI tests address either orientation uniformly.
                    railPill("New game", primary: true) { withAnimation { game.newRandomGame() } }
                        .accessibilityIdentifier("toolbar.newgame")
                    railPill("Undo", systemImage: "arrow.uturn.backward") { withAnimation { game.undo() } }
                        .disabled(!game.canUndo).opacity(game.canUndo ? 1 : 0.4)
                        .accessibilityIdentifier("toolbar.undo")
                    railPill("Replay", systemImage: "arrow.clockwise") { withAnimation { game.restartDeal() } }
                        .accessibilityIdentifier("toolbar.replay")
                    railPill(game.autoplayOn ? "Auto-play: On" : "Auto-play: Off") { game.autoplayOn.toggle() }
                        .accessibilityIdentifier("toolbar.autoplay")
                    railPill("Auto-finish: \(game.autoFinishMode.label)") { game.cycleAutoFinishMode() }
                        .accessibilityIdentifier("toolbar.autofinish")
                    if game.canOfferFinish {
                        railPill("Finish", primary: true) { withAnimation { game.runAutoFinish() } }
                            .accessibilityIdentifier("toolbar.finish")
                    }
                    railPill("Deal #\(game.seed)\(game.winStore.isWon(game.seed) ? " ✓" : "")") {
                        dealText = "\(game.seed)"; showDeal = true
                    }
                    .accessibilityIdentifier("toolbar.deal")
                    if !game.pool.isEmpty {
                        railPill("Daily") { showDaily = true }
                            .accessibilityIdentifier("toolbar.daily")
                    }
                    railPill("Wins") { showWins = true }
                        .accessibilityIdentifier("toolbar.wins")
                    railPill("How to play") { showRules = true }
                        .accessibilityIdentifier("toolbar.howtoplay")
                }
                .background(GeometryReader { g in
                    Color.clear.preference(key: RailContentHeightKey.self, value: g.size.height)
                })
            }
            .frame(width: landscapeRailW, height: max(60, boardH - (overflows ? cueH : 0)))
            .onPreferenceChange(RailContentHeightKey.self) { railContentH = $0 }
            if overflows {
                HStack(spacing: 3) {
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    Text("more").font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Color(hex: 0xF4EFE2).opacity(0.9))
                .frame(height: cueH)
                .allowsHitTesting(false)          // purely a cue; the ScrollView above owns the gesture
                .accessibilityHidden(true)        // VoiceOver already reports the rail as scrollable
            }
        }
        .frame(width: landscapeRailW, height: boardH, alignment: .top)
    }
    /// A rail button — like `pill` but filled to the rail width, left-aligned, compact.
    private func railPill(_ title: String, systemImage: String? = nil, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 11, weight: .bold)) }
                Text(title).font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.65)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Capsule().fill(primary ? Theme.gold : Color(hex: 0x2A3B44).opacity(0.46)))
            .foregroundStyle(primary ? Color(hex: 0x3A2B00) : Color(hex: 0xF4EFE2))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
        }
        // NO .buttonStyle(.plain) here — the plain style preserves the explicit near-white label
        // color when the button is DISABLED, which over the faded capsule rendered the disabled
        // Undo as a blank white pill. The default style greys a disabled label (like the portrait
        // toolbar's pill), keeping it legible.
    }
    /// Landscape middle column — foundations (up/down rows) with the free cells directly beneath,
    /// so both sit to the left of the tableau and the tableau owns the remaining width.
    private func foundationsAndCells(cardW: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                groupLabel("FOUNDATIONS · A↑ / K↓")   // see the portrait upperArea note
                foundationRow(dir: .up, cardW: cardW)
                foundationRow(dir: .down, cardW: cardW)
            }
            VStack(alignment: .leading, spacing: 4) {
                groupLabel("FREE CELLS")
                HStack(spacing: gap) {
                    ForEach(0..<Game.cellCount, id: \.self) { i in
                        cellView(i, cardW: cardW)
                            .zIndex(drag?.source == .cell(i) ? 5 : 0)   // dragged cell floats over its neighbours
                    }
                }
            }
        }
    }

    // MARK: header + toolbar

    private var header: some View {
        // While a demo line plays (or its completion banner shows), the board's move count is the
        // APP'S, not the player's — showing it against the stopped clock reads as a perfect
        // zero-second game. Blank both readouts for the demo's duration; Won stays (it's real).
        let demoActive = game.demoing || game.demoDoneMessage != nil
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Causeway").font(.system(size: 22, weight: .bold, design: .serif))
                Text("build each suit from both ends").font(.system(size: 11)).opacity(0.65)
            }
            Spacer()
            stat("Moves", demoActive ? "—" : "\(game.moveCount)", id: "stat.moves")
            if demoActive {
                stat("Time", "—", id: "stat.time")
            } else {
                ClockStat(clock: game.clock)   // observes only the clock, so its 1 Hz tick
            }
            stat("Won", "\(game.winStore.count)", id: "stat.won")   // doesn't re-render the board
        }
    }
    private func stat(_ label: String, _ value: String, id: String) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 12)).opacity(0.8)
            Text(value).font(.system(size: 18, weight: .bold, design: .serif))
                .accessibilityIdentifier(id)   // the VALUE carries the id, so tests read it directly
        }
    }

    private var toolbar: some View {
        FlowLayout(spacing: 8) {
            pill("New game", primary: true) { withAnimation { game.newRandomGame() } }
                .accessibilityIdentifier("toolbar.newgame")
            pill("Undo", systemImage: "arrow.uturn.backward") { withAnimation { game.undo() } }
                .disabled(!game.canUndo).opacity(game.canUndo ? 1 : 0.4)
                .accessibilityIdentifier("toolbar.undo")
            pill("Replay", systemImage: "arrow.clockwise") { withAnimation { game.restartDeal() } }
                .accessibilityIdentifier("toolbar.replay")
            pill(game.autoplayOn ? "Auto-play: On" : "Auto-play: Off") { game.autoplayOn.toggle() }
                .accessibilityIdentifier("toolbar.autoplay")
            pill("Auto-finish: \(game.autoFinishMode.label)") { game.cycleAutoFinishMode() }
                .accessibilityIdentifier("toolbar.autofinish")
            if game.canOfferFinish {
                pill("Finish", primary: true) { withAnimation { game.runAutoFinish() } }
                    .accessibilityIdentifier("toolbar.finish")
            }
            pill("Deal #\(game.seed)\(game.winStore.isWon(game.seed) ? " ✓" : "")") {
                dealText = "\(game.seed)"; showDeal = true
            }
            .accessibilityIdentifier("toolbar.deal")
            if !game.pool.isEmpty {
                pill("Daily") { showDaily = true }
                    .accessibilityIdentifier("toolbar.daily")
            }
            pill("Wins") { showWins = true }
                .accessibilityIdentifier("toolbar.wins")
            pill("How to play") { showRules = true }
                .accessibilityIdentifier("toolbar.howtoplay")
        }
    }
    private func pill(_ title: String, systemImage: String? = nil, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 12, weight: .bold)) }
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Capsule().fill(primary ? Theme.gold : Color(hex: 0x2A3B44).opacity(0.46)))
            .foregroundStyle(primary ? Color(hex: 0x3A2B00) : Color(hex: 0xF4EFE2))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
        }
    }

    // MARK: free cells + foundations

    private func upperArea(cardW: CGFloat) -> some View {
        HStack(alignment: .top) {
            // Foundations on the LEFT, free cells on the RIGHT (matches MobilityWare FreeCell muscle memory).
            VStack(alignment: .leading, spacing: 4) {
                // The two rows are the app's central twist and were the one thing the board never
                // named (ux/WF-1:foundation-rows-unlabelled): top row builds up from A, bottom row
                // down from K, echoed by the A/K corner hint on each empty slot.
                groupLabel("FOUNDATIONS · A↑ / K↓")
                VStack(spacing: gap) {
                    foundationRow(dir: .up, cardW: cardW)
                    foundationRow(dir: .down, cardW: cardW)
                }
            }
            Spacer(minLength: gap)
            VStack(alignment: .trailing, spacing: 4) {
                groupLabel("FREE CELLS")
                HStack(spacing: gap) {
                    ForEach(0..<Game.cellCount, id: \.self) { i in
                        cellView(i, cardW: cardW)
                            .zIndex(drag?.source == .cell(i) ? 5 : 0)   // dragged cell floats over its neighbours
                    }
                }
            }
        }
    }
    private func groupLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 10, weight: .semibold)).tracking(1).opacity(0.6)
            .lineLimit(1).minimumScaleFactor(0.6)   // never wrap/truncate on a narrow board
    }

    // MARK: tap / drag

    private var dragInUpper: Bool { if case .cell = drag?.source { return true } else { return false } }
    private var dragColumn: Int? { if case .tableau(let c, _) = drag?.source { return c } else { return nil } }

    /// Whether the drag's source slot still holds its card. False once an autoplay step has
    /// removed the dragged card out from under the finger — used to self-heal a stuck drag.
    private func dragSourceHoldsCard(_ s: Spot) -> Bool {
        switch s {
        case .cell(let i):            return game.cells[i] != nil
        case .tableau(let c, let i):  return i < game.tableau[c].count
        }
    }

    /// The finger offset to apply to `spot` — non-zero only for the card(s) in the run
    /// currently being dragged (the run head plus everything stacked below it).
    private func runOffset(_ spot: Spot) -> CGSize {
        guard let d = drag else { return .zero }
        switch (d.source, spot) {
        case (.cell(let a), .cell(let b)):
            return a == b ? d.translation : .zero
        case (.tableau(let sc, let si), .tableau(let c, let i)):
            return (sc == c && i >= si) ? d.translation : .zero
        default:
            return .zero
        }
    }

    /// One unified gesture per card: a small finger travel is a tap (smart-move); a larger one
    /// is a drag that drops onto whichever registered drop zone is under the finger on release.
    /// `minimumDistance: 0` means the card follows the finger instantly — no press-and-hold.
    private func cardGesture(for spot: Spot, canDrag: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
            .onChanged { v in
                guard canDrag else { return }
                if drag == nil { drag = DragInfo(source: spot, translation: v.translation) }
                else if drag?.source == spot { drag?.translation = v.translation }
            }
            .onEnded { v in
                // Ignore a second finger's release while another card owns the drag: acting on
                // it would fire a stray smartMove and clear `drag`, snapping the in-flight drag
                // back. Only the owning card (or a fresh tap, drag == nil) may resolve here.
                guard drag == nil || drag?.source == spot else { return }
                if !canDrag, !game.demoing {
                    // The touch landed on a card that cannot move (buried / not a run head):
                    // acknowledge it with a shake so silence never reads as a dropped touch.
                    // Suppressed while demoing (ALL input is locked then, not just this card).
                    shakeSpot = spot
                    withAnimation(.linear(duration: 0.3)) { shakeTrigger += 1 }
                    return
                }
                let travelled = hypot(v.translation.width, v.translation.height)
                withAnimation(.easeOut(duration: 0.18)) {
                    if travelled < tapSlop {
                        game.smartMove(spot)                                   // tap
                    } else if canDrag, let t = dropTarget(at: v.location) {
                        game.drop(spot, to: t)                                 // drop onto target under finger
                    }
                    drag = nil                                                 // else: snaps back
                }
            }
    }

    /// Which drop target a release at `p` resolves to. Tableau columns deliberately overhang each
    /// other by the inter-column gutter (see `column`), so more than one zone can contain the
    /// point; the nearest zone CENTRE wins, on the horizontal axis only — a column's zone runs all
    /// the way down to the tableau bottom, so its midY is meaningless for "which column is this".
    private func dropTarget(at p: CGPoint) -> DropTarget? {
        let hits = dropZones.filter { $0.rect.contains(p) }
        if hits.count <= 1 { return hits.first?.target }
        return hits.min(by: { abs($0.rect.midX - p.x) < abs($1.rect.midX - p.x) })?.target
    }

    /// A transparent probe that reports this view's frame in board coordinates as a drop zone.
    private func dropZone(_ target: DropTarget) -> some View {
        GeometryReader { g in
            Color.clear.preference(key: DropZonesKey.self,
                                   value: [DropZoneFrame(target: target, rect: g.frame(in: .named("board")))])
        }
    }

    private func cellView(_ i: Int, cardW: CGFloat) -> some View {
        Group {
            if let c = game.cells[i] {
                CardView(card: c, width: cardW)
                    .matchedGeometryEffect(id: c.id, in: ns)
                    .offset(runOffset(.cell(i)))
                    .gesture(cardGesture(for: .cell(i), canDrag: !game.demoing))
            } else {
                SlotView(width: cardW)
            }
        }
        .background(dropZone(.cell(i)))
    }

    private func foundationRow(dir: Dir, cardW: CGFloat) -> some View {
        HStack(spacing: gap) {
            ForEach(Suit.allCases, id: \.rawValue) { suit in
                foundationCell(suit: suit, dir: dir, cardW: cardW)
            }
        }
    }
    private func foundationCell(suit: Suit, dir: Dir, cardW: CGFloat) -> some View {
        let s = suit.rawValue
        let rank = dir == .up ? game.up[s] : (game.down[s] < 14 ? game.down[s] : 0)
        return Group {
            if rank >= 1 {
                let card = Card(suit: suit, rank: rank)
                CardView(card: card, width: cardW)
                    .matchedGeometryEffect(id: card.id, in: ns)
            } else {
                SlotView(width: cardW, glyphSuit: suit, startRank: dir == .up ? "A" : "K")
            }
        }
        .background(dropZone(.foundation(suit, dir)))   // drop target only; foundation cards aren't dragged
    }

    // MARK: tableau

    /// A buried card stays readable while its whole rank glyph shows. CardView's rank Text sits at
    /// the 0.05·w top inset, and the glyph hangs from the line box by SF's ascent (~0.955 em of the
    /// 0.50·w font), putting its baseline at ≈ 0.05 + 0.955·0.50 ≈ 0.53·w below the card top (the
    /// cap top is at ~0.17·w, not at the inset — the ascent-to-cap gap pushes it down). Measured on
    /// device at cardW 41: the digit spans y ≈ 7–22 pt = 0.17·w–0.53·w. Fan compression must not
    /// go below this, else the bottom of every buried rank is clipped by the card above.
    private static let legibleOverlapUnit: CGFloat = 0.53

    /// Portrait: ONE card width for the whole board. Width-bound normally; when the tallest
    /// tableau column couldn't fit `totalH` even at the legibility-floor fan, shrink so the
    /// upper row (two card-rows) and that column fit together — the shrink surrenders upper-row
    /// height too, which is exactly what lets the shared size stay as large as possible.
    /// `totalH` spans the upper row + tableau; the card-size-independent vertical chrome inside
    /// it (FOUNDATIONS label ~12 + its 4pt spacing + the 4pt gap between foundation rows + the
    /// 12pt VStack gap above the tableau) is ~32pt. A few points of estimate error are absorbed
    /// by column()'s per-column fan compression, which backstops the exact fit. Landscape never
    /// calls this — its cardW already height-sizes live (fan 0.34·aspect ≈ 0.57·w > the 0.53
    /// floor). The 30pt clamp matches the landscape minimum; the portrait caller passes the
    /// deal-scoped shrinkLatchCount AND a deal-scoped minimum-latched totalH (latchedBoardH),
    /// so BOTH inputs are monotone within a deal (no per-move or per-chrome-row board
    /// pulsing). totalH == 0 is a transient sizing pass: keep width-sized cards for that frame.
    private func portraitFitCardW(totalH: CGFloat, widthCardW: CGFloat, tallest: Int) -> CGFloat {
        guard tallest > 1, totalH > 0 else { return widthCardW }
        // Card-width units: 2 upper card-rows + 1 full card + (n-1) legibility-floor fan steps.
        let units = 3 * Theme.cardAspect + Self.legibleOverlapUnit * CGFloat(tallest - 1)
        let fit = floor((totalH - 32) / units)
        return max(30, min(widthCardW, fit))
    }

    private func tableauArea(cardW: CGFloat, overlap: CGFloat, maxH: CGFloat) -> some View {
        let cardH = cardW * Theme.cardAspect
        return HStack(alignment: .top, spacing: gap) {
            ForEach(0..<Game.colCount, id: \.self) { col in
                column(col, cardW: cardW, cardH: cardH, overlap: overlap, maxH: maxH)
                    .zIndex(dragColumn == col ? 5 : 0)   // the column holding the dragged run floats over its neighbours
            }
        }
    }
    private func column(_ col: Int, cardW: CGFloat, cardH: CGFloat, overlap: CGFloat, maxH: CGFloat) -> some View {
        let cards = game.tableau[col]
        // A long column compresses ITS OWN fan just enough to stay inside `maxH`, so the
        // bottom card can never run off-screen (the tableau deliberately doesn't scroll).
        // Legibility is guaranteed upstream: portraitFitCardW shrinks the whole board's card
        // size before the fit here would ever compress past the readable rank band, so the
        // 8pt floor is a last-resort backstop only (the 30pt card-size clamp binding on a
        // degenerate ~18+-card column on a short phone, or a transient zero-height pass).
        let ov = cards.count > 1
            ? max(8, min(overlap, floor((maxH - cardH) / CGFloat(cards.count - 1))))
            : overlap
        let height = cards.isEmpty ? cardH : CGFloat(cards.count - 1) * ov + cardH
        return ZStack(alignment: .top) {
            if cards.isEmpty {
                SlotView(width: cardW)
            }
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                tableauCard(col: col, idx: idx, card: card, cardW: cardW, overlap: ov)
            }
        }
        .frame(width: cardW, height: height, alignment: .top)
        // The drop frame extends past the cards down to the tableau's bottom (`maxH`): the empty
        // strip below a column belongs to no other target, so a run released a few points below
        // the column's last card should land ON that column, not silently snap back. (The web
        // mirror gives every column the tallest column's hit height for the same reason.)
        //
        // It also overhangs `gap` HORIZONTALLY on each side, so the columns' hit areas TILE instead
        // of leaving the ~5 pt inter-column gutter belonging to nobody: a release there used to be
        // refused by both neighbours even though the dragged card visibly overlapped one of them by
        // ~45% (ux/WF-2:drop-gutter-dead-zone). The overhang makes adjacent zones overlap on
        // purpose; cardGesture resolves an overlap to the nearest column centre, which is exactly
        // "the column the card was mostly over".
        .background(alignment: .top) {
            dropZone(.column(col)).frame(width: cardW + gap * 2, height: max(height, maxH), alignment: .top)
        }
    }

    /// A single tableau card: single tap = smart-move; drag = manual placement. Only cards
    /// heading a valid run can drag (so buried cards don't lift); every card is still tappable.
    private func tableauCard(col: Int, idx: Int, card: Card, cardW: CGFloat, overlap: CGFloat) -> some View {
        CardView(card: card, width: cardW)
            .matchedGeometryEffect(id: card.id, in: ns)
            .offset(y: CGFloat(idx) * overlap)              // fan the pile
            .offset(runOffset(.tableau(col: col, idx: idx))) // + follow the finger while dragging
            // Refusal wiggle when this (unmovable) card was touched; amplitude 0 for the rest.
            .modifier(ShakeEffect(shakes: shakeTrigger,
                                  amplitude: shakeSpot == .tableau(col: col, idx: idx) ? 4 : 0))
            .zIndex(Double(idx))
            .gesture(cardGesture(for: .tableau(col: col, idx: idx),
                                 canDrag: !game.demoing && game.isSeqHead(col: col, idx: idx)))
    }

    // MARK: "Show me how to win" status bar

    private var demoBar: some View {
        HStack(spacing: 8) {
            Text(demoHeadline)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Color(hex: 0xF4EFE2))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("demo.headline")
            Spacer(minLength: 6)
            if game.demoing {
                if game.demoPaused {
                    demoPill("Next") { game.demoStepOnce() }
                        .accessibilityIdentifier("demo.next")
                }
                // "Start" before the first play, "Pause" while playing, "Resume" once paused.
                demoPill(!game.demoPaused ? "Pause" : (game.demoStarted ? "Resume" : "Start")) { game.demoTogglePause() }
                    .accessibilityIdentifier("demo.start")   // one id for Start/Pause/Resume (same control)
            }
            // Both mid-demo "Stop" and post-line "Done" re-deal the seed: a demo-touched board
            // must never become playable (taking over the app's own solution moves and finishing
            // would bank a genuine win/best-time). The player lands on a fresh board of the same
            // deal, which they can still solve legitimately.
            demoPill(game.demoing ? "Stop" : "Done") { withAnimation { game.restartDeal() } }
                .accessibilityIdentifier(game.demoing ? "demo.stop" : "demo.done")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x2A3B44).opacity(0.72)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
    }
    /// The demo bar's status line — Bronze just clears the deal; Silver/Gold name their objective.
    private var demoHeadline: String {
        guard game.demoing else { return game.demoDoneMessage ?? "" }
        let head: String
        switch game.demoTier {
        case "gold":   head = "🥇 Gold: \(game.demoLabel)"
        case "silver": head = "🥈 Silver: \(game.demoLabel)"
        default:       head = "Winning line"
        }
        let suffix = !game.demoPaused ? "…" : (game.demoStarted ? " (paused)" : "")   // initial = no suffix
        // "·", not an em dash: three objective labels ("Split every suit exactly down the middle —
        // A-7 up, 8-K down", no-supermoves, no-up-foundation) embed an em dash of their own, so an
        // em dash separator punctuated the move counter exactly like the second half of the
        // objective and it read as more objective text
        // (ux/WF-13:demo-headline-emdash-collides-with-label).
        return "\(head) · \(game.demoProgress)\(suffix)"
    }
    private func demoPill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: 0x2A3B44).opacity(0.6)))
                .foregroundStyle(Color(hex: 0xF4EFE2))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: win overlay

    /// The daily-challenge line for the win overlay, mirroring the web onWin(): a Flawless callout
    /// when all three tiers fell in this single run, else the medals earned this attempt. nil for
    /// casual (non-challenge) wins.
    private var winDailyText: String? {
        guard let d = game.dailyResult else { return nil }
        if d.flawless { return "🌟 Flawless! 🥉🥈🥇 all in a single run." }
        let earned = [(d.bronze, "🥉"), (d.silver, "🥈"), (d.gold, "🥇")]
            .filter { $0.0 }.map { $0.1 }.joined(separator: " ")
        return "Daily challenge: \(earned.isEmpty ? "—" : earned) earned."
    }

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("You solved it! 🎉").font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.gold)
                Text("Deal #\(game.seed) · \(game.moveCount) moves · \(DealFormat.time(game.clock.elapsed))")
                    .font(.system(size: 14)).multilineTextAlignment(.center).foregroundStyle(.white)
                if let dl = winDailyText {
                    Text(dl).font(.system(size: 14, weight: .semibold))
                        .multilineTextAlignment(.center).foregroundStyle(Theme.gold)
                }
                HStack(spacing: 8) {
                    pill("Play deal #\(game.nextSeed)", primary: true) { withAnimation { game.deal(seed: game.nextSeed) } }
                    pill("Random") { withAnimation { game.newRandomGame() } }
                    pill("Close") { game.dismissWin() }
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x2C3B3A)))
            .padding(28)
        }
    }
}

/// Time readout that observes only the isolated clock, so its per-second update
/// invalidates just this label instead of the whole board.
private struct ClockStat: View {
    @ObservedObject var clock: GameClock
    var body: some View {
        VStack(spacing: 1) {
            Text("Time").font(.system(size: 12)).opacity(0.8)
            Text(DealFormat.time(clock.elapsed)).font(.system(size: 18, weight: .bold, design: .serif))
                .accessibilityIdentifier("stat.time")
        }
    }
}

#Preview { ContentView() }
