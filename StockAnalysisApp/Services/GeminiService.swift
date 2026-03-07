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
    private let mcpService: MCPService

    private static var systemPrompt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY/MM/dd"
        let today = formatter.string(from: Date())
        return """
    你是一位專業的股票分析助理。
    【限制準則】：
    1. 你『只能』回答與股票、股市、財報、總體經濟或金融投資相關的問題。
    2. 如果使用者詢問與上述無關的話題（例如：程式開發、日常生活、食譜、閒聊等），請禮貌地拒絕，並說明你的專業僅限於股市分析。
    3. 請一律使用繁體中文回答。

    【股票代碼規則】：
    - 台灣股票代碼格式為「數字.TW」，例如：台積電=2330.TW、聯發科=2454.TW、鴻海=2317.TW、台達電=2308.TW、聯電=2303.TW、富邦金=2881.TW、國泰金=2882.TW
    - 美股直接使用代碼，例如：AAPL、NVDA、MSFT、TSLA
    - 呼叫工具前，請務必確認該公司『正確的股票代碼』，不可混淆不同公司

    【工具使用規則】：
    當使用者詢問任何特定股票時，你『必須』先呼叫工具取得即時資料，不可直接使用你的訓練資料回答。
    - 詢問股價、漲跌 → 呼叫 get_stock_price
    - 詢問分析、基本面、技術面、是否值得投資等 → 呼叫 get_stock_report
    禁止在未呼叫工具的情況下，直接回答與特定股票數據相關的問題。

    【回答格式】：
    當回答涉及特定股票時，請在回答的最開頭依序列出：
    第一行：「[公司名稱]分析報告 － \(today)」
    第二行：「📌 [公司名稱]（[股票代碼]）｜現價：[價格] [幣別]」
    然後再進行分析。

    【結尾警語】：
    每次回答結束時，請務必換行並加上：『投資有風險，以上分析僅供參考。』
    """
    }

    private static let mcpTools: [FunctionDeclaration] = [
        FunctionDeclaration(
            name: "get_stock_price",
            description: "取得股票最新價格資訊。適用美股（如 'AAPL'）與台股（如 '2330.TW'）。",
            parameters: ["ticker": .string(description: "股票代碼，例如 'AAPL' 或 '2330.TW'")]
        ),
        FunctionDeclaration(
            name: "get_valuation_analysis",
            description: "取得股票估值分析，包含本益比（P/E）、葛拉漢估值、PEG 等。",
            parameters: ["ticker": .string(description: "股票代碼，例如 'AAPL' 或 '2330.TW'")]
        ),
        FunctionDeclaration(
            name: "get_technical_indicators",
            description: "取得技術指標，包含 MA50/MA200 均線、RSI、52 週高低點。",
            parameters: ["ticker": .string(description: "股票代碼，例如 'AAPL' 或 '2330.TW'")]
        ),
        FunctionDeclaration(
            name: "get_fundamental_health",
            description: "取得基本面健康狀況，包含營收、EPS、利潤率、負債、自由現金流。",
            parameters: ["ticker": .string(description: "股票代碼，例如 'AAPL' 或 '2330.TW'")]
        ),
        FunctionDeclaration(
            name: "get_dividend_info",
            description: "取得股息資訊，包含殖利率、配息率、近 5 年股息歷史。",
            parameters: ["ticker": .string(description: "股票代碼，例如 'AAPL' 或 '2330.TW'")]
        ),
        FunctionDeclaration(
            name: "get_earnings_call_summary",
            description: "取得法說會摘要，包含 EPS 歷史、分析師預估與網路搜尋資訊。",
            parameters: ["ticker": .string(description: "股票代碼，例如 'AAPL' 或 '2330.TW'")]
        ),
        FunctionDeclaration(
            name: "get_institutional_trading",
            description: "取得法人買賣資訊。台股：三大法人；美股：機構持股狀況。",
            parameters: ["ticker": .string(description: "股票代碼，例如 'AAPL' 或 '2330.TW'")]
        ),
        FunctionDeclaration(
            name: "get_stock_report",
            description: "取得股票綜合分析報告，整合所有面向的分析（價格、估值、技術指標、基本面、股息、法說會、法人）。",
            parameters: ["ticker": .string(description: "股票代碼，例如 'AAPL' 或 '2330.TW'")]
        ),
    ]

    init() {
        mcpService = MCPService()
        let model = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModel(
            modelName: "gemini-2.5-flash",
            tools: [.functionDeclarations(GeminiService.mcpTools)],
            systemInstruction: ModelContent(
                role: "system",
                parts: GeminiService.systemPrompt
            )
        )
        chat = model.startChat()
    }

    func sendMessage(_ text: String) async throws -> String {
        var response = try await chat.sendMessage(text)
        for _ in 0..<5 {
            let calls = response.functionCalls
            guard !calls.isEmpty else {
                return response.text ?? "無法取得回應，請重試。"
            }
            let responseParts = await executeFunctionCalls(calls)
            response = try await chat.sendMessage(
                [ModelContent(role: "function", parts: responseParts)]
            )
        }
        throw GeminiError.invalidResponse
    }

    func sendMessageStream(_ text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var stream = try chat.sendMessageStream(text)
                    for _ in 0..<5 {
                        var accumulatedCalls: [FunctionCallPart] = []
                        for try await chunk in stream {
                            if let t = chunk.text { continuation.yield(t) }
                            accumulatedCalls.append(contentsOf: chunk.functionCalls)
                        }
                        if accumulatedCalls.isEmpty {
                            continuation.finish()
                            return
                        }
                        let responseParts = await executeFunctionCalls(accumulatedCalls)
                        stream = try chat.sendMessageStream(
                            [ModelContent(role: "function", parts: responseParts)]
                        )
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func executeFunctionCalls(_ calls: [FunctionCallPart]) async -> [FunctionResponsePart] {
        var parts: [FunctionResponsePart] = []
        for call in calls {
            do {
                let args = jsonObjectToAny(call.args)
                let result = try await mcpService.callTool(name: call.name, arguments: args)
                parts.append(FunctionResponsePart(name: call.name, response: ["result": .string(result)]))
            } catch {
                parts.append(FunctionResponsePart(name: call.name, response: ["error": .string(error.localizedDescription)]))
            }
        }
        return parts
    }

    private func jsonObjectToAny(_ obj: JSONObject) -> [String: Any] {
        obj.mapValues { jsonValueToAny($0) }
    }

    private func jsonValueToAny(_ value: JSONValue) -> Any {
        switch value {
        case .null: return NSNull()
        case .number(let d): return d
        case .string(let s): return s
        case .bool(let b): return b
        case .object(let o): return o.mapValues { jsonValueToAny($0) }
        case .array(let a): return a.map { jsonValueToAny($0) }
        }
    }
}
