import Foundation
import Observation

@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false

    private let geminiService = GeminiService()

    init() {
        messages.append(
            ChatMessage(
                role: .assistant,
                content:
                    "您好！我是股票分析 AI 助理 📈\n\n您可以問我：\n• 台積電現在股價多少？\n• Apple 的股票值得買嗎？\n• 特斯拉最近表現如何？"
            )
        )
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, content: text))
        isLoading = true

        do {
            let response = try await geminiService.sendMessage(text)
            messages.append(ChatMessage(role: .assistant, content: response))
        } catch {
            messages.append(
                ChatMessage(
                    role: .assistant,
                    content: "發生錯誤：\(error.localizedDescription)"
                )
            )
        }

        isLoading = false
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
}

enum MessageRole {
    case user
    case assistant
}
