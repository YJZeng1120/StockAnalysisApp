# StockAnalysisApp iOS Code Reviewer Memory

## Project Config (Verified)
- iOS deployment target: 26.0 (CLAUDE.md says 18.0, actual pbxproj says 26.0)
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types implicitly @MainActor
- `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- No third-party packages; URLSession directly calls Gemini REST API
- `PBXFileSystemSynchronizedRootGroup` — new .swift files auto-included, no pbxproj edits needed

## Architecture & File Map
| File | Role |
|------|------|
| `StockAnalysisApp.swift` | @main App entry point |
| `ContentView.swift` | Chat UI + MessageBubble + LoadingBubble sub-views |
| `ChatViewModel.swift` | @Observable state: messages, inputText, isLoading; also defines ChatMessage + MessageRole |
| `GeminiService.swift` | Gemini REST API, Function Calling loop (max depth 5), conversationHistory |
| `StockService.swift` | Yahoo Finance v8/chart fetch + parse; also defines StockQuote + StockError |

## Known Design Patterns & Decisions
- `ContentView.init(viewModel:)` accepts external ViewModel for Preview injection — intentional DI pattern
- `GeminiService` uses `[String: Any]` for JSON (not Codable) — deliberate choice for flexible Gemini API schema
- `conversationHistory` is a `[[String: Any]]` mutable array maintained across sendMessage() calls
- Function Calling: recursive `sendAndProcess(depth:)` up to depth 5
- On error in sendMessage(), the last userContent is removed from history to keep consistency

## Issues Found in Full Code Review (2026-03-05)

### Critical
1. **GeminiService is a class without actor isolation annotation** — under MainActor global isolation,
   `conversationHistory` mutations run on MainActor but `async throws` network calls suspend off it,
   creating potential for interleaved calls to corrupt history if user sends rapid messages.
2. **API Key appended to URL query string** — `?key=\(apiKey)` will appear in HTTP logs, proxy logs,
   and potentially server access logs. Should use `x-goog-api-key` header instead.
3. **`parseResponse` silently falls back** — `price = (meta["regularMarketPrice"] as? Double) ?? 0`
   returns 0 for missing price instead of throwing; `previousClose` fallback to `price` hides data errors.

### Warnings
4. **`conversationHistory.removeLast()` on error is fragile** — if sendAndProcess partially appends
   (model content + functionResponse) before failing, only the user message is removed, leaving orphaned
   history entries.
5. **No request timeout set on URLRequest** — both GeminiService and StockService use default timeout
   (~60s); long Gemini calls will block isLoading indefinitely.
6. **`StockService` and `GeminiService` are `class` but stateless/single-owner** — could be `struct`
   (StockService is pure) or `actor` (GeminiService has mutable state).
7. **`ChatMessage.timestamp` is unused** — declared but never displayed in UI.
8. **`LoadingBubble` animation uses `.repeatForever()` without `autoreverses: false`** — dots jump
   rather than smoothly reversing; minor but visible UX issue.
9. **Preview has commented-out dead code** — lines 170-172 in ContentView.swift.
10. **`GeminiError.networkError` has no associated value** — loses original URLSession error info,
    making debugging harder. Contrast with StockError.networkError(Error) which correctly wraps it.

### Suggestions
11. Use `Codable` structs for Gemini API response parsing instead of `[String: Any]` casting chains.
12. Add `Task.isCancelled` checks inside `sendAndProcess` loop for proper cancellation support.
13. Extract magic numbers: bubble corner radius (18), spacing (12, 48), animation duration (0.45, 0.15).
14. `ChatMessage` and `MessageRole` belong in their own file, not ChatViewModel.swift.
15. `StockQuote` and `StockError` belong in their own file, not StockService.swift.

## Coding Conventions Observed
- MARK comments used consistently (// MARK: - Section)
- Private computed vars for sub-views (messageListView, inputBarView, isSendDisabled)
- Guard-let chains for JSON parsing (acceptable given no Codable)
- Chinese error messages for end-user facing strings, English for internal comments
