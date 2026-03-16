import Foundation
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct PlayerOpenView: View {
    private enum OpenRoute: Hashable {
        case history
    }

    @EnvironmentObject var sessionStore: PlayerSessionStore

    private let defaultHint = "拖动视频文件到窗口播放"

    @State private var navigationPath: [OpenRoute] = []
    @State private var showFileImporter = false
    @State private var urlInput = ""
    @State private var isDropTargeted = false
    @FocusState private var isURLFieldFocused: Bool

    private var hasURLInput: Bool {
        !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                backgroundLayer

                VStack(spacing: 32) {
                    topBranding
                    openControls
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)

                #if os(macOS)
                bottomHint
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if isDropTargeted {
                    dropOverlay
                }
            }
            .navigationDestination(for: OpenRoute.self) { route in
                switch route {
                case .history:
                    PlaybackHistoryListView()
                }
            }
            .navigationTitle("")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    historyButton
                }
            }
            #else
            .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        historyButton
                    }
                }
            #endif
        }
        #if !os(tvOS)
        .onDrop(
            of: [UTType.fileURL],
            isTargeted: $isDropTargeted,
            perform: handleDrop(providers:)
        )
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

    private var historyButton: some View {
        Button {
            navigationPath.append(.history)
        } label: {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
        }
    }

    private var backgroundLayer: some View {
        Rectangle()
            .fill(systemBackgroundColor)
            .overlay {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.08),
                        .white.opacity(0.2)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            }
            .ignoresSafeArea()
        #if os(iOS)
            .contentShape(Rectangle())
            .onTapGesture {
                isURLFieldFocused = false
            }
        #endif
    }

    private var systemBackgroundColor: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #elseif os(tvOS)
        return .black
        #else
        return Color(uiColor: .systemBackground)
        #endif
    }

    private var topBranding: some View {
        Image("CinePlayerIcon")
            .resizable()
            .scaledToFit()
            .frame(width: 86, height: 86)
            .shadow(color: Color.black.opacity(0.2), radius: 18, y: 8)
    }

    private var openControls: some View {
        VStack(spacing: 32) {
            HStack {
                urlPlayContainer

                if hasURLInput {
                    playURLButton
                }
            }
            .animation(.snappy, value: hasURLInput)
            #if !os(tvOS)
            orDividerRow
            openFileButton
            #endif
        }
        .frame(maxWidth: 640)
    }

    private static let openControlCornerRadius: CGFloat = 16

    private var urlPlayContainer: some View {
        HStack(alignment: .center, spacing: 8) {
            TextField("输入视频 URL", text: $urlInput)
            #if os(tvOS)
                .textFieldStyle(.automatic)
            #else
                .textFieldStyle(.plain)
            #endif
                .focused($isURLFieldFocused)
                .submitLabel(.go)
                .onSubmit {
                    guard let url = resolveInputURL(urlInput) else {
                        return
                    }
                    openMedia(url: url)
                }
                .font(.system(size: 15, weight: .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)

            if hasURLInput {
                Button {
                    urlInput = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 44)
        .modifier(GlassEffectModifier(
            cornerRadius: Self.openControlCornerRadius,
            useCapsule: true,
            clipsContent: true
        ))
    }

    private var playURLButton: some View {
        Button(action: {
            guard let url = resolveInputURL(urlInput) else { return }
            openMedia(url: url)
        }) {
            ZStack {
                Color(red: 0.08, green: 0.5, blue: 0.97)
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .modifier(GlassEffectModifier(
                cornerRadius: Self.openControlCornerRadius,
                useCapsule: true,
                clipsContent: true
            ))
        }
        .buttonStyle(.plain)
    }

    private var orDividerRow: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(Color.primary.opacity(0.2))
                .frame(height: 1)
            Text("或")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.72))
            Capsule()
                .fill(Color.primary.opacity(0.2))
                .frame(height: 1)
        }
        .frame(alignment: .center)
        .padding(.horizontal, 4)
    }

    private var openFileButton: some View {
        Button(action: {
            showFileImporter = true
        }) {
            ZStack {
                Color.blue
                Text("打开文件")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 240, height: 44)
            .modifier(GlassEffectModifier(
                cornerRadius: Self.openControlCornerRadius,
                useCapsule: true,
                clipsContent: true
            ))
        }
        .buttonStyle(.plain)
    }

    private var bottomHint: some View {
        VStack {
            Spacer()
            Text(defaultHint)
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
               let url = URL(dataRepresentation: data, relativeTo: nil)
            {
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
        sessionStore.open(url: url)
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
