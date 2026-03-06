import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    var content: String
}

enum MessageRole {
    case user
    case assistant
}
