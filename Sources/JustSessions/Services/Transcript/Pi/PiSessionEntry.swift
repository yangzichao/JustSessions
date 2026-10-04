import Foundation

/// The fields of a Pi session entry that the preview shows, decoded from one line of the session file. Every field is
/// optional and one of another type reads as missing, so an odd field never hides the rest of the entry.
struct PiSessionEntry: Decodable {
    /// The message of a `message` entry. Only the fields of the roles the preview shows are kept.
    struct Message: Decodable {
        /// A message's content: plain text, or parts such as text, images, thinking, and tool calls.
        enum Content: Decodable {
            case text(String)
            case parts([Part])

            /// Fails for anything but a string or an array of objects, so that content reads as missing.
            init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let text = try? container.decode(String.self) {
                    self = .text(text)
                } else {
                    self = .parts(try container.decode([Part].self))
                }
            }
        }

        /// One part of a message's content.
        struct Part: Decodable {
            private enum CodingKeys: String, CodingKey {
                case type, text, name, arguments, data
            }

            /// Such as `text`, `image`, `thinking`, or `toolCall`.
            let type: String?
            let text: String?
            /// The tool a `toolCall` part calls.
            let name: String?
            /// The arguments of a `toolCall` part, in whatever shape the tool takes them.
            let arguments: PiJSONValue?
            /// The base64 of an `image` part.
            let data: String?

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                type = container.lenientlyDecode(String.self, forKey: .type)
                text = container.lenientlyDecode(String.self, forKey: .text)
                name = container.lenientlyDecode(String.self, forKey: .name)
                arguments = container.lenientlyDecode(PiJSONValue.self, forKey: .arguments)
                data = container.lenientlyDecode(String.self, forKey: .data)
            }

            /// The image of an `image` part; nil for other parts and for one without base64.
            var image: TranscriptImage? {
                guard type == "image", let data else { return nil }
                return TranscriptImage(base64Encoded: data)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case role, content, command, excludeFromContext, stopReason, errorMessage
        }

        /// Such as `user`, `assistant`, `bashExecution`, or `toolResult`.
        let role: String?
        let content: Content?
        /// The command of a `bashExecution` message.
        let command: String?
        /// True for a `bashExecution` message run with `!!`, whose output is kept out of the model's context.
        let excludeFromContext: Bool?
        /// Why an assistant message ended; `error` when the request failed.
        let stopReason: String?
        let errorMessage: String?

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            role = container.lenientlyDecode(String.self, forKey: .role)
            content = container.lenientlyDecode(Content.self, forKey: .content)
            command = container.lenientlyDecode(String.self, forKey: .command)
            // Like a JSON dictionary's `as? Bool`, which also reads the numbers 0 and 1 as false and true.
            excludeFromContext = container.lenientlyDecode(Bool.self, forKey: .excludeFromContext)
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

    /// Such as `message`, `compaction`, `branch_summary`, or `model_change`.
    let type: String?
    /// An ISO 8601 date.
    let timestamp: String?
    /// Present for `message` entries.
    let message: Message?

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.lenientlyDecode(String.self, forKey: .type)
        timestamp = container.lenientlyDecode(String.self, forKey: .timestamp)
        message = container.lenientlyDecode(Message.self, forKey: .message)
    }

    /// What the preview shows this entry as, or nil when it shows nothing for it.
    var previewedEntry: PiPreviewedEntry? {
        type.flatMap { PiPreviewedEntry(entryType: $0, role: message?.role) }
    }
}
