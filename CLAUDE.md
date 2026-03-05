# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 建置與執行

這是 Xcode 專案，透過 Xcode 或 `xcodebuild` 進行建置與執行。

```bash
# 建置
xcodebuild -project StockAnalysisApp.xcodeproj -scheme StockAnalysisApp -destination 'platform=iOS Simulator,name=iPhone 16' build

# 清除
xcodebuild -project StockAnalysisApp.xcodeproj -scheme StockAnalysisApp clean
```

目前沒有單元測試。透過 Xcode（`Cmd+R`）在實機或 Simulator 上執行。

## API Key 設定

App 從 process 環境變數讀取 `GEMINI_API_KEY`，設定位置：
**Xcode → Edit Scheme → Run → Arguments → Environment Variables**

## 架構

單一 target 的 iOS App，所有原始碼放在 `StockAnalysisApp/` 資料夾。專案使用 `PBXFileSystemSynchronizedRootGroup`（Xcode 16+ 功能），**新增 `.swift` 檔案時不需要修改 `project.pbxproj`**，Xcode 會自動納入編譯。

### 資料流

```
ContentView  →  ChatViewModel  →  GeminiService  →  Gemini REST API
                                        ↓（偵測到 function call）
                                  StockService  →  Yahoo Finance API
                                        ↓
                                  GeminiService  →  最終文字回應
```

### 各檔案職責

- **`GeminiService.swift`** — 透過 REST API 呼叫 Gemini 1.5 Flash。以 `conversationHistory: [[String: Any]]` 維護多輪對話。實作 Function Calling 迴圈（最多遞迴 5 次）：若 Gemini 回傳 `functionCall`，則執行對應函式並再次呼叫 API，直到取得文字回應為止。
- **`StockService.swift`** — 從 Yahoo Finance v8/chart 端點取得即時股票報價，不需要 API key。
- **`ChatViewModel.swift`** — `@Observable` class，管理 `messages`、`inputText`、`isLoading` 狀態，由 `ContentView` 以 `@State` 持有。
- **`ContentView.swift`** — 聊天介面。`init` 接受外部傳入的 `ChatViewModel`，方便 Preview 注入假資料。

### 專案設定

- 最低支援版本：**iOS 18.0**
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`：所有型別預設為 `@MainActor`
- `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- 無第三方套件（使用 URLSession 直接呼叫 REST API，未使用 Gemini Swift SDK）
