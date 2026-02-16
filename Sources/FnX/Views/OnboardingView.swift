import SwiftUI

private let W: CGFloat = 540
private let H: CGFloat = 580

struct OnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            ZStack {
                ForEach(0..<OnboardingViewModel.totalPages, id: \.self) { index in
                    if viewModel.currentPage == index {
                        pageContent(index: index)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(x: 30)),
                                removal: .opacity.combined(with: .offset(x: -30))
                            ))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: viewModel.currentPage)

            VStack(spacing: 0) {
                PageDots(currentPage: viewModel.currentPage, totalPages: OnboardingViewModel.totalPages)
                    .padding(.bottom, 16)

                Button(action: { viewModel.goNext() }) {
                    Text(viewModel.actionButtonTitle)
                        .frame(width: 180, height: 38)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.isActionEnabled)
                .padding(.bottom, 28)
            }
        }
        .frame(width: W, height: H)
        .onAppear { viewModel.didShowPage(0) }
        .onChange(of: viewModel.currentPage) { new in viewModel.didShowPage(new) }
    }

    @ViewBuilder
    private func pageContent(index: Int) -> some View {
        switch index {
        case 0: welcomePage
        case 1: stepsPage
        case 2: rulesPage
        case 3: permissionsPage
        case 4: tryItPage
        default: EmptyView()
        }
    }

    private var welcomePage: some View {
        OnboardingPageLayout(
            icon: "waveform.circle.fill",
            iconSize: 72,
            title: "FnX",
            titleSize: 42,
            subtitle: "Your voice, everywhere.",
            bodyText: "Dictate text into any app with a single key.\nFast, private, and seamless."
        )
    }

    private var stepsPage: some View {
        VStack(spacing: 0) {
            Text("How It Works")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 40)

            Text("Three simple steps to voice-powered typing.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 8)

            HStack(spacing: 18) {
                StepCard(step: 1, icon: "keyboard", label: "Hold Fn", desc: "Press and hold the\nFunction key")
                StepCard(step: 2, icon: "mic.fill", label: "Speak", desc: "Say what you want\nto type")
                StepCard(step: 3, icon: "text.cursor", label: "Release", desc: "Text appears at\nyour cursor")
            }
            .padding(.top, 24)

            Text("Works in any text field across macOS.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.top, 24)
            Spacer()
        }
    }

    private var rulesPage: some View {
        OnboardingPageLayout(
            icon: "text.badge.checkmark",
            iconSize: 52,
            title: "Smart Rules",
            titleSize: 28,
            subtitle: "Transform your text automatically.",
            bodyText: "Translate, fix grammar, or rewrite\nas code comments — all hands-free."
        )
    }

    private var permissionsPage: some View {
        VStack(spacing: 0) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(.white)
                .padding(.top, 40)

            Text("Permissions")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 20)

            Text("FnX needs these to work properly.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 8)

            VStack(spacing: 16) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Record your voice for transcription.",
                    granted: viewModel.micGranted,
                    buttonTitle: "Allow",
                    action: { viewModel.requestMicPermission() }
                )
                PermissionRow(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: "Listen for the Fn key & type text for you.",
                    granted: viewModel.accessibilityGranted,
                    buttonTitle: "Open Settings",
                    action: { viewModel.openAccessibilitySettings() }
                )
            }
            .padding(.horizontal, 30)
            .padding(.top, 32)
            Spacer()
        }
    }

    private var tryItPage: some View {
        VStack(spacing: 0) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(.white)
                .padding(.top, 40)

            Text("Try It!")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 20)

            HStack(spacing: 10) {
                Circle()
                    .fill(viewModel.isTryRecording ? Color.red : Color.white.opacity(0.25))
                    .frame(width: 9, height: 9)
                Text(viewModel.tryItStatus)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
            .padding(.top, 24)

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.07), lineWidth: 0.5))
                    .frame(height: 160)

                if viewModel.showTryPlaceholder && viewModel.tryItText.isEmpty {
                    Text("Your transcription will appear here...")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.18))
                }
                ScrollView {
                    Text(viewModel.tryItText)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .frame(maxHeight: 160)
            }
            .padding(.horizontal, 40)
            .padding(.top, 24)
            Spacer()
        }
    }
}

private struct OnboardingPageLayout: View {
    let icon: String
    let iconSize: CGFloat
    let title: String
    let titleSize: CGFloat
    let subtitle: String
    let bodyText: String

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .thin))
                .foregroundStyle(.white)
                .padding(.top, 40)

            Text(title)
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 20)

            Text(subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 8)

            Text(bodyText)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.38))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
                .padding(.top, 20)
            Spacer()
        }
    }
}

private struct StepCard: View {
    let step: Int
    let icon: String
    let label: String
    let desc: String

    var body: some View {
        VStack(spacing: 0) {
            Text("\(step)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.25))
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 8)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 8)
            Text(desc)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.38))
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .frame(width: 136, height: 156)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let granted: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.38))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)

            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(granted ? .green : .white.opacity(0.25))
        }
        .padding(16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
    }
}

private struct PageDots: View {
    let currentPage: Int
    let totalPages: Int
    private let dotSize: CGFloat = 7
    private let activeWidth: CGFloat = 22
    private let spacing: CGFloat = 7

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<totalPages, id: \.self) { i in
                RoundedRectangle(cornerRadius: dotSize / 2)
                    .fill(i == currentPage ? Color.white.opacity(0.85) : Color.white.opacity(0.18))
                    .frame(width: i == currentPage ? activeWidth : dotSize, height: dotSize)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }
}

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(
            viewModel: OnboardingViewModel(
                audioRecorder: .init(),
                whisperService: .init(),
                onComplete: {}
            )
        )
    }
}
#endif
