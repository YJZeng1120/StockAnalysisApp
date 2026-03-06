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
        你是一位專業的股票分析助理。
        【限制準則】：
        1. 你『只能』回答與股票、股市、財報、總體經濟或金融投資相關的問題。
        2. 如果使用者詢問與上述無關的話題（例如：程式開發、日常生活、食譜、閒聊等），請禮貌地拒絕，並說明你的專業僅限於股市分析。
        3. 請一律使用繁體中文回答。

        【結尾警語】：
        每次回答結束時，請務必換行並加上：『投資有風險，以上分析僅供參考。』
        """

    init() {
        let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: "gemini-2.5-flash-lite",
            systemInstruction: ModelContent(
                role: "system",
                parts: GeminiService.systemPrompt
            )
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
