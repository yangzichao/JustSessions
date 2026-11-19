extension KeyedDecodingContainer {
    func lenientlyDecode<Value: Decodable>(_ type: Value.Type, forKey key: Key) -> Value? {
        try? decodeIfPresent(type, forKey: key)
    }
}
