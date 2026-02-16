import SwiftUI

// MARK: - Main View

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel
    
    // Top portion hidden behind menu bar — must cover full menu bar height to reach notch
    private let hiddenTop: CGFloat = 38
    // Notch width on MacBook Pro
    private let notchWidth: CGFloat = 180
    private let expandedWidth: CGFloat = 260
    private let wideExpandedWidth: CGFloat = 300
    // Visible body height when expanded
    private let bodyHeight: CGFloat = 48
    
    private var isWide: Bool {
        viewModel.state == .limitReached || viewModel.state == .proRequired
    }
    
    private var targetWidth: CGFloat {
        viewModel.isVisible ? (isWide ? wideExpandedWidth : expandedWidth) : notchWidth
    }
    
    private var totalHeight: CGFloat {
        viewModel.isVisible ? hiddenTop + bodyHeight : hiddenTop
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Single unified black shape: top flat (hidden behind menu bar) + bottom rounded
                NotchShape(cornerRadius: viewModel.isVisible ? 22 : 6)
                    .fill(Color.black)
                    .frame(width: targetWidth, height: totalHeight)
                    .offset(y: viewModel.isVisible ? 0 : -20)
                    .shadow(
                        color: .black.opacity(viewModel.isVisible ? 0.5 : 0),
                        radius: 14,
                        y: 6
                    )

                // Content — appears after the black shape has expanded
                if viewModel.contentVisible {
                    Group {
                        if isWide {
                            upgradeContent
                        } else {
                            defaultContent
                        }
                    }
                    .padding(.top, hiddenTop + 10)
                    .transition(.opacity.combined(with: .offset(y: -6)))
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .animation(.spring(response: 0.5, dampingFraction: 0.74), value: viewModel.isVisible)
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: viewModel.state)
        .animation(.easeOut(duration: 0.25), value: viewModel.contentVisible)
    }
    
    // MARK: - Accent Color
    
    private var accentGlow: Color {
        switch viewModel.state {
        case .recording: return .red
        case .processing: return .cyan
        case .done: return .green
        case .limitReached: return .orange
        case .proRequired: return .purple
        case .hidden: return .clear
        }
    }
    
    // MARK: - Default Content (Recording / Processing / Done)
    
    private var defaultContent: some View {
        HStack(spacing: 10) {
            stateIcon
                .frame(width: 24, height: 24)
            
            Text(viewModel.label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .contentTransition(.numericText())
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.state)
    }
    
    @ViewBuilder
    private var stateIcon: some View {
        switch viewModel.state {
        case .recording:
            RecordingIndicator()
                .transition(.scale.combined(with: .opacity))
        case .processing:
            ProcessingSpinner()
                .transition(.scale.combined(with: .opacity))
        case .done:
            DoneCheckmark()
                .transition(.scale.combined(with: .opacity))
        default:
            Color.clear
        }
    }
    
    // MARK: - Upgrade Content (Limit / Pro Required)
    
    private var upgradeContent: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.state == .proRequired ? "lock.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(viewModel.state == .proRequired ? .purple : .orange)
                .shadow(color: (viewModel.state == .proRequired ? Color.purple : .orange).opacity(0.5), radius: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(viewModel.state == .proRequired ? "Typed raw text instead" : "Upgrade to Pro for unlimited")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Notch Shape (flat top, rounded bottom)

private struct NotchShape: InsettableShape {
    var cornerRadius: CGFloat
    var insetAmount: CGFloat = 0
    
    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        let cr = min(cornerRadius, r.height / 2, r.width / 2)
        
        path.move(to: CGPoint(x: r.minX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cr))
        path.addQuadCurve(
            to: CGPoint(x: r.maxX - cr, y: r.maxY),
            control: CGPoint(x: r.maxX, y: r.maxY)
        )
        path.addLine(to: CGPoint(x: r.minX + cr, y: r.maxY))
        path.addQuadCurve(
            to: CGPoint(x: r.minX, y: r.maxY - cr),
            control: CGPoint(x: r.minX, y: r.maxY)
        )
        path.closeSubpath()
        return path
    }
    
    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

// MARK: - Recording Indicator

private struct RecordingIndicator: View {
    @State private var pulseScale = 1.0
    @State private var pulseOpacity = 0.5
    @State private var dotScale = 1.0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(pulseOpacity))
                .frame(width: 20, height: 20)
                .scaleEffect(pulseScale)
            
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .scaleEffect(dotScale)
                .shadow(color: .red.opacity(0.7), radius: 5)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulseScale = 1.5
                pulseOpacity = 0
                dotScale = 0.8
            }
        }
    }
}

// MARK: - Processing Spinner

private struct ProcessingSpinner: View {
    @State private var rotation = 0.0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.cyan.opacity(0.15), lineWidth: 2.5)
                .frame(width: 16, height: 16)
            
            Circle()
                .trim(from: 0, to: 0.6)
                .stroke(
                    AngularGradient(
                        colors: [.cyan.opacity(0), .cyan],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(rotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 0.75).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Done Checkmark

private struct DoneCheckmark: View {
    @State private var scale = 0.0
    
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.green)
            .scaleEffect(scale)
            .shadow(color: .green.opacity(0.6), radius: 5)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    scale = 1.0
                }
            }
    }
}

// MARK: - Preview

#if DEBUG
private func makePreviewVM(_ configure: (OverlayViewModel) -> Void) -> OverlayViewModel {
    let vm = OverlayViewModel()
    configure(vm)
    return vm
}

struct OverlayView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            OverlayView(viewModel: makePreviewVM { $0.showRecording() })
                .frame(width: 400, height: 80)
            OverlayView(viewModel: makePreviewVM { $0.showProcessing() })
                .frame(width: 400, height: 80)
            OverlayView(viewModel: makePreviewVM { $0.showDone() })
                .frame(width: 400, height: 80)
            OverlayView(viewModel: makePreviewVM { $0.showLimitReached() })
                .frame(width: 400, height: 80)
        }
        .padding()
        .background(.gray.opacity(0.2))
    }
}
#endif
