import Foundation

enum KiroTranscriptTimestamp {
    /// Prompts may carry an epoch timestamp in `data.meta`; other records can carry an ISO timestamp.
    static func date(in record: [String: Any], data: [String: Any]) -> Date? {
        let metadata = data["meta"] as? [String: Any]
        let value = metadata?["timestamp"] ?? data["timestamp"] ?? record["timestamp"]
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            let epochValue = number.doubleValue
            guard epochValue.isFinite else { return nil }
            return Date(timeIntervalSince1970: abs(epochValue) >= 100_000_000_000 ? epochValue / 1_000 : epochValue)
        }
        return ConversationMetadata.date(value)
    }
}
