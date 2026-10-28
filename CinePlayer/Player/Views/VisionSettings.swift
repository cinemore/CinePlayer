#if os(visionOS)
//
//  VisionSettings.swift
//  CinemoreVision
//

import AVFAudio
import SwiftUI
import Combine

enum VisionImmersionStyleSetting: String, CaseIterable, Identifiable, Codable {
    case progressive
    case mixed
    case full

    var id: String {
        rawValue
    }

    var title: LocalizedStringKey {
        switch self {
        case .progressive: "vision.immersion.progressive"
        case .mixed: "vision.immersion.mixed"
        case .full: "vision.immersion.full"
        }
    }

    var swiftUIStyle: any ImmersionStyle {
        switch self {
        case .progressive: ProgressiveImmersionStyle()
        case .mixed: MixedImmersionStyle()
        case .full: FullImmersionStyle()
        }
    }
}

@MainActor
final class VisionSettings: ObservableObject {
    static let shared = VisionSettings()

    /// 写入路径必须经过 immersionStyle 的 setter，否则 objectWillChange 不会触发，
    /// SwiftUI 视图收不到更新（@AppStorage 在 ObservableObject 内不会自动 publish）。
    @AppStorage("vision.immersionStyle")
    private var storedStyle: String = VisionImmersionStyleSetting.progressive.rawValue

    var immersionStyle: VisionImmersionStyleSetting {
        get { VisionImmersionStyleSetting(rawValue: storedStyle) ?? .progressive }
        set {
            objectWillChange.send()
            storedStyle = newValue.rawValue
        }
    }

    /// SwiftUI binding wrapping the persisted style.
    var immersionStyleBinding: Binding<VisionImmersionStyleSetting> {
        Binding(
            get: { self.immersionStyle },
            set: { self.immersionStyle = $0 }
        )
    }
}

extension Binding where Value == VisionImmersionStyleSetting {
    /// 系统与设置页共用同一个持久化值，避免切换风格后互相覆盖。
    var styleErased: Binding<any ImmersionStyle> {
        Binding<any ImmersionStyle>(
            get: { wrappedValue.swiftUIStyle },
            set: { newStyle in
                if newStyle is ProgressiveImmersionStyle {
                    wrappedValue = .progressive
                } else if newStyle is MixedImmersionStyle {
                    wrappedValue = .mixed
                } else if newStyle is FullImmersionStyle {
                    wrappedValue = .full
                } else {
                    assertionFailure("Unhandled ImmersionStyle: \(type(of: newStyle))")
                }
            }
        )
    }
}

/// Vision-only spatial audio bridge. Lives outside the CinePlayer submodule so
/// soundstage can follow user-selected immersion style without modifying shared CinePlayer code.
enum VisionSpatialAudio {
    static func apply(isImmersive: Bool, immersionStyle: VisionImmersionStyleSetting) {
        let experience: AVAudioSessionSpatialExperience = makeExperience(
            isImmersive: isImmersive,
            style: immersionStyle
        )
        do {
            try AVAudioSession.sharedInstance().setIntendedSpatialExperience(experience)
        } catch {
            cinemoreLog(level: .error, "[VisionSpatialAudio] setIntendedSpatialExperience failed: \(error)")
        }
    }

    private static func makeExperience(
        isImmersive: Bool,
        style: VisionImmersionStyleSetting
    ) -> AVAudioSessionSpatialExperience {
        guard isImmersive else {
            return .headTracked(soundStageSize: .small, anchoringStrategy: .automatic)
        }
        switch style {
        case .progressive,
             .full:
            return .headTracked(soundStageSize: .large, anchoringStrategy: .automatic)
        case .mixed:
            // Mixed-style passthrough: smaller soundstage so users can hear ambient.
            return .headTracked(soundStageSize: .small, anchoringStrategy: .automatic)
        }
    }
}

#endif
