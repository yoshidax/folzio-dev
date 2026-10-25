import Foundation
import Testing
@testable import MediaViewerCore

@Suite("SlideshowInputPolicy")
struct SlideshowInputPolicyTests {
    @Test("6条件の64通りで、Esc と矢印は全条件を満たすときだけ受理する")
    func truthTable() {
        for active in [false, true] {
            for restoring in [false, true] {
                for keyWindow in [false, true] {
                    for sheet in [false, true] {
                        for modal in [false, true] {
                            for editing in [false, true] {
                                let policy = SlideshowInputPolicy(
                                    isActive: active,
                                    isRestoring: restoring,
                                    isTargetWindowKey: keyWindow,
                                    hasSheet: sheet,
                                    hasAppModal: modal,
                                    isEditingText: editing
                                )
                                let label = "active=\(active), restoring=\(restoring), key=\(keyWindow), "
                                    + "sheet=\(sheet), modal=\(modal), editing=\(editing)"
                                let expected = active
                                    && !restoring
                                    && keyWindow
                                    && !sheet
                                    && !modal
                                    && !editing

                                #expect(policy.acceptsKeys == expected, "\(label)")
                                #expect(policy.accepts(.escape) == expected, "\(label)")
                                #expect(policy.accepts(.arrow) == expected, "\(label)")
                                #expect(!policy.accepts(.other), "\(label)")
                            }
                        }
                    }
                }
            }
        }
    }

    @Test("メニューがキーを処理している間は Esc・矢印を受理しない")
    func menuOwnsInput() {
        let policy = SlideshowInputPolicy(
            isActive: true,
            isRestoring: false,
            isTargetWindowKey: true,
            hasSheet: false,
            hasAppModal: false,
            isEditingText: false,
            menuOwnsInput: true
        )
        #expect(!policy.acceptsKeys)
        #expect(!policy.accepts(.escape))
        #expect(!policy.accepts(.arrow))
    }

    @Test("開始可否は候補・実行状態・編集・シート・モーダルで決まり、読み込み中と全画面は妨げない")
    func startTruthTable() {
        for hasCandidate in [false, true] {
            for loading in [false, true] {
                for fullScreen in [false, true] {
                    for active in [false, true] {
                        for restoring in [false, true] {
                            for editing in [false, true] {
                                for sheet in [false, true] {
                                    for modal in [false, true] {
                                        let policy = SlideshowStartPolicy(
                                            hasCandidate: hasCandidate,
                                            isLoading: loading,
                                            isFullScreen: fullScreen,
                                            isSlideshowActive: active,
                                            isRestoring: restoring,
                                            isEditingText: editing,
                                            hasSheet: sheet,
                                            hasAppModal: modal
                                        )
                                        let expected = hasCandidate
                                            && !active
                                            && !restoring
                                            && !editing
                                            && !sheet
                                            && !modal
                                        let label = "candidate=\(hasCandidate), loading=\(loading), "
                                            + "fullScreen=\(fullScreen), active=\(active), "
                                            + "restoring=\(restoring), editing=\(editing), "
                                            + "sheet=\(sheet), modal=\(modal)"
                                        #expect(policy.canStart == expected, "\(label)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @Test("スライドショー中と復帰中はペイン切り替えと履歴移動を止める")
    func paneCommandsRespectSlideshow() {
        let normal = PaneCommands(layout: .all, isFullScreen: false, isEditingText: false)
        #expect(normal.canChangeLayout)
        #expect(normal.canNavigateHistory)

        let active = PaneCommands(
            layout: .previewOnly,
            isFullScreen: false,
            isEditingText: false,
            isSlideshowActive: true
        )
        #expect(!active.canChangeLayout)
        #expect(!active.canNavigateHistory)

        let restoring = PaneCommands(
            layout: .all,
            isFullScreen: false,
            isEditingText: false,
            isRestoring: true
        )
        #expect(!restoring.canChangeLayout)
        #expect(!restoring.canNavigateHistory)
    }
}
