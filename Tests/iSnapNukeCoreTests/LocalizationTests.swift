import Foundation
import XCTest
import iSnapNukeLocalization

final class LocalizationTests: XCTestCase {
    private struct LocalizableEntry {
        let key: String
        let value: String
    }

    private static let localizableEntryPattern = try! NSRegularExpression(
        pattern: #"^\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)";\s*$"#
    )
    private static let printfMarkerPattern = try! NSRegularExpression(
        pattern: #"%(?:\d+\$)?[@d]"#
    )

    private func resourceURL(languageDirectory: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/iSnapNukeLocalization/Resources")
            .appendingPathComponent(languageDirectory)
            .appendingPathComponent("Localizable.strings")
    }

    private func localizableEntries(at url: URL) throws -> [LocalizableEntry] {
        let source = try String(contentsOf: url, encoding: .utf8)

        return try source
            .components(separatedBy: .newlines)
            .enumerated()
            .compactMap { lineNumber, line -> LocalizableEntry? in
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedLine.isEmpty else {
                    return nil
                }

                let range = NSRange(trimmedLine.startIndex..., in: trimmedLine)
                guard
                    let match = Self.localizableEntryPattern.firstMatch(
                        in: trimmedLine,
                        range: range
                    ),
                    let keyRange = Range(match.range(at: 1), in: trimmedLine),
                    let valueRange = Range(match.range(at: 2), in: trimmedLine)
                else {
                    throw NSError(
                        domain: "LocalizationTests",
                        code: lineNumber + 1,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Invalid Localizable.strings entry at \(url.path):\(lineNumber + 1)"
                        ]
                    )
                }

                let key = String(trimmedLine[keyRange])
                guard !key.isEmpty else {
                    throw NSError(
                        domain: "LocalizationTests",
                        code: lineNumber + 1,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Empty Localizable.strings key at \(url.path):\(lineNumber + 1)"
                        ]
                    )
                }

                return LocalizableEntry(key: key, value: String(trimmedLine[valueRange]))
            }
    }

    private func printfMarkers(in value: String) -> [String] {
        let range = NSRange(value.startIndex..., in: value)
        return Self.printfMarkerPattern.matches(in: value, range: range).compactMap { match in
            Range(match.range, in: value).map { String(value[$0]) }
        }
    }

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
            "Meets conservative deletion criteria"
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
            "Total fucking space taken up: 1 GB"
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
        XCTAssertEqual(
            L10n.text("action.select_all_eligible", language: .english),
            "Select All Eligible"
        )
        XCTAssertEqual(
            L10n.text("action.select_all_eligible", language: .traditionalChinese),
            "全選可刪除快照"
        )
        XCTAssertEqual(
            L10n.text("action.deselect_all", language: .english),
            "Deselect All"
        )
        XCTAssertEqual(
            L10n.text("action.deselect_all", language: .traditionalChinese),
            "取消全選"
        )
    }

    func testRawResourcesHaveMatchingValidEntriesAndPrintfMarkers() throws {
        let englishEntries = try localizableEntries(
            at: resourceURL(languageDirectory: "en.lproj")
        )
        let traditionalChineseEntries = try localizableEntries(
            at: resourceURL(languageDirectory: "zh-Hant.lproj")
        )

        XCTAssertEqual(englishEntries.count, 139)
        XCTAssertEqual(traditionalChineseEntries.count, 139)

        let englishKeys = englishEntries.map(\.key)
        let traditionalChineseKeys = traditionalChineseEntries.map(\.key)
        let englishKeySet = Set(englishKeys)
        let traditionalChineseKeySet = Set(traditionalChineseKeys)
        XCTAssertEqual(englishKeySet.count, englishKeys.count, "English resource has duplicate keys")
        XCTAssertEqual(
            traditionalChineseKeySet.count,
            traditionalChineseKeys.count,
            "Traditional Chinese resource has duplicate keys"
        )
        XCTAssertEqual(englishKeySet, traditionalChineseKeySet)

        guard
            englishKeySet.count == englishKeys.count,
            traditionalChineseKeySet.count == traditionalChineseKeys.count,
            englishKeySet == traditionalChineseKeySet
        else {
            return
        }

        let englishValues = Dictionary(uniqueKeysWithValues: englishEntries.map { ($0.key, $0.value) })
        let traditionalChineseValues = Dictionary(
            uniqueKeysWithValues: traditionalChineseEntries.map { ($0.key, $0.value) }
        )
        for key in englishKeys {
            XCTAssertEqual(
                printfMarkers(in: englishValues[key]!),
                printfMarkers(in: traditionalChineseValues[key]!),
                "Printf markers differ for \(key)"
            )
        }
    }

    func testEveryRawResourceKeyResolvesThroughL10n() throws {
        let englishEntries = try localizableEntries(
            at: resourceURL(languageDirectory: "en.lproj")
        )

        for key in englishEntries.map(\.key) {
            XCTAssertNotEqual(
                L10n.text(key, language: .english),
                key,
                "English localization did not resolve \(key)"
            )
            XCTAssertNotEqual(
                L10n.text(key, language: .traditionalChinese),
                key,
                "Traditional Chinese localization did not resolve \(key)"
            )
        }
    }

    func testEnglishSafetyWarningsAndAdministratorWording() {
        XCTAssertEqual(
            L10n.text("confirm.body", language: .english),
            "After deletion, you will no longer be able to restore to those points in time. This cannot be undone."
        )
        XCTAssertEqual(
            L10n.text("confirm.backup_warning", language: .english),
            "If any of these snapshots belong to a third-party backup tool, such as Synology Active Backup, deleting them may remove the corresponding local backup restore points."
        )
        XCTAssertEqual(
            L10n.text("action.retry_admin", language: .english),
            "Retry with Administrator Privileges"
        )
        XCTAssertEqual(
            L10n.text("error.force_requires_administrator", language: .english),
            "Force deletion requires administrator privileges."
        )
        XCTAssertEqual(
            L10n.text("force.mode.banner", language: .english),
            "“Fuck It” Mode is on. Protected snapshots can be selected, and deleting them requires administrator privileges."
        )
        XCTAssertEqual(
            L10n.text("snapshot.force_selectable", language: .english),
            "Selectable in “Fuck It” Mode"
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
