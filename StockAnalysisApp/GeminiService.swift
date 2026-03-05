import Foundation

enum GeminiError: LocalizedError {
    case missingAPIKey
    case networkError(Error)
    case invalidResponse
    case apiError(Int, String)
    case tooManyFunctionCalls

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "未設定 Gemini API Key。請在 Xcode Scheme 的環境變數中加入 GEMINI_API_KEY。"
        case .networkError(let error):
            return "網路連線失敗：\(error.localizedDescription)"
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
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent"
    private var conversationHistory: [[String: Any]] = []
    private let mcpService = MCPService()

    private let systemInstruction = """
        你是一個專業的股票分析助理，請用繁體中文回答。
        當用戶詢問特定股票時，請根據問題類型選擇適合的工具取得資料後再分析：
        - get_stock_price：取得最新股價（快速報價）
        - get_valuation_analysis：估值分析（P/E、Graham Number、PEG 等，判斷是否高估）
        - get_technical_indicators：技術指標（MA50/MA200、RSI、52 週高低，判斷趨勢）
        - get_fundamental_health：基本面健康度（營收成長、EPS、毛利率、現金流）
        - get_dividend_info：股息分析（殖利率、配息率、配息歷史）
        - get_earnings_call_summary：法說會摘要（EPS 達標、分析師預估、目標價）
        - get_institutional_trading：機構法人持股（三大法人買賣超）
        - get_volume_analysis：交易量與散戶／法人動向分析
        - get_stock_report：綜合投資報告（整合所有面向，適合全面分析）
        在回答結尾提醒：投資有風險，以上分析僅供參考。
        """

    private let tools: [[String: Any]] = [
        [
            "function_declarations": [
                [
                    "name": "get_stock_price",
                    "description": "取得股票最新即時價格",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "ticker": [
                                "type": "string",
                                "description": "股票代號，例如 AAPL、TSLA、2330.TW、9988.HK",
                            ]
                        ],
                        "required": ["ticker"],
                    ],
                ],
                [
                    "name": "get_valuation_analysis",
                    "description": "估值分析：判斷股票目前是否被高估，包含 P/E 歷史百分位、Graham Number、Forward/Trailing P/E 比較、PEG Ratio",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "ticker": [
                                "type": "string",
                                "description": "股票代號，例如 AAPL、TSLA、2330.TW",
                            ]
                        ],
                        "required": ["ticker"],
                    ],
                ],
                [
                    "name": "get_technical_indicators",
                    "description": "技術指標分析：MA50/MA200 均線、RSI、52 週高低價，判斷目前趨勢與超買超賣狀態",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "ticker": [
                                "type": "string",
                                "description": "股票代號，例如 AAPL、TSLA、2330.TW",
                            ]
                        ],
                        "required": ["ticker"],
                    ],
                ],
                [
                    "name": "get_fundamental_health",
                    "description": "基本面健康度分析：營收成長、EPS、毛利率、現金流等財務指標",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "ticker": [
                                "type": "string",
                                "description": "股票代號，例如 AAPL、TSLA、2330.TW",
                            ]
                        ],
                        "required": ["ticker"],
                    ],
                ],
                [
                    "name": "get_dividend_info",
                    "description": "股息分析：殖利率、配息率、歷史配息紀錄",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "ticker": [
                                "type": "string",
                                "description": "股票代號，例如 AAPL、TSLA、2330.TW",
                            ]
                        ],
                        "required": ["ticker"],
                    ],
                ],
                [
                    "name": "get_earnings_call_summary",
                    "description": "法說會摘要：EPS 達標情況、分析師預估、目標價區間",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "ticker": [
                                "type": "string",
                                "description": "股票代號，例如 AAPL、TSLA、2330.TW",
                            ]
                        ],
                        "required": ["ticker"],
                    ],
                ],
                [
                    "name": "get_institutional_trading",
                    "description": "機構法人持股分析：三大法人買賣超、機構持股比例變化",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "ticker": [
                                "type": "string",
                                "description": "股票代號，例如 AAPL、TSLA、2330.TW",
                            ]
                        ],
                        "required": ["ticker"],
                    ],
                ],
                [
                    "name": "get_volume_analysis",
                    "description": "交易量分析：成交量趨勢、散戶與法人動向研判",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "ticker": [
                                "type": "string",
                                "description": "股票代號，例如 AAPL、TSLA、2330.TW",
                            ]
                        ],
                        "required": ["ticker"],
                    ],
                ],
                [
                    "name": "get_stock_report",
                    "description": "綜合投資報告：整合股價、估值、技術、基本面、股息等所有面向，適合需要全面分析時使用",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "ticker": [
                                "type": "string",
                                "description": "股票代號，例如 AAPL、TSLA、2330.TW",
                            ]
                        ],
                        "required": ["ticker"],
                    ],
                ],
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
        let snapshotCount = conversationHistory.count
        conversationHistory.append(userContent)

        do {
            return try await sendAndProcess(depth: 0)
        } catch {
            // Roll back all history entries added during this request
            conversationHistory.removeSubrange(snapshotCount...)
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
        guard let url = URL(string: baseURL) else {
            throw GeminiError.networkError(URLError(.badURL))
        }

        let requestBody: [String: Any] = [
            "contents": conversationHistory,
            "tools": tools,
            "system_instruction": [
                "parts": [["text": systemInstruction]]
            ],
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = bodyData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw GeminiError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.networkError(URLError(.badServerResponse))
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
        let mcpTools: Set<String> = [
            "get_stock_price",
            "get_valuation_analysis",
            "get_technical_indicators",
            "get_fundamental_health",
            "get_dividend_info",
            "get_earnings_call_summary",
            "get_institutional_trading",
            "get_volume_analysis",
            "get_stock_report",
        ]

        guard mcpTools.contains(name) else {
            return ["error": "未知的函式：\(name)"]
        }

        guard let ticker = args["ticker"] as? String else {
            return ["error": "缺少 ticker 參數"]
        }

        return await callMCPTool(name: name, ticker: ticker)
    }

    private func callMCPTool(name: String, ticker: String) async -> [String: Any] {
        do {
            let text = try await mcpService.callTool(
                name: name,
                arguments: ["ticker": ticker]
            )
            return ["result": text]
        } catch {
            return ["error": error.localizedDescription]
        }
    }
}
