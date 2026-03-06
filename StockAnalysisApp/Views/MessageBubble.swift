import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .textSelection(.enabled)

            if !isUser { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}
