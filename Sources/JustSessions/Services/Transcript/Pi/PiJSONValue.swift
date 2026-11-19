import Foundation

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
