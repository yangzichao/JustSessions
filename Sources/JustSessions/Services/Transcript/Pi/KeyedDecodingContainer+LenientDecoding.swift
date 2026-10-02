extension KeyedDecodingContainer {
    /// The value for `key`, or nil when it is missing, null, or of another type. A Pi session line is decoded field by
    /// field this way, so one odd field reads as missing instead of hiding the rest of the entry.
    func lenientlyDecode<Value: Decodable>(_ type: Value.Type, forKey key: Key) -> Value? {
        try? decodeIfPresent(type, forKey: key)
    }
}
