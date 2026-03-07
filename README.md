# StockAnalysisApp

一款 iOS 股票分析 AI 助理 App，結合 Gemini AI 與即時股市資料，提供美股與台股的深度分析。

## Demo

[![Demo Video](https://img.youtube.com/vi/oVEhD4r3inM/0.jpg)](https://youtube.com/shorts/oVEhD4r3inM?feature=share)

## 功能

- 與 AI 助理即時對話，詢問股票相關問題
- 自動呼叫 MCP Server 取得即時股市資料（股價、估值、技術指標、基本面、股息、法人等）
- 支援美股（如 AAPL、NVDA）與台股（如 2330.TW、2454.TW）
- 串流回應，逐字顯示分析結果
- Markdown 格式渲染

## 技術架構

**使用者** 輸入問題
→ **App（SwiftUI）** 顯示對話介面
→ **Gemini AI** 判斷需要哪些股市資料
→ **MCP Server** 即時向 Yahoo Finance 查詢
→ **Gemini AI** 根據查回的資料撰寫分析
→ **App** 逐字串流顯示回答

### 使用技術

- **SwiftUI** — UI 框架
- **Firebase AI (Gemini 2.5 Flash)** — AI 對話與 Function Calling
- **MCP (Model Context Protocol)** — 連接即時股市資料工具
- **Yahoo Finance API** — 股市資料來源（透過 MCP Server）

