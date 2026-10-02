import Foundation

/// The fields `PiEntryLink` reads from a line it has to parse because its start is not in Pi's own layout. Every
/// field is optional and one of another type reads as missing.
struct PiEntryLinkRecord: Decodable {
    /// Only a message's role is needed to tell whether the preview might show it.
    struct Message: Decodable {
        private enum CodingKeys: String, CodingKey {
            case role
        }

        let role: String?

        init(from decoder: any Decoder) throws {
            role = try decoder.container(keyedBy: CodingKeys.self).lenientlyDecode(String.self, forKey: .role)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case parentID = "parentId"
        case message
    }

    let type: String?
    let id: String?
    let parentID: String?
    let message: Message?

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.lenientlyDecode(String.self, forKey: .type)
        id = container.lenientlyDecode(String.self, forKey: .id)
        parentID = container.lenientlyDecode(String.self, forKey: .parentID)
        message = container.lenientlyDecode(Message.self, forKey: .message)
    }
}
