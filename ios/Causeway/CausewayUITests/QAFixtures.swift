//
//  QAFixtures.swift
//  CausewayUITests
//
//  Shared launch helper + fixture saves for the qa-loop regression and smoke suites
//  (qa-loop 2026-09-09, round 1). NOT a test class — it holds no XCTestCase.
//
//  HOW STATE IS SEEDED (the launch-argument route, verified 2026-09-09):
//   The app reads its three stores with `UserDefaults.standard.data(forKey:)` —
//   "causeway.game" (Game.restore), "causeway.daily" (DailyStore.load) and "causeway.wins"
//   (WinStore.load) — plus `causeway.autoplay` (bool) and `causeway.autofinishmode` (string).
//   XCUITest can seed the ARGUMENT domain, which outranks the persisted plist for the launched
//   process, and UserDefaults parses every `-key value` pair as an OLD-STYLE property list —
//   in which `<hex bytes>` is NSData. So
//       app.launchArguments += ["-causeway.game", "<7b2273656564...7d>"]
//   reaches `data(forKey:)` byte-for-byte. A raw JSON string does NOT (`data(forKey:)` returns
//   nil for a string value), which is why the brief's "-causeway.game <json>" needs the hex
//   wrapper. `<>` is EMPTY data: the store's JSON decode fails and it starts clean — that is how
//   a test says "no saved game / no wins / no daily history" without touching the plist.
//   Proved with a standalone Swift probe before any test relied on it.
//
//   The argument domain is per-process, so nothing a test seeds leaks into the next launch.
//   The app's OWN writes during a test do land in the persisted plist, though, so every test
//   here pins all three stores (and the two settings) instead of trusting the previous test —
//   the pre-existing suites launch bare and inherit whatever the simulator holds.
//
//  THE CLOCK IS PINNED via launchEnvironment CAUSEWAY_TODAY_OVERRIDE (see
//  RegressionDailyCalendarTests.swift): day 0 = 2026-08-01, so the default 2026-08-15 is day 14,
//  "yesterday" is the seeded Aug 14 (index 13) and Aug 3 / Aug 4 are indices 2 / 3.
//
//  Fixtures were generated with the harness tools in .qa-loop/tools (the app's OWN certified
//  solution lines, truncated at the first position the Finish cascade wins from):

//   - day14Silver: make_save.mjs --day 14 --tier silver --challengeDay 14 --startDay 14 (seed 608530, parked at move 78; Finish -> 97 moves, bronze+silver)
//   - day13Flawless: make_save.mjs --day 13 --tier flawless --challengeDay 13 --startDay 13 (seed 720307, move 71; Finish -> 79 moves, flawless)
//   - day12FlawlessStart14: make_save.mjs --day 12 --tier flawless --challengeDay 12 --startDay 14 (seed 616917, a past-day replay begun Aug 15; Finish -> 103 moves, flawless, never on time)
//   - day2Bronze: make_save.mjs --day 2 --tier bronze --challengeDay 2 --startDay 2 (seed 539885, move 81; Finish -> 96 moves, bronze only)
//   - day29Flawless: make_save.mjs --day 29 --tier flawless --challengeDay 29 --startDay 29 (seed 551879, move 92; Finish -> 96 moves, flawless)
//   - day21FirstWinnable: make_save.mjs with its picker relaxed to `a.won` --day 21 --tier flawless --challengeDay 21 --startDay 29 (seed 944114, move 64/87: the FIRST position the cascade can win from; finish -> 83 moves, gold LOST)
//   - zeroMoveDay13: zero_move_save.mjs --day 13 (seed 720307, Play tapped on Aug 14 and never moved: challengeDay 13 / challengeStartDay 13 / moveCount 0)
//
import XCTest

enum QA {

    /// Mid-pool pinned clock: day index 14 (Aug 15). Aug 14 = index 13 (yesterday), Aug 3 = 2, Aug 4 = 3.
    static let pinnedToday = "2026-08-15"

    // MARK: launch

    /// A launch-ready app with the clock pinned and ALL persisted state controlled.
    ///  - `game`: a SavedGame JSON (see the fixtures below) or nil for "no saved game" (a fresh
    ///    random deal, exactly like a cold install).
    ///  - `daily` / `wins`: store JSON, defaulting to EMPTY stores (a fresh install).
    ///  - `autoplay` / `autofinish`: the two board settings, pinned to the app defaults.
    static func app(today: String = pinnedToday,
                    game: String? = nil,
                    daily: String? = emptyDaily,
                    wins: String? = emptyWins,
                    autoplay: Bool = true,
                    autofinish: String = "ask") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CAUSEWAY_TODAY_OVERRIDE"] = today
        app.launchArguments += ["-causeway.game",  plistData(game)]
        app.launchArguments += ["-causeway.daily", plistData(daily)]
        app.launchArguments += ["-causeway.wins",  plistData(wins)]
        app.launchArguments += ["-causeway.autoplay", autoplay ? "1" : "0"]
        app.launchArguments += ["-causeway.autofinishmode", autofinish]
        return app
    }

    /// `app(...)` + portrait + launched, with the board on screen.
    @discardableResult
    static func launch(today: String = pinnedToday,
                       game: String? = nil,
                       daily: String? = emptyDaily,
                       wins: String? = emptyWins,
                       autoplay: Bool = true,
                       autofinish: String = "ask") -> XCUIApplication {
        let app = QA.app(today: today, game: game, daily: daily, wins: wins,
                         autoplay: autoplay, autofinish: autofinish)
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["toolbar.deal"].waitForExistence(timeout: 10),
                      "the board never appeared (toolbar.deal missing)")
        return app
    }

    /// Old-style plist NSData literal for a UTF-8 string: `<hex...>`; nil -> `<>` (empty data).
    static func plistData(_ json: String?) -> String {
        guard let json else { return "<>" }
        return "<" + json.utf8.map { String(format: "%02x", $0) }.joined() + ">"
    }

    static let emptyDaily = #"{"version":3,"days":{}}"#
    static let emptyWins  = "{}"

    // MARK: shared element helpers

    /// Open the Daily sheet (waits for its navigation title).
    static func openDaily(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["toolbar.daily"].waitForExistence(timeout: 5), "no toolbar.daily pill")
        app.buttons["toolbar.daily"].tap()
        XCTAssertTrue(app.navigationBars["Daily Challenges"].waitForExistence(timeout: 5),
                      "the Daily sheet did not open")
    }

    /// Scroll the (open) Daily sheet until calendar cell `daily.cal.<idx>` is hittable and return it.
    /// Scrolls TOWARD the cell, never toward a landmark (RegressionDailyCalendarTests, R10).
    static func scrollToCalendarCell(_ app: XCUIApplication, _ idx: Int) -> XCUIElement {
        let cell = app.buttons["daily.cal.\(idx)"]
        for _ in 0..<8 where !cell.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(cell.isHittable, "calendar cell daily.cal.\(idx) never became hittable")
        return cell
    }

    /// Open Daily, scroll to the cell, tap it (selecting that day's card), and scroll back up so the
    /// day card's own controls (daily.play / daily.demo.*) are on screen.
    static func selectCalendarDay(_ app: XCUIApplication, _ idx: Int) {
        openDaily(app)
        scrollToCalendarCell(app, idx).tap()
        let play = app.buttons["daily.play"]
        for _ in 0..<8 where !play.isHittable {
            app.swipeDown()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(play.isHittable, "daily.play never came back on screen after selecting day \(idx)")
    }

    /// Every element on screen whose identifier begins with "card." (the 52 CardViews).
    static func cards(_ app: XCUIApplication) -> [XCUIElement] {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "card."))
            .allElementsBoundByIndex
    }

    /// Tap run heads (bottom-most cards first) until stat.moves leaves 0. Card-id driven.
    @discardableResult
    static func makeOneMove(_ app: XCUIApplication) -> Bool {
        let moves = app.staticTexts["stat.moves"]
        let sorted = cards(app).sorted { $0.frame.maxY > $1.frame.maxY }
        for card in sorted.prefix(16) {
            guard card.isHittable else { continue }
            card.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            if moves.label != "0" && moves.label != "—" { return true }
        }
        return false
    }

    /// True when `alert` carries a static text containing `fragment` (the message body).
    static func alert(_ alert: XCUIElement, contains fragment: String) -> Bool {
        alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).count > 0
    }

    /// The alert's message body (every static text joined) — for failure messages.
    static func alertText(_ alert: XCUIElement) -> String {
        alert.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " | ")
    }

    static func waitGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return !element.exists
    }

    static func wait(_ timeout: TimeInterval, until cond: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if cond() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return cond()
    }

    /// Accept the "Ready to finish" prompt the restored fixtures raise, and wait for the win overlay.
    static func finishFromPrompt(_ app: XCUIApplication) {
        let prompt = app.alerts["Ready to finish"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10),
                      "the restored board did not raise 'Ready to finish' (Auto-finish: Ask)")
        XCTAssertTrue(alert(prompt, contains: "Every remaining card can go home. Send them all now?"),
                      "prompt body changed: \(alertText(prompt))")
        prompt.buttons["Finish"].tap()
        XCTAssertTrue(app.staticTexts["You solved it! 🎉"].waitForExistence(timeout: 40),
                      "Finish did not cascade to the win overlay")
    }

    /// Deal an exact seed through the toolbar's Deal # alert (the field is PRE-FILLED: clear it first).
    static func dealSeed(_ app: XCUIApplication, _ seed: Int) {
        app.buttons["toolbar.deal"].tap()
        let entry = app.alerts["Play a deal"]
        XCTAssertTrue(entry.waitForExistence(timeout: 3), "the Deal # alert did not open")
        let field = entry.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        let prefilled = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prefilled.count))
        field.typeText(String(seed))
        entry.buttons["Play"].tap()
    }

    // MARK: fixture saves (SavedGame JSON for "causeway.game")

    /// make_save.mjs --day 14 --tier silver --challengeDay 14 --startDay 14 (seed 608530, parked at move 78; Finish -> 97 moves, bronze+silver)
    static let day14Silver = #"{"seed":608530,"tableau":[[{"suit":3,"rank":2}],[{"suit":0,"rank":4}],[{"suit":0,"rank":8}],[{"suit":3,"rank":8},{"suit":1,"rank":7}],[{"suit":0,"rank":6},{"suit":3,"rank":4}],[{"suit":3,"rank":6}],[{"suit":0,"rank":7},{"suit":1,"rank":8}],[{"suit":1,"rank":5},{"suit":3,"rank":3},{"suit":1,"rank":4},{"suit":0,"rank":5},{"suit":1,"rank":6},{"suit":3,"rank":7}]],"cells":[{"suit":3,"rank":9},{"suit":3,"rank":5},{"suit":1,"rank":3}],"up":[3,2,7,1],"down":[9,9,8,10],"moveCount":78,"elapsed":90,"started":true,"telem":{"cellUses":10,"undos":0,"maxRunMoved":2,"foundationOrder":[{"suit":2,"rank":1,"end":"up","moveIdx":3},{"suit":2,"rank":2,"end":"up","moveIdx":4},{"suit":2,"rank":3,"end":"up","moveIdx":6},{"suit":2,"rank":4,"end":"up","moveIdx":7},{"suit":0,"rank":13,"end":"down","moveIdx":11},{"suit":2,"rank":13,"end":"down","moveIdx":14},{"suit":2,"rank":5,"end":"up","moveIdx":15},{"suit":2,"rank":12,"end":"down","moveIdx":17},{"suit":2,"rank":11,"end":"down","moveIdx":18},{"suit":2,"rank":10,"end":"down","moveIdx":20},{"suit":2,"rank":9,"end":"down","moveIdx":31},{"suit":2,"rank":8,"end":"down","moveIdx":32},{"suit":2,"rank":6,"end":"up","moveIdx":33},{"suit":2,"rank":7,"end":"up","moveIdx":37},{"suit":3,"rank":13,"end":"down","moveIdx":45},{"suit":3,"rank":12,"end":"down","moveIdx":46},{"suit":0,"rank":1,"end":"up","moveIdx":49},{"suit":0,"rank":12,"end":"down","moveIdx":53},{"suit":1,"rank":13,"end":"down","moveIdx":54},{"suit":0,"rank":11,"end":"down","moveIdx":58},{"suit":0,"rank":2,"end":"up","moveIdx":59},{"suit":0,"rank":3,"end":"up","moveIdx":61},{"suit":0,"rank":10,"end":"down","moveIdx":64},{"suit":1,"rank":12,"end":"down","moveIdx":65},{"suit":3,"rank":1,"end":"up","moveIdx":67},{"suit":1,"rank":1,"end":"up","moveIdx":68},{"suit":1,"rank":2,"end":"up","moveIdx":69},{"suit":1,"rank":11,"end":"down","moveIdx":70},{"suit":3,"rank":11,"end":"down","moveIdx":71},{"suit":1,"rank":10,"end":"down","moveIdx":72},{"suit":1,"rank":9,"end":"down","moveIdx":74},{"suit":3,"rank":10,"end":"down","moveIdx":75},{"suit":0,"rank":9,"end":"down","moveIdx":76}]},"autoFinishDeferred":false,"challengeDay":14,"challengeStartDay":14}"#

    /// make_save.mjs --day 13 --tier flawless --challengeDay 13 --startDay 13 (seed 720307, move 71; Finish -> 79 moves, flawless)
    static let day13Flawless = #"{"seed":720307,"tableau":[[{"suit":3,"rank":5}],[{"suit":3,"rank":7}],[],[{"suit":3,"rank":3},{"suit":3,"rank":8}],[],[{"suit":3,"rank":6}],[],[{"suit":3,"rank":4}]],"cells":[{"suit":1,"rank":3},{"suit":3,"rank":2},null],"up":[5,2,7,1],"down":[6,4,8,9],"moveCount":71,"elapsed":90,"started":true,"telem":{"cellUses":9,"undos":0,"maxRunMoved":2,"foundationOrder":[{"suit":2,"rank":13,"end":"down","moveIdx":4},{"suit":3,"rank":13,"end":"down","moveIdx":6},{"suit":2,"rank":12,"end":"down","moveIdx":10},{"suit":2,"rank":1,"end":"up","moveIdx":13},{"suit":2,"rank":2,"end":"up","moveIdx":14},{"suit":2,"rank":3,"end":"up","moveIdx":15},{"suit":2,"rank":11,"end":"down","moveIdx":17},{"suit":2,"rank":4,"end":"up","moveIdx":18},{"suit":0,"rank":13,"end":"down","moveIdx":20},{"suit":2,"rank":5,"end":"up","moveIdx":22},{"suit":2,"rank":10,"end":"down","moveIdx":23},{"suit":3,"rank":12,"end":"down","moveIdx":26},{"suit":0,"rank":12,"end":"down","moveIdx":28},{"suit":0,"rank":11,"end":"down","moveIdx":30},{"suit":1,"rank":13,"end":"down","moveIdx":32},{"suit":1,"rank":12,"end":"down","moveIdx":33},{"suit":3,"rank":11,"end":"down","moveIdx":36},{"suit":3,"rank":10,"end":"down","moveIdx":37},{"suit":1,"rank":11,"end":"down","moveIdx":38},{"suit":1,"rank":10,"end":"down","moveIdx":41},{"suit":1,"rank":9,"end":"down","moveIdx":42},{"suit":0,"rank":10,"end":"down","moveIdx":44},{"suit":0,"rank":9,"end":"down","moveIdx":45},{"suit":0,"rank":8,"end":"down","moveIdx":46},{"suit":0,"rank":7,"end":"down","moveIdx":47},{"suit":0,"rank":1,"end":"up","moveIdx":49},{"suit":0,"rank":2,"end":"up","moveIdx":51},{"suit":0,"rank":6,"end":"down","moveIdx":53},{"suit":1,"rank":8,"end":"down","moveIdx":54},{"suit":2,"rank":6,"end":"up","moveIdx":55},{"suit":1,"rank":1,"end":"up","moveIdx":56},{"suit":1,"rank":7,"end":"down","moveIdx":57},{"suit":0,"rank":3,"end":"up","moveIdx":58},{"suit":1,"rank":2,"end":"up","moveIdx":59},{"suit":1,"rank":6,"end":"down","moveIdx":60},{"suit":3,"rank":1,"end":"up","moveIdx":61},{"suit":0,"rank":4,"end":"up","moveIdx":62},{"suit":0,"rank":5,"end":"up","moveIdx":63},{"suit":1,"rank":5,"end":"down","moveIdx":64},{"suit":1,"rank":4,"end":"down","moveIdx":65},{"suit":3,"rank":9,"end":"down","moveIdx":67},{"suit":2,"rank":9,"end":"down","moveIdx":68},{"suit":2,"rank":8,"end":"down","moveIdx":69},{"suit":2,"rank":7,"end":"up","moveIdx":70}]},"autoFinishDeferred":false,"challengeDay":13,"challengeStartDay":13}"#

    /// make_save.mjs --day 12 --tier flawless --challengeDay 12 --startDay 14 (seed 616917, a past-day replay begun Aug 15; Finish -> 103 moves, flawless, never on time)
    static let day12FlawlessStart14 = #"{"seed":616917,"tableau":[[{"suit":0,"rank":6}],[],[{"suit":0,"rank":4},{"suit":2,"rank":3}],[{"suit":1,"rank":4}],[{"suit":2,"rank":4},{"suit":0,"rank":5},{"suit":1,"rank":6},{"suit":3,"rank":7},{"suit":1,"rank":8},{"suit":3,"rank":9}],[{"suit":0,"rank":8},{"suit":1,"rank":9}],[{"suit":2,"rank":5},{"suit":1,"rank":5},{"suit":1,"rank":7},{"suit":3,"rank":8},{"suit":3,"rank":6}],[{"suit":0,"rank":9}]],"cells":[{"suit":2,"rank":6},{"suit":0,"rank":7},null],"up":[3,3,2,5],"down":[10,10,7,10],"moveCount":83,"elapsed":90,"started":true,"telem":{"cellUses":9,"undos":0,"maxRunMoved":4,"foundationOrder":[{"suit":3,"rank":13,"end":"down","moveIdx":8},{"suit":0,"rank":13,"end":"down","moveIdx":12},{"suit":3,"rank":12,"end":"down","moveIdx":18},{"suit":3,"rank":11,"end":"down","moveIdx":21},{"suit":2,"rank":13,"end":"down","moveIdx":30},{"suit":2,"rank":12,"end":"down","moveIdx":32},{"suit":0,"rank":12,"end":"down","moveIdx":36},{"suit":1,"rank":13,"end":"down","moveIdx":37},{"suit":2,"rank":11,"end":"down","moveIdx":38},{"suit":0,"rank":11,"end":"down","moveIdx":39},{"suit":2,"rank":10,"end":"down","moveIdx":40},{"suit":1,"rank":12,"end":"down","moveIdx":46},{"suit":3,"rank":10,"end":"down","moveIdx":49},{"suit":2,"rank":9,"end":"down","moveIdx":54},{"suit":1,"rank":11,"end":"down","moveIdx":59},{"suit":2,"rank":1,"end":"up","moveIdx":60},{"suit":3,"rank":1,"end":"up","moveIdx":61},{"suit":1,"rank":1,"end":"up","moveIdx":62},{"suit":0,"rank":1,"end":"up","moveIdx":63},{"suit":3,"rank":2,"end":"up","moveIdx":65},{"suit":1,"rank":2,"end":"up","moveIdx":66},{"suit":3,"rank":3,"end":"up","moveIdx":68},{"suit":1,"rank":3,"end":"up","moveIdx":69},{"suit":1,"rank":10,"end":"down","moveIdx":70},{"suit":3,"rank":4,"end":"up","moveIdx":72},{"suit":2,"rank":8,"end":"down","moveIdx":75},{"suit":3,"rank":5,"end":"up","moveIdx":76},{"suit":2,"rank":7,"end":"down","moveIdx":77},{"suit":2,"rank":2,"end":"up","moveIdx":78},{"suit":0,"rank":2,"end":"up","moveIdx":80},{"suit":0,"rank":10,"end":"down","moveIdx":82},{"suit":0,"rank":3,"end":"up","moveIdx":83}]},"autoFinishDeferred":false,"challengeDay":12,"challengeStartDay":14}"#

    /// make_save.mjs --day 2 --tier bronze --challengeDay 2 --startDay 2 (seed 539885, move 81; Finish -> 96 moves, bronze only)
    static let day2Bronze = #"{"seed":539885,"tableau":[[{"suit":0,"rank":8}],[{"suit":1,"rank":4}],[{"suit":2,"rank":8},{"suit":0,"rank":7},{"suit":2,"rank":6},{"suit":0,"rank":5},{"suit":2,"rank":4}],[],[{"suit":2,"rank":5},{"suit":1,"rank":5},{"suit":0,"rank":4}],[{"suit":2,"rank":7},{"suit":0,"rank":6}],[],[{"suit":2,"rank":9}]],"cells":[null,{"suit":0,"rank":3},{"suit":1,"rank":6}],"up":[2,3,3,12],"down":[9,7,10,13],"moveCount":81,"elapsed":90,"started":true,"telem":{"cellUses":11,"undos":0,"maxRunMoved":5,"foundationOrder":[{"suit":0,"rank":13,"end":"down","moveIdx":5},{"suit":0,"rank":12,"end":"down","moveIdx":6},{"suit":3,"rank":1,"end":"up","moveIdx":15},{"suit":0,"rank":1,"end":"up","moveIdx":16},{"suit":3,"rank":2,"end":"up","moveIdx":17},{"suit":3,"rank":3,"end":"up","moveIdx":23},{"suit":3,"rank":13,"end":"down","moveIdx":25},{"suit":2,"rank":1,"end":"up","moveIdx":29},{"suit":0,"rank":11,"end":"down","moveIdx":31},{"suit":2,"rank":2,"end":"up","moveIdx":32},{"suit":3,"rank":4,"end":"up","moveIdx":33},{"suit":2,"rank":3,"end":"up","moveIdx":34},{"suit":3,"rank":5,"end":"up","moveIdx":38},{"suit":3,"rank":6,"end":"up","moveIdx":39},{"suit":3,"rank":7,"end":"up","moveIdx":40},{"suit":1,"rank":1,"end":"up","moveIdx":45},{"suit":0,"rank":2,"end":"up","moveIdx":46},{"suit":1,"rank":13,"end":"down","moveIdx":50},{"suit":1,"rank":2,"end":"up","moveIdx":51},{"suit":1,"rank":12,"end":"down","moveIdx":52},{"suit":1,"rank":11,"end":"down","moveIdx":55},{"suit":3,"rank":8,"end":"up","moveIdx":57},{"suit":1,"rank":10,"end":"down","moveIdx":58},{"suit":3,"rank":9,"end":"up","moveIdx":61},{"suit":3,"rank":10,"end":"up","moveIdx":62},{"suit":1,"rank":9,"end":"down","moveIdx":63},{"suit":1,"rank":8,"end":"down","moveIdx":64},{"suit":1,"rank":7,"end":"down","moveIdx":65},{"suit":3,"rank":11,"end":"up","moveIdx":68},{"suit":1,"rank":3,"end":"up","moveIdx":70},{"suit":0,"rank":10,"end":"down","moveIdx":72},{"suit":0,"rank":9,"end":"down","moveIdx":74},{"suit":3,"rank":12,"end":"up","moveIdx":75},{"suit":2,"rank":13,"end":"down","moveIdx":76},{"suit":2,"rank":12,"end":"down","moveIdx":77},{"suit":2,"rank":11,"end":"down","moveIdx":78},{"suit":2,"rank":10,"end":"down","moveIdx":79}]},"autoFinishDeferred":false,"challengeDay":2,"challengeStartDay":2}"#

    /// make_save.mjs --day 29 --tier flawless --challengeDay 29 --startDay 29 (seed 551879, move 92; Finish -> 96 moves, flawless)
    static let day29Flawless = #"{"seed":551879,"tableau":[[],[],[{"suit":0,"rank":7},{"suit":2,"rank":8}],[],[],[],[{"suit":0,"rank":8}],[]],"cells":[{"suit":0,"rank":6},null,null],"up":[5,8,7,8],"down":[9,9,9,9],"moveCount":92,"elapsed":90,"started":true,"telem":{"cellUses":13,"undos":0,"maxRunMoved":4,"foundationOrder":[{"suit":1,"rank":1,"end":"up","moveIdx":2},{"suit":2,"rank":13,"end":"down","moveIdx":6},{"suit":1,"rank":13,"end":"down","moveIdx":7},{"suit":3,"rank":13,"end":"down","moveIdx":8},{"suit":0,"rank":13,"end":"down","moveIdx":9},{"suit":2,"rank":12,"end":"down","moveIdx":10},{"suit":0,"rank":12,"end":"down","moveIdx":13},{"suit":3,"rank":1,"end":"up","moveIdx":14},{"suit":2,"rank":11,"end":"down","moveIdx":17},{"suit":2,"rank":10,"end":"down","moveIdx":27},{"suit":2,"rank":9,"end":"down","moveIdx":29},{"suit":0,"rank":1,"end":"up","moveIdx":35},{"suit":1,"rank":2,"end":"up","moveIdx":37},{"suit":1,"rank":12,"end":"down","moveIdx":39},{"suit":3,"rank":2,"end":"up","moveIdx":40},{"suit":3,"rank":3,"end":"up","moveIdx":41},{"suit":1,"rank":11,"end":"down","moveIdx":44},{"suit":3,"rank":12,"end":"down","moveIdx":45},{"suit":2,"rank":1,"end":"up","moveIdx":48},{"suit":0,"rank":2,"end":"up","moveIdx":50},{"suit":1,"rank":3,"end":"up","moveIdx":52},{"suit":3,"rank":11,"end":"down","moveIdx":53},{"suit":2,"rank":2,"end":"up","moveIdx":54},{"suit":3,"rank":10,"end":"down","moveIdx":56},{"suit":3,"rank":9,"end":"down","moveIdx":57},{"suit":1,"rank":10,"end":"down","moveIdx":60},{"suit":0,"rank":11,"end":"down","moveIdx":61},{"suit":0,"rank":10,"end":"down","moveIdx":65},{"suit":3,"rank":4,"end":"up","moveIdx":66},{"suit":1,"rank":9,"end":"down","moveIdx":68},{"suit":0,"rank":9,"end":"down","moveIdx":69},{"suit":3,"rank":5,"end":"up","moveIdx":72},{"suit":3,"rank":6,"end":"up","moveIdx":74},{"suit":1,"rank":4,"end":"up","moveIdx":75},{"suit":3,"rank":7,"end":"up","moveIdx":77},{"suit":3,"rank":8,"end":"up","moveIdx":78},{"suit":0,"rank":3,"end":"up","moveIdx":79},{"suit":1,"rank":5,"end":"up","moveIdx":80},{"suit":1,"rank":6,"end":"up","moveIdx":82},{"suit":1,"rank":7,"end":"up","moveIdx":84},{"suit":1,"rank":8,"end":"up","moveIdx":85},{"suit":0,"rank":4,"end":"up","moveIdx":86},{"suit":2,"rank":3,"end":"up","moveIdx":87},{"suit":0,"rank":5,"end":"up","moveIdx":88},{"suit":2,"rank":4,"end":"up","moveIdx":89},{"suit":2,"rank":5,"end":"up","moveIdx":90},{"suit":2,"rank":6,"end":"up","moveIdx":91},{"suit":2,"rank":7,"end":"up","moveIdx":92}]},"autoFinishDeferred":false,"challengeDay":29,"challengeStartDay":29}"#

    /// make_save.mjs with its picker relaxed to `a.won` --day 21 --tier flawless --challengeDay 21 --startDay 29 (seed 944114, move 64/87: the FIRST position the cascade can win from; finish -> 83 moves, gold LOST)
    static let day21FirstWinnable = #"{"seed":944114,"tableau":[[{"suit":0,"rank":6},{"suit":0,"rank":7}],[{"suit":2,"rank":9},{"suit":3,"rank":8},{"suit":2,"rank":7}],[{"suit":3,"rank":10},{"suit":1,"rank":7},{"suit":0,"rank":10},{"suit":2,"rank":10}],[{"suit":3,"rank":9},{"suit":2,"rank":8},{"suit":3,"rank":7}],[{"suit":1,"rank":6}],[{"suit":0,"rank":5}],[{"suit":0,"rank":11}],[{"suit":0,"rank":9},{"suit":1,"rank":8}]],"cells":[{"suit":0,"rank":8},{"suit":3,"rank":11},null],"up":[4,5,6,6],"down":[12,9,11,12],"moveCount":64,"elapsed":90,"started":true,"telem":{"cellUses":8,"undos":0,"maxRunMoved":1,"foundationOrder":[{"suit":2,"rank":1,"end":"up","moveIdx":3},{"suit":0,"rank":1,"end":"up","moveIdx":4},{"suit":0,"rank":2,"end":"up","moveIdx":6},{"suit":2,"rank":13,"end":"down","moveIdx":7},{"suit":0,"rank":13,"end":"down","moveIdx":10},{"suit":3,"rank":1,"end":"up","moveIdx":13},{"suit":0,"rank":3,"end":"up","moveIdx":14},{"suit":0,"rank":12,"end":"down","moveIdx":16},{"suit":1,"rank":1,"end":"up","moveIdx":17},{"suit":1,"rank":2,"end":"up","moveIdx":18},{"suit":2,"rank":2,"end":"up","moveIdx":21},{"suit":3,"rank":13,"end":"down","moveIdx":22},{"suit":3,"rank":2,"end":"up","moveIdx":23},{"suit":2,"rank":3,"end":"up","moveIdx":24},{"suit":3,"rank":12,"end":"down","moveIdx":27},{"suit":2,"rank":4,"end":"up","moveIdx":30},{"suit":1,"rank":3,"end":"up","moveIdx":31},{"suit":1,"rank":13,"end":"down","moveIdx":32},{"suit":1,"rank":4,"end":"up","moveIdx":34},{"suit":1,"rank":5,"end":"up","moveIdx":37},{"suit":1,"rank":12,"end":"down","moveIdx":40},{"suit":3,"rank":3,"end":"up","moveIdx":43},{"suit":1,"rank":11,"end":"down","moveIdx":45},{"suit":1,"rank":10,"end":"down","moveIdx":47},{"suit":0,"rank":4,"end":"up","moveIdx":48},{"suit":3,"rank":4,"end":"up","moveIdx":52},{"suit":3,"rank":5,"end":"up","moveIdx":55},{"suit":3,"rank":6,"end":"up","moveIdx":56},{"suit":2,"rank":12,"end":"down","moveIdx":57},{"suit":1,"rank":9,"end":"down","moveIdx":58},{"suit":2,"rank":5,"end":"up","moveIdx":60},{"suit":2,"rank":6,"end":"up","moveIdx":62},{"suit":2,"rank":11,"end":"down","moveIdx":63}]},"autoFinishDeferred":false,"challengeDay":21,"challengeStartDay":29}"#

    /// zero_move_save.mjs --day 13 (seed 720307, Play tapped on Aug 14 and never moved: challengeDay 13 / challengeStartDay 13 / moveCount 0)
    static let zeroMoveDay13 = #"{"seed":720307,"tableau":[[{"suit":2,"rank":8},{"suit":3,"rank":9},{"suit":3,"rank":4},{"suit":1,"rank":5},{"suit":0,"rank":9},{"suit":3,"rank":2},{"suit":2,"rank":13}],[{"suit":0,"rank":1},{"suit":1,"rank":9},{"suit":0,"rank":6},{"suit":3,"rank":11},{"suit":0,"rank":2},{"suit":0,"rank":5},{"suit":0,"rank":8}],[{"suit":1,"rank":13},{"suit":1,"rank":12},{"suit":3,"rank":12},{"suit":2,"rank":3},{"suit":1,"rank":1},{"suit":2,"rank":12},{"suit":1,"rank":3}],[{"suit":3,"rank":3},{"suit":3,"rank":8},{"suit":3,"rank":5},{"suit":0,"rank":4},{"suit":1,"rank":2},{"suit":1,"rank":7},{"suit":1,"rank":11}],[{"suit":2,"rank":5},{"suit":1,"rank":8},{"suit":2,"rank":1},{"suit":1,"rank":4},{"suit":3,"rank":13},{"suit":2,"rank":4}],[{"suit":3,"rank":6},{"suit":3,"rank":1},{"suit":1,"rank":6},{"suit":0,"rank":3},{"suit":0,"rank":7},{"suit":2,"rank":9}],[{"suit":2,"rank":7},{"suit":3,"rank":7},{"suit":0,"rank":13},{"suit":0,"rank":10},{"suit":2,"rank":2},{"suit":3,"rank":10}],[{"suit":0,"rank":11},{"suit":1,"rank":10},{"suit":2,"rank":6},{"suit":2,"rank":10},{"suit":2,"rank":11},{"suit":0,"rank":12}]],"cells":[null,null,null],"up":[0,0,0,0],"down":[14,14,14,14],"moveCount":0,"elapsed":0,"started":false,"telem":{"cellUses":0,"undos":0,"maxRunMoved":0,"foundationOrder":[]},"autoFinishDeferred":false,"challengeDay":13,"challengeStartDay":13}"#

}
