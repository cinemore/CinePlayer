import CinePlayerSDK
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct ExternalSubtitleView: View {
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var playerControlModel: PlayerControlModel

    #if os(iOS) || os(visionOS)
    @State private var showFileImporter = false
    #endif

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("开启")
                    .f16b()
                    .foregroundColor(.white)
                Spacer()
                Toggle(
                    isOn: Binding(
                        get: { !playerControlModel.currentSubtitlePath.isEmpty },
                        set: { newValue in
                            if newValue {
                                if let current = localSubtitleItems.first(where: {
                                    $0.id == playerControlModel.currentSubtitlePath
                                }) {
                                    playSubtitle(current)
                                } else if let first = localSubtitleItems.first {
                                    playSubtitle(first)
                                }
                            } else {
                                playerCoordinator.subtitleTrackIndex = -1
                                playerCoordinator.controller?.clearSubtitle()
                                playerControlModel.currentSubtitlePath = ""
                            }
                        }
                    )
                ) {}
                .toggleStyle(.switch)
                .labelsHidden()
                #if os(iOS)
                    .scaleEffect(0.8)
                    .offset(x: 2)
                #endif
            }

            HStack(spacing: 20) {
                if PurePlayerUIPolicy.allowsLocalSubtitleImport {
                    Button {
                        openLocalSubtitleFilePicker()
                    } label: {
                        Text("导入")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            if localSubtitleItems.isEmpty {
                ScrollView(showsIndicators: false) {
                    VStack {
                        Spacer(minLength: 24)
                        Text("尚未导入外部字幕")
                            .f12r()
                            .foregroundStyle(.white.opacity(0.65))
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(localSubtitleItems) { item in
                            subtitleRowView(item: item)
                        }
                    }
                }
            }
        }
        #if os(iOS) || os(visionOS)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: subtitleContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                if let url = urls.first {
                    let hasAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if hasAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    importSubtitles(urls: [url])
                }
            case .failure:
                break
            }
        }
        #endif
    }

    private var localSubtitleItems: [PlayerControlModel.LocalSubtitleItem] {
        playerControlModel.localSubtitleItems
    }

    @ViewBuilder
    private func subtitleRowView(item: PlayerControlModel.LocalSubtitleItem) -> some View {
        let isSelected = playerControlModel.currentSubtitlePath == item.id
        Button {
            playSubtitle(item)
        } label: {
            ExternalSubtitleRowView(
                isSelected: isSelected,
                subtitleName: item.displayName,
                subtitleLanguage: "",
                subtitleSize: item.sizeDescription
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? .white : .white.opacity(0.2),
                        lineWidth: 1
                    )
            }
            .contentShape(Rectangle())
            .roundedCorner(8)
            .id(item.id)
        }
        .buttonStyle(.plain)
    }

    private var subtitleContentTypes: [UTType] {
        var types: [UTType] = [.plainText, .text]
        if let srtType = UTType(filenameExtension: "srt") {
            types.append(srtType)
        }
        if let assType = UTType(filenameExtension: "ass") {
            types.append(assType)
        }
        if let ssaType = UTType(filenameExtension: "ssa") {
            types.append(ssaType)
        }
        if let vttType = UTType(filenameExtension: "vtt") {
            types.append(vttType)
        }
        if let subType = UTType(filenameExtension: "sub") {
            types.append(subType)
        }
        return types
    }

    private func playSubtitle(_ item: PlayerControlModel.LocalSubtitleItem) {
        playerCoordinator.subtitleTrackIndex = -1
        playerControlModel.currentSubtitlePath = item.id
        playerCoordinator.controller?.loadSubtitleFile(subtitleID: item.displayName, url: item.url)
    }

    private func importSubtitles(urls: [URL]) {
        for url in urls {
            if let item = persistSubtitle(url: url) {
                playerControlModel.addLocalSubtitle(item)
                playSubtitle(item)
            }
        }
    }

    private func persistSubtitle(url: URL) -> PlayerControlModel.LocalSubtitleItem? {
        let destinationDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CinePlayerSubtitles", isDirectory: true)
        try? FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)

        let destinationURL = destinationDirectory
            .appendingPathComponent("\(UUID().uuidString)_\(url.lastPathComponent)")

        do {
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.copyItem(at: url, to: destinationURL)
            let attrs = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let bytes = attrs[.size] as? Int64 ?? 0
            return .init(
                id: destinationURL.path,
                url: destinationURL,
                displayName: destinationURL.lastPathComponent,
                sizeDescription: ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            )
        } catch {
            return nil
        }
    }

    private func openLocalSubtitleFilePicker() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "导入字幕"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = subtitleContentTypes
        panel.begin { response in
            guard response == .OK else {
                return
            }
            importSubtitles(urls: panel.urls)
        }
        #elseif os(iOS) || os(visionOS)
        showFileImporter = true
        #endif
    }
}
