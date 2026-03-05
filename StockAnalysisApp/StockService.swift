import Foundation

struct StockQuote {
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let changePercent: Double
    let volume: Int
    let marketCap: Double?
}

enum StockError: LocalizedError {
    case invalidSymbol
    case notFound
    case networkError(Error)
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidSymbol: return "無效的股票代號"
        case .notFound: return "找不到該股票，請確認代號是否正確"
        case .networkError(let error):
            return "網路錯誤：\(error.localizedDescription)"
        case .parseError: return "資料解析失敗"
        }
    }
}

class StockService {
    func getStockQuote(symbol: String) async throws -> StockQuote {
        let encoded =
            symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? symbol
        guard
            let url = URL(
                string:
                    "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)"
            )
        else {
            throw StockError.invalidSymbol
        }

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw StockError.networkError(error)
        }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200: break
            case 404: throw StockError.notFound
            default: throw StockError.networkError(URLError(.badServerResponse))
            }
        }

        return try parseResponse(data: data, symbol: symbol)
    }

    private func parseResponse(data: Data, symbol: String) throws -> StockQuote
    {
        guard
            let json = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            let chart = json["chart"] as? [String: Any],
            let results = chart["result"] as? [[String: Any]],
            let result = results.first,
            let meta = result["meta"] as? [String: Any]
        else {
            throw StockError.parseError
        }

        guard let price = meta["regularMarketPrice"] as? Double, price > 0 else {
            throw StockError.parseError
        }
        let previousClose = (meta["chartPreviousClose"] as? Double) ?? price
        let change = price - previousClose
        let changePercent =
            previousClose != 0 ? (change / previousClose) * 100 : 0
        let name =
            (meta["longName"] as? String)
            ?? (meta["shortName"] as? String)
            ?? symbol
        let volume = (meta["regularMarketVolume"] as? Int) ?? 0
        let marketCap = meta["marketCap"] as? Double

        return StockQuote(
            symbol: symbol.uppercased(),
            name: name,
            price: price,
            change: change,
            changePercent: changePercent,
            volume: volume,
            marketCap: marketCap
        )
    }
}
