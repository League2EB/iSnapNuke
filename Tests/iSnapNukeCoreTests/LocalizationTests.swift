import XCTest
import iSnapNukeLocalization

final class LocalizationTests: XCTestCase {
    func testTraditionalChineseLanguageResolution() {
        XCTAssertEqual(iSnapNukeLanguage.resolve(localeIdentifier: "zh-Hant-TW"), .traditionalChinese)
        XCTAssertEqual(iSnapNukeLanguage.resolve(localeIdentifier: "zh_TW"), .traditionalChinese)
        XCTAssertEqual(iSnapNukeLanguage.resolve(localeIdentifier: "zh-HK"), .traditionalChinese)
    }

    func testUnsupportedLanguagesFallBackToEnglish() {
        XCTAssertEqual(iSnapNukeLanguage.resolve(localeIdentifier: "en-US"), .english)
        XCTAssertEqual(iSnapNukeLanguage.resolve(localeIdentifier: "zh-Hans-CN"), .english)
        XCTAssertEqual(iSnapNukeLanguage.resolve(localeIdentifier: "ja-JP"), .english)
    }

    func testBothTranslationsAndUnavailableSize() {
        XCTAssertEqual(
            L10n.text("safety.deletable", language: .english),
            "Eligible for deletion"
        )
        XCTAssertEqual(
            L10n.text("safety.deletable", language: .traditionalChinese),
            "符合保守刪除條件"
        )
        XCTAssertEqual(
            L10n.format(
                "confirm.total_reclaimable",
                "1 GB",
                language: .english
            ),
            "Total fucking space occupied: 1 GB"
        )
        XCTAssertEqual(
            L10n.format(
                "confirm.total_reclaimable",
                "1 GB",
                language: .traditionalChinese
            ),
            "你他媽被佔用了總計：1 GB"
        )
        XCTAssertEqual(L10n.byteCount(nil, language: .english), "Unavailable")
        XCTAssertEqual(L10n.byteCount(nil, language: .traditionalChinese), "無法取得")
        XCTAssertEqual(
            L10n.text("force.mode.enable", language: .traditionalChinese),
            "開啟「管他去死」模式"
        )
        XCTAssertEqual(
            L10n.text("force.mode.disable", language: .traditionalChinese),
            "關閉「管他去死」模式"
        )
        XCTAssertEqual(
            L10n.text("force.mode.acknowledge", language: .traditionalChinese),
            "確認開啟「管他去死」模式"
        )
        XCTAssertEqual(
            L10n.text("force.mode.enable", language: .english),
            "Turn On “Fuck It” Mode"
        )
        XCTAssertEqual(
            L10n.text("force.mode.disable", language: .english),
            "Turn Off “Fuck It” Mode"
        )
        XCTAssertEqual(
            L10n.text("force.mode.acknowledge", language: .english),
            "Confirm and Turn On “Fuck It” Mode"
        )
    }

    func testDeletionProgressAndDemoTranslationsExistInBothLanguages() {
        XCTAssertEqual(
            L10n.format(
                "footer.processing_progress",
                2,
                3,
                language: .english
            ),
            "Deleting snapshot 2 of 3…"
        )
        XCTAssertEqual(
            L10n.format(
                "footer.processing_progress",
                2,
                3,
                language: .traditionalChinese
            ),
            "正在刪除第 2／3 個快照…"
        )

        let keys = [
            "snapshot.queued",
            "snapshot.deleting",
            "snapshot.deleted_animating",
            "snapshot.delete_failed",
            "snapshot.delete_skipped",
            "force.mode.enable",
            "force.mode.disable",
            "force.mode.warning_title",
            "force.mode.warning_body",
            "force.mode.warning_note",
            "force.mode.acknowledge",
            "snapshot.force_selectable",
            "footer.select_force",
            "action.force_delete_permanently",
            "confirm.force_title",
            "confirm.force_warning",
            "summary.force_mode",
            "summary.force_item",
            "demo.title",
            "demo.description",
            "demo.reset",
            "demo.speed.fast",
            "demo.speed.normal",
            "demo.speed.slow",
            "demo.scenario.all_succeed",
            "demo.scenario.permission_denied",
            "demo.scenario.missing",
            "demo.scenario.command_failed",
            "update.checking_title",
            "update.optional_title",
            "update.required_title",
            "update.install_now",
            "update.later",
            "update.retry",
            "update.quit",
            "update.check_for_updates",
            "update.demo_install_title",
            "update.demo_install_body",
        ]

        for key in keys {
            XCTAssertNotEqual(L10n.text(key, language: .english), key)
            XCTAssertNotEqual(L10n.text(key, language: .traditionalChinese), key)
        }
    }
}
