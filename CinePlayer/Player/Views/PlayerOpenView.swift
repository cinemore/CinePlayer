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

            VStack(spacing: 0) {
                Spacer(minLength: 36)
                topBranding
                Spacer(minLength: topToControlsSpacing)
                openControls
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
            .padding(.bottom, 88)

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
                .fill(Color(red: 0.55, green: 0.63, blue: 1.0).opacity(0.2))
                .frame(width: 820, height: 820)
                .offset(x: -260, y: -320)
                .blur(radius: 26)
        }
        .overlay {
            Circle()
                .fill(Color(red: 0.36, green: 0.86, blue: 0.86).opacity(0.1))
                .frame(width: 860, height: 860)
                .offset(x: 300, y: 420)
                .blur(radius: 38)
        }
        .overlay {
            LinearGradient(
                colors: [
                    Color(red: 0.62, green: 0.7, blue: 1).opacity(0.18),
                    Color(red: 0.54, green: 0.64, blue: 0.96).opacity(0.1),
                    Color(red: 0.4, green: 0.84, blue: 0.88).opacity(0.03),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay {
            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.22)
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
            .frame(width: 86, height: 86)
            .shadow(color: Color.black.opacity(0.2), radius: 18, y: 8)
    }

    private var openControls: some View {
        VStack(spacing: 16) {
            enclosedURLField
            actionsRow
        }
        .frame(maxWidth: controlsMaxWidth)
    }

    private var enclosedURLField: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.34))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.27), lineWidth: 1)

            TextField("输入视频 URL", text: $urlInput)
                #if os(tvOS)
                .textFieldStyle(.automatic)
                #else
                .textFieldStyle(.plain)
                #endif
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.96))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .shadow(color: Color.black.opacity(0.14), radius: 12, y: 5)
    }

    private var actionsRow: some View {
        HStack(spacing: 14) {
            Button("播放") {
                guard let url = resolveInputURL(urlInput) else {
                    hintText = "请输入有效 URL 或文件路径"
                    return
                }
                openMedia(url: url)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.08, green: 0.5, blue: 0.97))
            .controlSize(.large)
            .frame(width: actionButtonWidth, height: actionButtonHeight)

            #if !os(tvOS)
            Button("播放文件") {
                showFileImporter = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.24, green: 0.31, blue: 0.41))
            .controlSize(.large)
            .frame(width: actionButtonWidth, height: actionButtonHeight)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var controlsMaxWidth: CGFloat {
        #if os(macOS)
        return 760
        #elseif os(tvOS)
        return 720
        #else
        return 640
        #endif
    }

    private var actionButtonWidth: CGFloat {
        #if os(tvOS)
        return 170
        #else
        return 132
        #endif
    }

    private var actionButtonHeight: CGFloat {
        #if os(tvOS)
        return 52
        #else
        return 44
        #endif
    }

    private var topToControlsSpacing: CGFloat {
        #if os(macOS)
        return 96
        #elseif os(tvOS)
        return 86
        #else
        return 72
        #endif
    }

    private var bottomHint: some View {
        VStack {
            Spacer()
            Text(hintText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
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
                Task { @MainActor in
                    openMedia(url: url)
                }
                return
            }

            if let url = item as? URL {
                Task { @MainActor in
                    openMedia(url: url)
                }
                return
            }

            if let path = item as? String {
                let sanitized = path.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = URL(string: sanitized) {
                    Task { @MainActor in
                        openMedia(url: url)
                    }
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
