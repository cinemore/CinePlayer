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
    #if !os(macOS)
        @Environment(\.openURL) private var openURL
    #endif

    private var versionText: String {
        "版本号: \(AboutAppInfo.version) (\(AboutAppInfo.build))"
    }

    var body: some View {
        #if os(macOS)
            macBody
                .navigationTitle("关于")
        #else
            mobileBody
                .navigationTitle("关于")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
        #endif
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
                .frame(width: 82, height: 82)
                .padding(.bottom, 8)

            Text("CinePlayer")
                .font(.system(size: 24, weight: .semibold))

            Text(versionText)
                .f13r()
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
                        .f13r()
                    Text("cinemore@cinemore.com.cn")
                        .f12r()
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
            Button {
                openExternal(AboutLinks.filing)
            } label: {
                Text("Copyright © 2024 Youduohong. All rights reserved.")
                    .f12r()
            }
            .buttonStyle(.plain)
            .focusable(false)

            HStack(spacing: 26) {
                linkButton(title: "第三方许可信息", url: AboutLinks.licenses)
                linkButton(title: "隐私政策", url: AboutLinks.privacy)
                linkButton(title: "使用条款(EULA)", url: AboutLinks.eula)
            }

            //            Button {
            //                openExternal(AboutLinks.filing)
            //            } label: {
            //                Text("粤ICP备2022030744号-5A")
            //                    .f12r()
            //                    .foregroundStyle(.blue)
            //            }
            //            .buttonStyle(.plain)
        }
    }

    private func linkButton(title: String, url: String) -> some View {
        Button {
            openExternal(url)
        } label: {
            Text(title)
                .f12r()
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
