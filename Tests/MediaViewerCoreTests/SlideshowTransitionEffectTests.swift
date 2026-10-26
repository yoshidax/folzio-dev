import Testing
@testable import MediaViewerCore

@Suite("SlideshowTransitionEffect")
struct SlideshowTransitionEffectTests {
    @Test("保存値と視差効果を減らす設定での置き換え")
    func effects() {
        #expect(SlideshowTransitionEffect.allCases.map(\.rawValue) == ["none", "crossfade", "slide", "zoom"])
        for effect in SlideshowTransitionEffect.allCases {
            #expect(effect.effective(reduceMotion: false) == effect)
            let expected: SlideshowTransitionEffect = effect == .slide || effect == .zoom ? .crossfade : effect
            #expect(effect.effective(reduceMotion: true) == expected)
        }
    }
}
