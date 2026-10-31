import Foundation
import FolzioLocalization
import Testing

@Suite("Settings Window Text")
struct SettingsTextTests {
    @Test("The confirmation checkbox and its note are separate sentences in both languages (FR-209)")
    func confirmationCheckboxAndNote() {
        let ja = LocalizationTestSupport.localizer("ja")
        let en = LocalizationTestSupport.localizer("en")

        #expect(ja.text(.settingsConfirm) == "コピー・ゴミ箱に入れる・お気に入りから削除する前に確認する")
        #expect(ja.text(.settingsConfirmNote) == "名前の変更・移動・ツリーのフォルダのゴミ箱は常に確認する")
        #expect(en.text(.settingsConfirm) == "Confirm before copying, moving to the Trash, or removing from Favorites")
        #expect(en.text(.settingsConfirmNote) == "Renaming, moving, and moving tree folders to the Trash are always confirmed")
    }

    @Test("The confirmation checkbox no longer carries the always-confirmed operations in parentheses")
    func confirmationCheckboxHasNoParenthesizedNote() {
        for language in LocalizationTestSupport.languages {
            let text = LocalizationTestSupport.localizer(language).text(.settingsConfirm)
            #expect(!text.contains("（") && !text.contains("("), "\(language): \(text)")
        }
    }
}
