import SwiftUI

#if canImport(AppKit)
    import AppKit
#endif

private enum AboutAppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}

private enum AboutLinks {
    static let privacy = "https://cinemore.com.cn/privacy"
    static let licenses = "https://cinemore.com.cn/licenses/apple"
    static let eula = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    static let filing = "https://beian.miit.gov.cn/#/Integrated/index"
}

struct AboutPage: View {
    @State private var showsEnhancementLicenses = false
    #if !os(macOS)
        @Environment(\.openURL) private var openURL
    #endif

    var body: some View {
        Group {
            #if os(macOS)
            macBody
                .navigationTitle("关于")
        #else
            mobileBody
                .navigationTitle("关于")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.large)
            #endif
            #endif
        }
        .sheet(isPresented: $showsEnhancementLicenses) {
            NavigationStack {
                ScrollView {
                    Text(enhancementLicenses)
                        .font(.system(.footnote, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        #if !os(tvOS)
                        .textSelection(.enabled)
                        #endif
                }
                .navigationTitle("视频增强许可")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("完成") { showsEnhancementLicenses = false }
                    }
                }
            }
            #if os(macOS) || os(visionOS)
            .frame(width: 640, height: 520)
            #endif
        }
    }

    private var enhancementLicenses: String {
        guard let url = Bundle.main.url(forResource: "VideoEnhancementLicenses", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text
    }

    #if os(macOS)
        private var macBody: some View {
            VStack(spacing: 0) {
                headerView
                    .padding(.bottom, 18)

                contactCard

                Spacer(minLength: 80)

                footerLinks
            }
            .padding(.top, 30)
            .padding(.bottom, 42)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    #else
        private var mobileBody: some View {
            VStack(spacing: 18) {
                Spacer()

                headerView

                Spacer()

                contactCard
                footerLinks
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .frame(maxHeight: .infinity)
        }
    #endif

    private var headerView: some View {
        VStack(spacing: 8) {
            Image("CinePlayerIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 86)
                .shadow(color: Color.black.opacity(0.2), radius: 18, y: 8)
                .padding(.bottom, 8)

            Text("CinePlayer")
                .font(.title.weight(.semibold))

            Text("版本号: \(AboutAppInfo.version) (\(AboutAppInfo.build))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var contactCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("联系我们")
                        .font(.footnote)
                    Text("cinemore@cinemore.com.cn")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
        }
        .background(Color.primary.opacity(0.015))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(lineWidth: 1)
                .foregroundStyle(.quaternary)
        }
    }

    private var footerLinks: some View {
        VStack(spacing: 6) {
            filingButton

            HStack(spacing: 26) {
                linkButton(title: "第三方许可信息", url: AboutLinks.licenses)
                linkButton(title: "隐私政策", url: AboutLinks.privacy)
                linkButton(title: "使用条款(EULA)", url: AboutLinks.eula)
            }
            Button("视频增强许可") { showsEnhancementLicenses = true }
                .font(.footnote)
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
        }
    }

    @ViewBuilder
    private var filingButton: some View {
        Button {
            openExternal(AboutLinks.filing)
        } label: {
            #if os(iOS)
                VStack(alignment: .center, spacing: 6) {
                    Text("Copyright © 2026 Youduohong. All rights reserved.")
                        .font(.caption)
//                    Text("粤ICP备2022030744号-6A")
//                        .font(.caption)
//                        .foregroundStyle(.blue)
                }
            #else
                Text("Copyright © 2026 Youduohong. All rights reserved.")
                    .font(.caption)
            #endif
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private func linkButton(title: LocalizedStringKey, url: String) -> some View {
        Button {
            openExternal(url)
        } label: {
            Text(title)
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
    }

    private func openExternal(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }
        #if os(macOS)
            NSWorkspace.shared.open(url)
        #else
            openURL(url)
        #endif
    }
}

#Preview {
    NavigationStack {
        AboutPage()
    }
}
