import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct PlayerOpenView: View {
    @EnvironmentObject var sessionStore: PlayerSessionStore
    @State private var showFileImporter = false
    @State private var urlInput = ""

    var body: some View {
        VStack(spacing: 18) {
            Text("CinePlayer")
                .font(.largeTitle.bold())

            #if !os(tvOS)
            Button("打开文件") {
                showFileImporter = true
            }
            .buttonStyle(.borderedProminent)
            #endif

            TextField("输入视频 URL", text: $urlInput)
                #if os(tvOS)
                .textFieldStyle(.automatic)
                #else
                .textFieldStyle(.roundedBorder)
                #endif
                .frame(maxWidth: 520)

            Button("播放 URL") {
                guard let url = resolveInputURL(urlInput) else {
                    return
                }
                sessionStore.open(url: url)
            }
            .buttonStyle(.bordered)

            Button("测试视频") {
                if let url = URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4") {
                    sessionStore.open(url: url)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(32)
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie, .video],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                sessionStore.open(url: url)
            }
        }
        #endif
    }

    private func resolveInputURL(_ rawInput: String) -> URL? {
        let text = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return nil
        }

        if let url = URL(string: text), url.scheme != nil {
            return url
        }

        let expandedPath = (text as NSString).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            return URL(fileURLWithPath: expandedPath)
        }

        return URL(string: text)
    }
}
