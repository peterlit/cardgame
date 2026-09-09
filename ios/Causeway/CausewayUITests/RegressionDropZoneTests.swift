//
//  RegressionDropZoneTests.swift
//  CausewayUITests
//
//  Regression tripwires for:
//    ux/WF-2:drop-below-column-refused (minor; fixed on 5447237, archive 20260822-125736-f949d82)
//    ux/WF-2:drop-gutter-dead-zone     (minor; fixed on 369c365, archive 20260830-155810-a937162)
//  Both unguarded until this round's archive sweep.
//
//  FIXED contracts these tests guard (ContentView.dropZone / column drop frames):
//   - A column's drop frame spans the FULL tableau height, so a legal drag released in the
//     empty space just below the target column's last card is accepted, not snapped back.
//   - Column drop zones TILE horizontally: every x across the ~5 pt gutter between two
//     columns resolves to the nearer column, so a release in the gutter lands.
//
//  Original repros (round-1 tester, coordinates are tester geometry — NOT a contract):
//   below: deal #10004; press-drag the 10♥ at the bottom of column 6 (321,612) and release
//     at (28,700), 20 pt below column 0's last card (J♣, bottom edge y=680): snapped back.
//   gutter: deal #10004 after three set-up drags; release 5♠ at x=52 (the gap between
//     col 0 and col 1): snapped back, Moves unchanged; 4 pt further left it landed.
//
//  Retrofit: the same deal (#10004, dealt through the Deal # alert), but the cards are
//  located by "card.<S><rank>" (CardView) and the release points are derived from the
//  TARGET card's frame — below its bottom edge, and just past its right edge — so the
//  probe follows the layout instead of a device's pixel grid. Auto-play is pinned OFF so
//  nothing but the drag can change the move count.
//
import XCTest

final class RegressionDropZoneTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-2:drop-below-column-refused — releasing 20 pt below the column's last card lands.
    func testReleaseBelowTheColumnsLastCardIsAccepted() throws {
        let app = QA.launch(autoplay: false)
        let (source, target, moves) = dealTenOfHeartsOntoJackOfClubs(app)

        let release = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: target.frame.midX, dy: target.frame.maxY + 20))   // 20 pt BELOW J♣
        source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: release)

        XCTAssertTrue(QA.wait(3) { moves.label == "1" },
                      "a legal drop released 20 pt below column 0's last card was refused (Moves \(moves.label)) — the round-1 bug is back")
        XCTAssertLessThan(abs(source.frame.midX - target.frame.midX), 6,
                          "10♥ did not land in column 0 (x \(source.frame.midX) vs J♣ x \(target.frame.midX))")
    }

    /// ux/WF-2:drop-gutter-dead-zone — a release in the gutter resolves to the nearer column.
    func testReleaseInTheGutterResolvesToTheNearestColumn() throws {
        let app = QA.launch(autoplay: false)
        let (source, target, moves) = dealTenOfHeartsOntoJackOfClubs(app)

        // 1 pt past J♣'s right edge: inside the gutter, nearer column 0 than column 1.
        let release = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: target.frame.maxX + 1, dy: target.frame.midY))
        source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: release)

        XCTAssertTrue(QA.wait(3) { moves.label == "1" },
                      "a legal drop released in the gutter beside column 0 was refused (Moves \(moves.label)) — the dead zone is back")
        XCTAssertLessThan(abs(source.frame.midX - target.frame.midX), 6,
                          "10♥ did not land in column 0 (x \(source.frame.midX) vs J♣ x \(target.frame.midX))")
    }

    // MARK: - helpers

    /// Deal #10004 and return (10♥ = column 6's bottom card, J♣ = column 0's bottom card, stat.moves).
    private func dealTenOfHeartsOntoJackOfClubs(_ app: XCUIApplication) -> (XCUIElement, XCUIElement, XCUIElement) {
        QA.dealSeed(app, 10004)
        let dealPill = app.buttons["toolbar.deal"]
        XCTAssertTrue(QA.wait(5) { dealPill.label.hasPrefix("Deal #10004") }, "deal #10004 did not load: \(dealPill.label)")
        let moves = app.staticTexts["stat.moves"]
        XCTAssertEqual(moves.label, "0")
        let source = app.descendants(matching: .any)["card.H10"]
        let target = app.descendants(matching: .any)["card.C11"]
        XCTAssertTrue(source.waitForExistence(timeout: 3), "no card.H10 on the board — deal #10004 layout changed?")
        XCTAssertTrue(target.exists, "no card.C11 on the board — deal #10004 layout changed?")
        XCTAssertTrue(source.isHittable && target.isHittable)
        // Layout sanity for the probe: 10♥ is the deepest card of its column, J♣ of column 0.
        XCTAssertGreaterThan(abs(source.frame.midX - target.frame.midX), 100, "10♥ and J♣ should sit in different columns")
        return (source, target, moves)
    }
}
