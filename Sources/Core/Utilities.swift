import Foundation

public enum CarpdmDateCodec {
    private static func makeFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    public static func string(from date: Date) -> String {
        makeFormatter().string(from: date)
    }

    public static func date(from string: String) -> Date {
        makeFormatter().date(from: string) ?? Date()
    }
}

public extension String {
    func slugified() -> String {
        let lowered = lowercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let filtered = lowered.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        let collapsed = String(filtered).split(whereSeparator: \.isWhitespace).joined(separator: "-")
        return collapsed.isEmpty ? "task" : collapsed
    }

    func trimmingTrailingNewlines() -> String {
        var result = self
        while result.last?.isNewline == true {
            result.removeLast()
        }
        return result
    }
}
