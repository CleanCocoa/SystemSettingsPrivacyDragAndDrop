import CoreGraphics
import Testing
@testable import PrivacyDragAndDrop

struct CoverageTests {
    let settings = CGRect(x: 100, y: 100, width: 400, height: 300)

    @Test func noCoversLeaveItVisible() {
        #expect(isFullyCovered(settings, by: []) == false)
    }

    @Test func aLargerWindowCoversIt() {
        #expect(isFullyCovered(settings, by: [CGRect(x: 0, y: 0, width: 800, height: 600)]) == true)
    }

    @Test func aWindowBesideItDoesNotCoverIt() {
        #expect(isFullyCovered(settings, by: [CGRect(x: 500, y: 100, width: 400, height: 300)]) == false)
    }

    @Test func aPartialOverlapDoesNotCoverIt() {
        #expect(isFullyCovered(settings, by: [CGRect(x: 0, y: 0, width: 300, height: 600)]) == false)
    }

    @Test func twoWindowsTogetherCoverIt() {
        let left = CGRect(x: 0, y: 0, width: 300, height: 600)
        let right = CGRect(x: 300, y: 0, width: 300, height: 600)
        #expect(isFullyCovered(settings, by: [left, right]) == true)
    }

    @Test func aGapBetweenTwoWindowsLeavesItVisible() {
        let left = CGRect(x: 0, y: 0, width: 300, height: 600)
        let right = CGRect(x: 301, y: 0, width: 300, height: 600)
        #expect(isFullyCovered(settings, by: [left, right]) == false)
    }
}
