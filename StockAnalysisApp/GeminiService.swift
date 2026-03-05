import Foundation

enum GeminiError: LocalizedError {
    case missingAPIKey
    case networkError
    case invalidResponse
    case apiError(Int, String)
    case tooManyFunctionCalls

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "未設定 Gemini API Key。請在 Xcode Scheme 的環境變數中加入 GEMINI_API_KEY。"
        case .networkError:
            return "網路連線失敗"
        case .invalidResponse:
            return "收到無效的 API 回應"
        case .apiError(let code, let message):
            return "API 錯誤 (\(code)): \(message)"
        case .tooManyFunctionCalls:
            return "函式呼叫次數超過限制"
        }
    }
}

class GeminiService {
    private let apiKey: String
    private let baseURL =
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    private var conversationHistory: [[String: Any]] = []
    private let stockService = StockService()

    private let systemInstruction = """
        你是一個專業的股票分析助理，請用繁體中文回答。
        當用戶詢問特定股票時，使用 get_stock_quote 工具取得即時資料再分析。
        在回答結尾提醒：投資有風險，以上分析僅供參考。
        """

    private let tools: [[String: Any]] = [
        [
            "function_declarations": [
                [
                    "name": "get_stock_quote",
                    "description": "取得股票的即時報價資訊，包含股價、漲跌幅、成交量等",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "symbol": [
                                "type": "string",
                                "description":
                                    "股票代號，例如美股 AAPL、TSLA，台股 2330.TW，港股 9988.HK",
                            ]
                        ],
                        "required": ["symbol"],
                    ],
                ]
            ]
        ]
    ]

    init() {
        apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
    }

    func sendMessage(_ text: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw GeminiError.missingAPIKey
        }

        let userContent: [String: Any] = [
            "role": "user",
            "parts": [["text": text]],
        ]
        conversationHistory.append(userContent)

        do {
            return try await sendAndProcess(depth: 0)
        } catch {
            // Remove the user message on failure to keep history consistent
            conversationHistory.removeLast()
            throw error
        }
    }

    private func sendAndProcess(depth: Int) async throws -> String {
        guard depth < 5 else {
            throw GeminiError.tooManyFunctionCalls
        }

        let responseJSON = try await callGeminiAPI()

        guard
            let candidates = responseJSON["candidates"] as? [[String: Any]],
            let candidate = candidates.first,
            let content = candidate["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw GeminiError.invalidResponse
        }

        // Check if the model wants to call a function
        if let part = parts.first,
            let functionCall = part["functionCall"] as? [String: Any],
            let funcName = functionCall["name"] as? String
        {

            // Save model's function call to history
            conversationHistory.append(content)

            // Execute the function
            let args = functionCall["args"] as? [String: Any] ?? [:]
            let funcResult = await executeFunction(name: funcName, args: args)

            // Add function response to history
            let functionResponse: [String: Any] = [
                "role": "user",
                "parts": [
                    [
                        "functionResponse": [
                            "name": funcName,
                            "response": funcResult,
                        ]
                    ]
                ],
            ]
            conversationHistory.append(functionResponse)

            // Recurse to get the final text response
            return try await sendAndProcess(depth: depth + 1)
        }

        // Collect all text parts
        let responseText = parts.compactMap { $0["text"] as? String }.joined()

        // Save model's text response to history
        conversationHistory.append(content)

        return responseText.isEmpty ? "無法取得回應，請重試。" : responseText
    }

    private func callGeminiAPI() async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw GeminiError.networkError
        }

        let requestBody: [String: Any] = [
            "contents": conversationHistory,
            "tools": tools,
            "system_instruction": [
                "parts": [["text": systemInstruction]]
            ],
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GeminiError.networkError
        }

        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.networkError
        }

        guard http.statusCode == 200 else {
            let errorText =
                String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.apiError(http.statusCode, errorText)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else {
            throw GeminiError.invalidResponse
        }

        return json
    }

    private func executeFunction(name: String, args: [String: Any]) async
        -> [String: Any]
    {
        switch name {
        case "get_stock_quote":
            guard let symbol = args["symbol"] as? String else {
                return ["error": "缺少 symbol 參數"]
            }
            return await fetchStockQuote(symbol: symbol)
        default:
            return ["error": "未知的函式：\(name)"]
        }
    }

    private func fetchStockQuote(symbol: String) async -> [String: Any] {
        do {
            let quote = try await stockService.getStockQuote(symbol: symbol)
            var result: [String: Any] = [
                "symbol": quote.symbol,
                "name": quote.name,
                "price": quote.price,
                "change": quote.change,
                "changePercent": String(format: "%.2f%%", quote.changePercent),
                "volume": quote.volume,
            ]
            if let marketCap = quote.marketCap {
                result["marketCap"] = marketCap
            }
            return result
        } catch {
            return ["error": error.localizedDescription]
        }
    }
}
