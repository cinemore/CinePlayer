#if !os(tvOS)
import CinePlayerSDK
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct ExternalSubtitleView: View {
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var playerControlModel: PlayerControlModel
    @State private var subtitleCommandScheduler = DeferredMainActorCommandScheduler()
    @State private var importControlBottom: CGFloat?
    @Namespace private var formCoordinateSpace
    #if os(iOS) || os(visionOS)
    @State private var showFileImporter = false
    #endif

    var body: some View {
        let showsEmpty = playerControlModel.localSubtitleItems.isEmpty
        Form {
            Section {
                Toggle("开启", isOn: Binding(
                    get: { !playerControlModel.currentSubtitlePath.isEmpty },
                    set: { enabled in
                        if enabled, let item = playerControlModel.localSubtitleItems.first { playSubtitle(item) }
                        else { playerControlModel.clearSubtitle(controller: playerCoordinator.controller) }
                    }
                ))
                .toggleStyle(.switch)
                .disabled(showsEmpty)
                .accessibilityIdentifier("player.subtitle.externalEnabled")
                #if !os(tvOS)
                if PurePlayerUIPolicy.allowsLocalSubtitleImport {
                    Button("从本机导入", systemImage: "doc.badge.plus") { openLocalSubtitleFilePicker() }
                        .accessibilityIdentifier("player.subtitle.importLocal")
                        .onGeometryChange(for: CGFloat?.self) { [formCoordinateSpace] geometry in
                            showsEmpty ? geometry.frame(in: .named(formCoordinateSpace)).maxY : nil
                        } action: { importControlBottom = $0 }
                }
                #endif
            }
            if !showsEmpty {
                Section {
                    ForEach(playerControlModel.localSubtitleItems) { item in
                        HStack {
                            ExternalSubtitleRowView(isSelected: Binding(
                                get: { playerControlModel.currentSubtitlePath == item.id },
                                set: { selected in
                                    if selected { playSubtitle(item) }
                                    else { playerControlModel.clearSubtitle(controller: playerCoordinator.controller) }
                                }
                            ), subtitleName: item.displayName, subtitleLanguage: "", subtitleSize: item.sizeDescription)
                            if playerControlModel.pendingLocalSubtitleID == item.id {
                                ProgressView().controlSize(.small)
                            }
                        }
                        .contextMenu {
                            Button("删除", systemImage: "trash", role: .destructive) {
                                playerControlModel.removeLocalSubtitle(item, controller: playerCoordinator.controller)
                            }
                        }
                    }
                }
            }
        }
        .modifier(PlayerPanelFormModifier())
        .scrollContentBackground(.hidden)
        .coordinateSpace(name: formCoordinateSpace)
        .overlay(alignment: .topLeading) {
            if showsEmpty, let importControlBottom {
                Text("尚未导入外部字幕")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .padding(.top, max(0, importControlBottom))
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("player.subtitle.emptyState")
            }
        }
        .onAppear { subtitleCommandScheduler.cancel() }
        .onDisappear { subtitleCommandScheduler.cancel() }
        .compatibleOnChange(of: playerControlModel.showSubtitleContainer) { visible in
            if !visible { subtitleCommandScheduler.cancel() }
        }
        .alert("字幕", isPresented: Binding(
            get: { playerControlModel.subtitleOperationError != nil },
            set: { if !$0 { playerControlModel.subtitleOperationError = nil } }
        )) {
            Button("好", role: .cancel) { playerControlModel.subtitleOperationError = nil }
        } message: {
            Text(LocalizedStringKey(playerControlModel.subtitleOperationError ?? ""))
        }
        #if os(iOS) || os(visionOS)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: subtitleContentTypes, allowsMultipleSelection: false) { result in
            if case let .success(urls) = result, let url = urls.first {
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                importSubtitles(urls: [url])
            }
        }
        #endif
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
        subtitleCommandScheduler.schedule {
            playerControlModel.selectLocalSubtitle(item, controller: playerCoordinator.controller)
        }
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
                displayName: url.lastPathComponent,
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
#endif
