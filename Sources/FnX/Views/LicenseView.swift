import SwiftUI

struct LicenseView: View {
    @ObservedObject var viewModel: LicenseViewModel

    var body: some View {
        Group {
            if viewModel.isPro {
                ProStatusView(viewModel: viewModel)
            } else {
                FreePaywallView(viewModel: viewModel)
            }
        }
        .frame(width: 480, height: 560)
    }
}

private struct FreePaywallView: View {
    @ObservedObject var viewModel: LicenseViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let logoURL = Bundle.module.url(forResource: "AppLogo", withExtension: "png"),
               let nsImage = NSImage(contentsOf: logoURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .padding(.top, 16)
            }

            UsageCard(viewModel: viewModel)
                .padding(.horizontal, 24)
                .padding(.top, 12)

            Text("Upgrade to FnX Pro")
                .font(.system(size: 22, weight: .bold))
                .padding(.top, 12)

            Text("Unlock unlimited transcriptions and Smart Rules")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            FeatureTable()
                .padding(.top, 14)
                .padding(.horizontal, 24)

            PricingCards(viewModel: viewModel)
                .padding(.top, 16)
                .padding(.horizontal, 24)

            Spacer(minLength: 8)

            ActivationSection(viewModel: viewModel)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            Button("Reset Usage (Debug)") {
                viewModel.resetUsage()
            }
            .font(.system(size: 10))
            .foregroundStyle(.red)
            .buttonStyle(.plain)
            .padding(.bottom, 8)
        }
    }
}

private struct UsageCard: View {
    @ObservedObject var viewModel: LicenseViewModel

    private var barColor: Color {
        if viewModel.remaining == 0 { return .red }
        if viewModel.remaining <= 5 { return .orange }
        return .green
    }

    private var subtitle: String {
        if viewModel.remaining == 0 {
            return "Daily limit reached. Resets tomorrow."
        } else if viewModel.remaining <= 5 {
            return "Running low — upgrade for unlimited."
        }
        return "Resets daily at midnight."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TODAY'S USAGE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("\(viewModel.remaining) of \(viewModel.dailyLimit) remaining")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.remaining == 0 ? .red : viewModel.remaining <= 5 ? .orange : .primary)
            }

            ProgressView(value: viewModel.usageFraction)
                .tint(barColor)

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct FeatureTable: View {
    private let features: [(icon: String, name: String, free: String, pro: String)] = [
        ("waveform", "Transcriptions", "15/day", "Unlimited"),
        ("globe", "Translate to English", "check", "check"),
        ("wand.and.stars", "Smart Rules (AI)", "xmark", "check"),
        ("slider.horizontal.3", "Custom Rules", "xmark", "check"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer().frame(width: 200)
                Spacer()
                Text("FREE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 70)
                Text("PRO")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.blue)
                    .frame(width: 70)
            }

            Divider().padding(.vertical, 4)

            ForEach(features, id: \.name) { feature in
                FeatureRow(
                    icon: feature.icon,
                    name: feature.name,
                    freeValue: feature.free,
                    proValue: feature.pro
                )
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let name: String
    let freeValue: String
    let proValue: String

    var body: some View {
        HStack {
            Label(name, systemImage: icon)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .labelStyle(.titleAndIcon)
                .frame(width: 200, alignment: .leading)

            Spacer()

            ValueBadge(value: freeValue, isPro: false)
                .frame(width: 70)

            ValueBadge(value: proValue, isPro: true)
                .frame(width: 70)
        }
        .padding(.vertical, 4)
    }
}

private struct ValueBadge: View {
    let value: String
    let isPro: Bool

    var body: some View {
        switch value {
        case "check":
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(isPro ? .green : .secondary.opacity(0.5))
        case "xmark":
            Image(systemName: "minus.circle")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.3))
        default:
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isPro ? .blue : .secondary)
        }
    }
}

private struct PricingCards: View {
    @ObservedObject var viewModel: LicenseViewModel

    var body: some View {
        HStack(spacing: 12) {
            PricingCard(
                planName: "Monthly",
                price: "$4.99",
                period: "/month",
                subtitle: nil,
                badge: nil,
                isHighlighted: false
            ) {
                viewModel.openCheckout(annual: false)
            }

            PricingCard(
                planName: "Annual",
                price: "$3.33",
                period: "/month",
                subtitle: "Billed $39.99/year",
                badge: "SAVE 33%",
                isHighlighted: true
            ) {
                viewModel.openCheckout(annual: true)
            }
        }
    }
}

private struct PricingCard: View {
    let planName: String
    let price: String
    let period: String
    let subtitle: String?
    let badge: String?
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(planName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isHighlighted ? .blue : .secondary)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue, in: Capsule())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(price)
                    .font(.system(size: 30, weight: .bold))
                Text(period)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            Spacer()

            Button(action: onTap) {
                Text(isHighlighted ? "Get Pro — Best Value" : "Get Pro")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.bordered)
            .tint(isHighlighted ? .blue : nil)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? Color.blue.opacity(0.06) : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isHighlighted ? Color.blue.opacity(0.35) : Color.primary.opacity(0.08),
                            lineWidth: isHighlighted ? 1.5 : 1
                        )
                )
        }
    }
}

private struct ActivationSection: View {
    @ObservedObject var viewModel: LicenseViewModel

    var body: some View {
        VStack(spacing: 8) {
            Divider().padding(.horizontal, 40)

            Text("Already purchased? Enter your license key:")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                TextField("XXXXX-XXXXX-XXXXX-XXXXX", text: $viewModel.licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .disabled(viewModel.isActivating)

                Button("Activate") {
                    viewModel.activate()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isActivating)
            }

            if !viewModel.activationMessage.isEmpty {
                Text(viewModel.activationMessage)
                    .font(.system(size: 11))
                    .foregroundColor(viewModel.activationFailed ? .red : .green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct ProStatusView: View {
    @ObservedObject var viewModel: LicenseViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack(alignment: .bottomTrailing) {
                if let logoURL = Bundle.module.url(forResource: "AppLogo", withExtension: "png"),
                   let nsImage = NSImage(contentsOf: logoURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.green)
                    .background(Circle().fill(.white).frame(width: 18, height: 18))
                    .offset(x: 4, y: 4)
            }

            Text("FnX Pro Active")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.green)
                .padding(.top, 12)

            Text("Unlimited Transcriptions")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1), in: Capsule())
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 12) {
                ProFeatureRow(icon: "infinity", text: "Unlimited transcriptions")
                ProFeatureRow(icon: "wand.and.stars", text: "Smart Rules with AI processing")
                ProFeatureRow(icon: "globe", text: "Offline translate to English")
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 28)
            .padding(.top, 20)

            VStack(alignment: .leading, spacing: 6) {
                Text("LICENSE KEY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)

                if let masked = viewModel.maskedKey {
                    Text(masked)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)

            Text("License active. Thank you for supporting FnX!")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            Spacer()

            Button("Deactivate License") {
                viewModel.deactivate()
            }
            .foregroundStyle(.red)
            .buttonStyle(.bordered)
            .padding(.bottom, 24)
        }
    }
}

private struct ProFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 13))
            .foregroundStyle(.primary)
            .labelStyle(ProFeatureLabelStyle())
    }
}

private struct ProFeatureLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .foregroundStyle(.green)
                .frame(width: 18)
            configuration.title
        }
    }
}

#if DEBUG
struct LicenseView_Previews: PreviewProvider {
    static var previews: some View {
        LicenseView(
            viewModel: .init(
                licenseManager: .init(),
                onUpdate: {
                })
        )
    }
}
#endif
