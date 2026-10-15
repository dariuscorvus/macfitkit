import Foundation

public enum NumericInput {
    public static func accept(_ text: String, in range: ClosedRange<Double>) -> Double? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let number = Double(text), number.isFinite else { return nil }
        return min(range.upperBound, max(range.lowerBound, number))
    }
}
