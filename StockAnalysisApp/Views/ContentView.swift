//
//  ContentView.swift
//  StockAnalysisApp
//
//  Created by crystal.zeng on 2026/3/5.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel: ChatViewModel
    @FocusState private var isTextFieldFocused: Bool

    init(viewModel: ChatViewModel = ChatViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageListView
                Divider()
                inputBarView
            }
            .navigationTitle("股票分析 AI")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Message List

    private var messageListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if viewModel.isLoading {
                        LoadingBubble()
                            .id("loading")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isLoading) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onTapGesture {
                isTextFieldFocused = false
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            if viewModel.isLoading {
                proxy.scrollTo("loading", anchor: .bottom)
            } else if let lastId = viewModel.messages.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }

    // MARK: - Input Bar

    private var inputBarView: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("輸入問題...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .focused($isTextFieldFocused)
                .disabled(viewModel.isLoading)
                .onSubmit {
                    Task { await viewModel.sendMessage() }
                }

            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(isSendDisabled ? .gray : .blue)
                    }
                }
            }
            .disabled(isSendDisabled)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var isSendDisabled: Bool {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
            || viewModel.isLoading
    }
}

#Preview {
    let vm = ChatViewModel()
    vm.messages = [
        ChatMessage(
            role: .assistant,
            content: "您好！我是股票分析 AI 助理\n\n請問有什麼我可以幫您的？"
        ),
        ChatMessage(role: .user, content: "台積電現在股價多少？"),
        ChatMessage(
            role: .assistant,
            content:
                "台積電（2330.TW）目前股價為 **NT$850**，較昨日上漲 +12（+1.43%）。\n\n投資有風險，以上分析僅供參考。"
        ),
    ]
    return ContentView(viewModel: vm)
}
