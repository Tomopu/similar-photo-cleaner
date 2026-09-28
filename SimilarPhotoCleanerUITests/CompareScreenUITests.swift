import XCTest

/// ホーム → 似た写真 → 比較モードを実際に操作し、各画面のスクリーンショットを結果に残す。
/// シミュレータの写真ライブラリに似た写真のグループがあることが前提。
final class CompareScreenUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    func testBrowseSimilarGroupsAndCompare() throws {
        app.launch()
        grantPhotoAccessIfNeeded()

        let similarRow = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "似た写真を比べる")).firstMatch
        XCTAssertTrue(similarRow.waitForExistence(timeout: 30), "ホームに「似た写真を比べる」が出ない")
        // 解析が終わってグループができるまで待つ
        let hasGroups = NSPredicate(format: "NOT (label CONTAINS %@)", "0グループ")
        expectation(for: hasGroups, evaluatedWith: similarRow)
        waitForExpectations(timeout: 300)
        attachScreenshot("1-home")

        similarRow.tap()
        let groupCard = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "削除候補")).firstMatch
        XCTAssertTrue(groupCard.waitForExistence(timeout: 10), "グループのカードが出ない")
        attachScreenshot("2-groups")

        groupCard.tap()
        let nextButton = app.buttons["次の写真と比べる"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 10), "比較画面が出ない")
        sleep(2)
        attachScreenshot("3-compare")

        // 下の一覧を左へスクロールし、右端の写真をタップして切り替える
        let strip = app.scrollViews.containing(NSPredicate(format: "label CONTAINS %@", "この写真と比べる")).firstMatch
        if strip.exists { strip.swipeLeft() }
        sleep(1)
        attachScreenshot("4-filmstrip-scrolled")
        let targets = app.buttons.matching(NSPredicate(format: "label == %@", "この写真と比べる"))
        if targets.count > 0 {
            targets.element(boundBy: targets.count - 1).tap()
            sleep(2)
            attachScreenshot("5-picked-from-filmstrip")
        }

        nextButton.tap()
        sleep(2)
        attachScreenshot("6-next")
    }

    private func grantPhotoAccessIfNeeded() {
        let allow = app.buttons["写真へのアクセスを許可"]
        guard allow.waitForExistence(timeout: 5) else { return }
        allow.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["フルアクセスを許可", "Allow Full Access"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 5) {
                button.tap()
                return
            }
        }
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
