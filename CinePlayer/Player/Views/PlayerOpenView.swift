import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct PlayerOpenView: View {
    @EnvironmentObject var sessionStore: PlayerSessionStore

    private let defaultHint = "拖动视频文件到窗口任意区域可直接播放"

    @State private var showFileImporter = false
    @State private var urlInput = ""
    @State private var hintText = "拖动视频文件到窗口任意区域可直接播放"
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 26) {
                topBranding
                openControls
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 70)

            bottomHint
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isDropTargeted {
                dropOverlay
            }
        }
        .onAppear {
            hintText = defaultHint
        }
        #if !os(tvOS)
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted, perform: handleDrop(providers:))
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie, .video],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                openMedia(url: url)
            }
        }
        #endif
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.04, blue: 0.07),
                Color(red: 0.04, green: 0.06, blue: 0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Circle()
                .fill(Color(red: 0.55, green: 0.63, blue: 1.0).opacity(0.24))
                .frame(width: 760, height: 760)
                .offset(x: -240, y: -300)
                .blur(radius: 18)
        }
        .overlay {
            Circle()
                .fill(Color(red: 0.4, green: 0.92, blue: 0.9).opacity(0.14))
                .frame(width: 720, height: 720)
                .offset(x: 260, y: 360)
                .blur(radius: 20)
        }
        .overlay {
            LinearGradient(
                colors: [
                    Color(red: 0.6, green: 0.68, blue: 1).opacity(0.22),
                    Color(red: 0.52, green: 0.61, blue: 0.95).opacity(0.14),
                    Color(red: 0.4, green: 0.84, blue: 0.88).opacity(0.05),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var topBranding: some View {
        Image("CinePlayerIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 82, height: 82)
    }

    private var openControls: some View {
        VStack(spacing: 22) {
            enclosedURLField
            actionsRow
        }
    }

    private var enclosedURLField: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial.opacity(0.38))
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)

            TextField("输入视频 URL", text: $urlInput)
                #if os(tvOS)
                .textFieldStyle(.automatic)
                #else
                .textFieldStyle(.plain)
                #endif
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.white.opacity(0.96))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: 1220)
        .frame(height: 52)
    }

    private var actionsRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            Button("播放") {
                guard let url = resolveInputURL(urlInput) else {
                    hintText = "请输入有效 URL 或文件路径"
                    return
                }
                openMedia(url: url)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 6)

            #if !os(tvOS)
            Spacer(minLength: 160)

            Button("播放文件") {
                showFileImporter = true
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal, 6)
            #endif

            Spacer(minLength: 0)
        }
        .frame(maxWidth: 760)
    }

    private var bottomHint: some View {
        VStack {
            Spacer()
            Text(hintText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .allowsHitTesting(false)
    }

    private var dropOverlay: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color.white.opacity(0.06))
            .overlay {
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [7, 6]))
                    .foregroundStyle(Color.white.opacity(0.38))
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    #if !os(tvOS)
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let fileProvider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            return false
        }

        fileProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            if let data = item as? Data,
               let url = URL(dataRepresentation: data, relativeTo: nil) {
                openMedia(url: url)
                return
            }

            if let url = item as? URL {
                openMedia(url: url)
                return
            }

            if let path = item as? String {
                let sanitized = path.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = URL(string: sanitized) {
                    openMedia(url: url)
                }
            }
        }

        return true
    }
    #endif

    private func openMedia(url: URL) {
        let displayName = displayText(for: url)
        DispatchQueue.main.async {
            hintText = "准备播放: \(displayName)"
            sessionStore.open(url: url)
        }
    }

    private func displayText(for url: URL) -> String {
        if url.isFileURL {
            return url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        }
        return url.absoluteString
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
