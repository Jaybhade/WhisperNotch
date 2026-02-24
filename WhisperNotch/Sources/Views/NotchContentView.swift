import SwiftUI

/// The SwiftUI content rendered inside the notch panel — premium design
struct NotchContentView: View {
    @ObservedObject var notchState: NotchState

    // Pulsing glow when listening
    @State private var glowPulse: Bool = false
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            // ── Background pill shape ──
            NotchShape()
                .fill(.black)

            // ── Glow border when active ──
            if notchState.isListening || notchState.isTranscribing {
                NotchShape()
                    .stroke(
                        LinearGradient(
                            colors: notchState.isTranscribing
                                ? [Color.orange, Color.yellow.opacity(0.6)]
                                : [Color.cyan, Color.purple, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
                    .blur(radius: glowPulse ? 4 : 2)
                    .opacity(glowPulse ? 0.9 : 0.5)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            glowPulse = true
                        }
                    }
                    .onDisappear {
                        glowPulse = false
                    }
            }

            // ── Drop shadow ──
            NotchShape()
                .fill(.clear)
                .shadow(color: .black.opacity(0.6), radius: 16, y: 6)

            // ── Content ──
            VStack(spacing: 0) {
                // Notch spacer (the real notch sits above our content)
                Spacer().frame(height: 34)

                if notchState.isListening {
                    listeningView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if notchState.isTranscribing {
                    transcribingView
                        .transition(.opacity)
                } else if !notchState.transcribedText.isEmpty {
                    doneView
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else if !notchState.statusMessage.isEmpty {
                    statusView
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 20)
            .animation(.easeInOut(duration: 0.2), value: notchState.isListening)
            .animation(.easeInOut(duration: 0.2), value: notchState.isTranscribing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Listening: Waveform + live text

    private var listeningView: some View {
        VStack(spacing: 8) {
            // Real-time waveform driven by actual audio levels
            AudioWaveformView(levels: notchState.audioLevels)
                .frame(height: 32)

            // Show interim transcription as it comes
            if !notchState.transcribedText.isEmpty {
                Text(notchState.transcribedText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .animation(.easeOut(duration: 0.15), value: notchState.transcribedText)
            } else {
                Text("Listening…")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Transcribing spinner

    private var transcribingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.6)
                .colorScheme(.dark)

            Text("Transcribing…")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Done: show final text

    private var doneView: some View {
        VStack(spacing: 4) {
            Text(notchState.transcribedText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                Text("Inserted")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundColor(.green)
        }
    }

    // MARK: - Status

    private var statusView: some View {
        Text(notchState.statusMessage)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.6))
    }
}

// MARK: - Audio Waveform View

/// Displays a bar waveform where each bar height is driven by a real audio level sample.
/// The bars scroll left as new samples arrive, creating a real-time visualization.
struct AudioWaveformView: View {
    let levels: [CGFloat]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<levels.count, id: \.self) { i in
                SingleBar(level: levels[i], index: i, total: levels.count)
            }
        }
    }
}

struct SingleBar: View {
    let level: CGFloat
    let index: Int
    let total: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(barColor)
            .frame(width: 3, height: barHeight)
            .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.7), value: level)
    }

    private var barHeight: CGFloat {
        let minHeight: CGFloat = 2
        let maxHeight: CGFloat = 28
        return minHeight + level * (maxHeight - minHeight)
    }

    private var barColor: LinearGradient {
        let progress = CGFloat(index) / CGFloat(max(total - 1, 1))

        // Gradient shifts from purple → cyan → white based on level intensity
        let baseColor: Color
        if level > 0.7 {
            baseColor = Color(red: 0.4 + progress * 0.3, green: 0.85, blue: 1.0) // bright cyan-white
        } else if level > 0.3 {
            baseColor = Color(red: 0.3, green: 0.55 + level * 0.3, blue: 1.0) // medium blue
        } else {
            baseColor = Color(red: 0.45, green: 0.35, blue: 0.8 + level * 0.2) // purple
        }

        return LinearGradient(
            colors: [baseColor.opacity(0.6), baseColor],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

// MARK: - Notch Shape

struct NotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let topCorner: CGFloat = 10
        let bottomCorner: CGFloat = 20

        var path = Path()

        path.move(to: CGPoint(x: rect.minX + topCorner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topCorner, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + topCorner),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomCorner))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomCorner, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomCorner, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomCorner),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topCorner))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCorner, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()

        return path
    }
}
