import Foundation
import Observation

@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var streamingMessageId: UUID? = nil
    var streamingToken: Int = 0

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

        let assistantMessage = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)
        streamingMessageId = assistantMessage.id

        do {
            let stream = geminiService.sendMessageStream(text)
            for try await chunk in stream {
                if let idx = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                    messages[idx].content += chunk
                    streamingToken += 1
                }
            }
        } catch {
            if let idx = messages.firstIndex(where: { $0.id == streamingMessageId }) {
                messages[idx].content = "發生錯誤：\(error.localizedDescription)"
            }
        }

        streamingMessageId = nil
        isLoading = false
    }
}
