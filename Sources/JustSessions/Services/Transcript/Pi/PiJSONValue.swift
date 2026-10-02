import Foundation

/// Any JSON value, for the parts of a Pi session line whose shape is up to the tool that wrote it, such as a tool
/// call's arguments.
enum PiJSONValue: Decodable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([PiJSONValue])
    case object([String: PiJSONValue])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let text = try? container.decode(String.self) {
            self = .string(text)
        } else if let flag = try? container.decode(Bool.self) {
            self = .bool(flag)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let elements = try? container.decode([PiJSONValue].self) {
            self = .array(elements)
        } else {
            self = .object(try container.decode([String: PiJSONValue].self))
        }
    }

    /// The value in the shape of `JSONSerialization`'s output, for code that reads JSON as `[String: Any]`: objects
    /// become dictionaries, arrays become `[Any]`, and null becomes `NSNull`. Unlike `JSONSerialization`'s `NSNumber`,
    /// a number is a `Double` and a boolean is a `Bool`, so `as? Int` fails on a whole number.
    var foundationValue: Any {
        switch self {
        case .null: NSNull()
        case .bool(let flag): flag
        case .number(let number): number
        case .string(let text): text
        case .array(let elements): elements.map(\.foundationValue)
        case .object(let fields): fields.mapValues(\.foundationValue)
        }
    }
}
