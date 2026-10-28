import Foundation
import MediaViewerLocalization
import Testing

@Suite("値を含む文")
struct ValueSentenceTests {
    @Test("値は書式として解釈されず、文字どおりに入る")
    func valuesAreLiteral() {
        let samples = ["%@", "%d", "{0}", "%1$@", "نص", "טקסט", "100%"]
        for language in LocalizationTestSupport.languages {
            let localizer = LocalizationTestSupport.localizer(language)
            for key in TextKey.allCases where key.arguments.contains(.text) {
                for sample in samples {
                    let values = key.arguments.map { argument -> TextValue in
                        switch argument {
                        case .text: return .text(sample)
                        case .count: return .count(3)
                        case .number: return .number(3)
                        }
                    }
                    let output = localizer.text(key, values)
                    #expect(output.contains(sample), "\(language): \(key.rawValue) に \(sample) が入らない: \(output)")
                }
            }
        }
    }
}
