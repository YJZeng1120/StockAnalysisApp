import FirebaseAI
import Foundation

enum GeminiError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "收到無效的 API 回應"
        }
    }
}

class GeminiService {
    private let chat: Chat

    private static let systemPrompt = """
        你是一個專業的股票分析助理，請用繁體中文回答。
        在回答結尾提醒：投資有風險，以上分析僅供參考。
        """

    init() {
        let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: "gemini-2.5-flash-lite",
        )
        chat = model.startChat()
    }

    func sendMessage(_ text: String) async throws -> String {
        let response = try await chat.sendMessage(text)
        guard let text = response.text else {
            throw GeminiError.invalidResponse
        }
        return text.isEmpty ? "無法取得回應，請重試。" : text
    }
}
