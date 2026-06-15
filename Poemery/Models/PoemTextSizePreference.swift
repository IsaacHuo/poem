import Foundation

enum PoemTextSizePreference {
    static let storageKey = "poemery.display.poemTextSize"
    static let defaultValue: Double = 22
    static let range: ClosedRange<Double> = 18...28
    static let step: Double = 1

    static func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    static func displayValue(for value: Double) -> String {
        "\(Int(clamped(value).rounded())) pt"
    }
}
