import Foundation

// MARK: - Error Types

enum MCPError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(String)
    case toolError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "MCP Server URL 無效"
        case .networkError(let error):
            return "MCP 網路錯誤：\(error.localizedDescription)"
        case .invalidResponse:
            return "MCP Server 回傳無效的回應格式"
        case .serverError(let message):
            return "MCP Server 錯誤：\(message)"
        case .toolError(let message):
            return "MCP 工具執行失敗：\(message)"
        case .timeout:
            return "MCP Server 請求逾時（工具執行需要較長時間，請稍後再試）"
        }
    }
}

// MARK: - Response Models

private struct MCPResponse: Decodable {
    let jsonrpc: String
    let id: Int?
    let result: MCPResult?
    let error: MCPResponseError?
}

private struct MCPResult: Decodable {
    let content: [MCPContentItem]
    let isError: Bool?
}

private struct MCPContentItem: Decodable {
    let type: String
    let text: String?
}

private struct MCPResponseError: Decodable {
    let code: Int?
    let message: String
}

// MARK: - MCPService

class MCPService {
    private let baseURL: String
    /// 60 秒 timeout，因為 MCP tools（yfinance、網頁搜尋等）執行較慢
    private let timeoutInterval: TimeInterval = 60
    private var requestID: Int = 0

    init(baseURL: String = "http://127.0.0.1:8000/mcp") {
        self.baseURL = baseURL
    }

    // MARK: - Public Interface

    /// 呼叫 MCP Server 上的指定工具，回傳工具的文字輸出。
    func callTool(name: String, arguments: [String: Any]) async throws -> String {
        requestID += 1
        let currentID = requestID

        guard let url = URL(string: baseURL) else {
            throw MCPError.invalidURL
        }

        let requestBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": currentID,
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": arguments,
            ],
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = bodyData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw MCPError.timeout
        } catch {
            throw MCPError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw MCPError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "（無回應內容）"
            throw MCPError.serverError("HTTP \(http.statusCode)：\(body)")
        }

        return try parseResponse(data: data)
    }

    // MARK: - Private Helpers

    private func parseResponse(data: Data) throws -> String {
        let mcpResponse: MCPResponse
        do {
            mcpResponse = try JSONDecoder().decode(MCPResponse.self, from: data)
        } catch {
            throw MCPError.invalidResponse
        }

        // JSON-RPC error block
        if let rpcError = mcpResponse.error {
            throw MCPError.serverError(rpcError.message)
        }

        guard let result = mcpResponse.result else {
            throw MCPError.invalidResponse
        }

        // MCP tool returned isError == true
        if result.isError == true {
            let errorText = result.content.first?.text ?? "工具回傳未知錯誤"
            throw MCPError.toolError(errorText)
        }

        // Collect all text items from content array
        let text = result.content
            .filter { $0.type == "text" }
            .compactMap { $0.text }
            .joined(separator: "\n")

        guard !text.isEmpty else {
            throw MCPError.invalidResponse
        }

        return text
    }
}
