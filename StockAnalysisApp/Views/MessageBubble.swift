import SwiftUI
import MarkdownUI

struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            if isUser {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .textSelection(.enabled)
            } else if message.content.isEmpty {
                TypingDotsView()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                Markdown(message.content)
                    .markdownTheme(.basic)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .textSelection(.enabled)
            }

            if !isUser { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

private struct TypingDotsView: View {
    @State private var phases: [Bool] = [false, false, false]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(phases[index] ? 1.3 : 0.7)
                    .animation(
                        .easeInOut(duration: 0.45).repeatForever(autoreverses: true),
                        value: phases[index]
                    )
            }
        }
        .onAppear {
            for index in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                    phases[index] = true
                }
            }
        }
    }
}
