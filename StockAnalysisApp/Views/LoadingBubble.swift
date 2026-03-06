import SwiftUI

struct LoadingBubble: View {
    @State private var phases: [Bool] = [false, false, false]

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(phases[index] ? 1.3 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.45).repeatForever(
                                autoreverses: true
                            ),
                            value: phases[index]
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Spacer(minLength: 48)
        }
        .onAppear {
            for index in 0..<3 {
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + Double(index) * 0.15
                ) {
                    phases[index] = true
                }
            }
        }
    }
}
