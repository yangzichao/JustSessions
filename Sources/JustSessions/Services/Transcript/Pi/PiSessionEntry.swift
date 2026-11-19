import Foundation

struct PiSessionEntry: Decodable {
    struct Message: Decodable {
        enum Content: Decodable {
            case text(String)
            case parts([Part])

            init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let text = try? container.decode(String.self) {
                    self = .text(text)
                } else {
                    self = .parts(try container.decode([Part].self))
                }
            }
        }

        struct Part: Decodable {
            private enum CodingKeys: String, CodingKey {
                case type, text, name, arguments, data
            }

            let type: String?
            let text: String?
            let name: String?
            let arguments: PiJSONValue?
            let data: String?

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                type = container.lenientlyDecode(String.self, forKey: .type)
                text = container.lenientlyDecode(String.self, forKey: .text)
                name = container.lenientlyDecode(String.self, forKey: .name)
                arguments = container.lenientlyDecode(PiJSONValue.self, forKey: .arguments)
                data = container.lenientlyDecode(String.self, forKey: .data)
            }

            var imageBase64: String? {
                type == "image" ? data : nil
            }
        }

        private enum CodingKeys: String, CodingKey {
            case role, content, command, excludeFromContext, stopReason, errorMessage
        }

        let role: String?
        let content: Content?
        let command: String?
        let excludeFromContext: Bool?
        let stopReason: String?
        let errorMessage: String?

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            role = container.lenientlyDecode(String.self, forKey: .role)
            content = container.lenientlyDecode(Content.self, forKey: .content)
            command = container.lenientlyDecode(String.self, forKey: .command)
            excludeFromContext =
                container.lenientlyDecode(Bool.self, forKey: .excludeFromContext)
                ?? container.lenientlyDecode(Double.self, forKey: .excludeFromContext).flatMap { number in
                    number == 1 ? true : number == 0 ? false : nil
                }
            stopReason = container.lenientlyDecode(String.self, forKey: .stopReason)
            errorMessage = container.lenientlyDecode(String.self, forKey: .errorMessage)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, timestamp, message
    }

    let type: String?
    let timestamp: String?
    let message: Message?

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.lenientlyDecode(String.self, forKey: .type)
        timestamp = container.lenientlyDecode(String.self, forKey: .timestamp)
        message = container.lenientlyDecode(Message.self, forKey: .message)
    }

    var previewedEntry: PiPreviewedEntry? {
        type.flatMap { PiPreviewedEntry(entryType: $0, role: message?.role) }
    }
}
