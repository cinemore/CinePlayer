#if os(macOS)
import AppKit
import Combine
import SwiftData
import SwiftUI
import Testing
@testable import CinePlayer

@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct PlayerAppearanceTests {
    @Test func playerSheetUsesDarkAppearanceWithoutChangingItsPresenter() async throws {
        let probe = PlayerAppearanceProbe()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = NSHostingView(rootView: AppearanceSheetHost(probe: probe))
        window.makeKeyAndOrderFront(nil)
        defer {
            if let sheet = window.attachedSheet { window.endSheet(sheet) }
            window.contentView = nil
            window.close()
        }

        try await waitForAppearance { probe.mainColorScheme == .light }
        probe.isSheetPresented = true
        try await waitForAppearance { window.attachedSheet != nil && probe.sheetColorScheme == .dark }
        let sheet = try #require(window.attachedSheet)
        #expect(sheet.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
        #expect(window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua)
        #expect(probe.mainColorScheme == .light)

        window.appearance = NSAppearance(named: .darkAqua)
        try await waitForAppearance { probe.mainColorScheme == .dark }
        window.appearance = NSAppearance(named: .aqua)
        try await waitForAppearance { probe.mainColorScheme == .light }
        #expect(probe.sheetColorScheme == .dark)
        #expect(sheet.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)

        probe.isSheetPresented = false
        try await waitForAppearance { window.attachedSheet == nil }
        #expect(probe.mainColorScheme == .light)
    }

    @Test func playerDoesNotRequestAppearanceForTheMainWindow() async throws {
        let defaultsName = "CinePlayerAppearanceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        let session = PlayerSessionStore(defaults: defaults)
        let player = VideoPlayerModel()
        let windowController = PlayerWindowController()
        let container = try ModelContainer(for: PlaybackHistoryRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let probe = PlayerAppearanceProbe()
        let host = NSHostingView(rootView: VStack {
            AppearanceReader { probe.mainColorScheme = $0 }
            PlayerControlView()
        }
        .environmentObject(session)
        .environmentObject(player)
        .environmentObject(windowController)
        .modelContainer(container)
        .overlayPreferenceValue(PreferredColorSchemeKey.self) { preference in
            Color.clear
                .onAppear { probe.preference = preference; probe.didReadPreference = true }
                .onChange(of: preference) { _, value in probe.preference = value }
        })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = host
        windowController.attach(to: window)
        window.makeKeyAndOrderFront(nil)
        defer {
            window.contentView = nil
            window.close()
            player.close()
            defaults.removePersistentDomain(forName: defaultsName)
        }

        try await waitForAppearance { probe.didReadPreference && probe.mainColorScheme != nil }
        #expect(probe.preference == nil)
        #expect(probe.mainColorScheme == .light)

        window.appearance = NSAppearance(named: .darkAqua)
        try await waitForAppearance { probe.mainColorScheme == .dark }
        #expect(probe.preference == nil)

        window.appearance = NSAppearance(named: .aqua)
        try await waitForAppearance { probe.mainColorScheme == .light }
        #expect(probe.preference == nil)
    }

    private func waitForAppearance(_ predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !predicate(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }
        try #require(predicate())
    }
}

@MainActor
private final class PlayerAppearanceProbe: ObservableObject {
    @Published var isSheetPresented = false
    var preference: ColorScheme?
    var didReadPreference = false
    var mainColorScheme: ColorScheme?
    var sheetColorScheme: ColorScheme?
}

private struct AppearanceSheetHost: View {
    @ObservedObject var probe: PlayerAppearanceProbe

    var body: some View {
        AppearanceReader { probe.mainColorScheme = $0 }
            .frame(width: 640, height: 480)
            .sheet(isPresented: $probe.isSheetPresented) {
                AppearanceReader { probe.sheetColorScheme = $0 }
                    .frame(width: 320, height: 240)
                    .modifier(PlayerPresentationAppearance())
            }
    }
}

private struct AppearanceReader: View {
    @Environment(\.colorScheme) private var colorScheme
    let report: (ColorScheme) -> Void

    var body: some View {
        Text("Appearance")
            .onAppear { report(colorScheme) }
            .onChange(of: colorScheme) { _, value in report(value) }
    }
}
#endif
