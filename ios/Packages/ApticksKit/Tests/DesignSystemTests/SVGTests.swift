import SwiftUI
import Testing
@testable import DesignSystem

struct SVGTests {
    @Test func compactPathNumbers() {
        // Numbers that run together, as in the seed's figures.
        let box = SVGPath.parse("M-22-26H22V26H0").boundingRect
        #expect(box.minX == -22)
        #expect(box.minY == -26)
        #expect(box.maxX == 22)
        #expect(box.maxY == 26)
    }

    @Test func decimalsWithoutSeparators() {
        let box = SVGPath.parse("M.5.5L10.5 10.5").boundingRect
        #expect(abs(box.minX - 0.5) < 0.001)
        #expect(abs(box.maxY - 10.5) < 0.001)
    }

    @Test func arcsBulgeTheRightWay() {
        // A half circle from (8,-32) to (8,0) with radius 16 bulges right, to x = 24.
        let box = SVGPath.parse("M8 -32A16 16 0 0 1 8 0").boundingRect
        #expect(abs(box.maxX - 24) < 0.5)
        #expect(abs(box.minX - 8) < 0.5)
    }

    @Test func relativeAndSmoothCurves() {
        // Tiko's confused mouth: q then t.
        let box = SVGPath.parse("M49 89 q5.5 -5 11 0 t11 0").boundingRect
        #expect(abs(box.minX - 49) < 0.001)
        #expect(abs(box.maxX - 71) < 0.001)
    }

    @Test func refusesUnsafeMarkup() {
        #expect(SVGDocument.load(#"<svg viewBox="0 0 10 10"><script>x</script></svg>"#) == nil)
        #expect(SVGDocument.load(#"<svg viewBox="0 0 10 10" onload="x()"></svg>"#) == nil)
        #expect(SVGDocument.load("not svg") == nil)
        #expect(SVGDocument.load(#"<svg viewBox="0 0 540 100"><rect x="3" y="3" width="94" height="94"/></svg>"#)?.viewBox.width == 540)
    }

    @Test func easingEndpointsAndTracks() {
        for ease in [Ease.linear, .ease, .easeIn, .easeOut, .easeInOut, .rise, .fall] {
            #expect(ease(0) == 0)
            #expect(ease(1) == 1)
        }
        #expect(Ease.easeOut(0.5) > 0.5) // fast start
        #expect(Ease.easeIn(0.5) < 0.5) // slow start
        let track = Track(frames: [KF(0, [0, 10]), KF(0.5, [10, 10]), KF(1, [0, 0])])
        #expect(track.at(0.25) == [5, 10])
        #expect(track.at(0.75) == [5, 5])
        #expect(track.loop(3, period: 2) == [10, 10])
    }
}
