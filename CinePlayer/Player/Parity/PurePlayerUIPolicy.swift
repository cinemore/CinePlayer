import Foundation

/// Centralized pure-player UI exclusions to avoid accidental feature reintroduction.
enum PurePlayerUIPolicy {
    static let allowsSourceSwitch = false
    static let allowsEpisodeList = false
    static let allowsSubtitleImportFromFileSource = false
    static let allowsLocalSubtitleImport = true
}
