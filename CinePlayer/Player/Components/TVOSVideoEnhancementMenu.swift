#if os(tvOS)
import Anime4KMetal
import CinePlayerSDK
import SwiftUI

struct TVOSVideoEnhancementMenu: View {
    @ObservedObject private var enhancementSettings = PlayerEnhancementModel.shared
    var body: some View {
        Menu {
            if enhancementSettings.dolbyVisionP7SectionVisible {
                Toggle("FEL 增强层解码", isOn: $enhancementSettings.dolbyVisionFELDecode)
            }
            enhancementOption("关闭", strategy: .off)
            enhancementOption("Anime4K 超分", strategy: .anime4k,
                              enabled: enhancementSettings.anime4kSectionVisible && !enhancementSettings.enhancementCurrentVideoHasDolbyVisionConfig)
            vtModeOption("VT 补帧", interpolation: true, enabled: canUseVTInterpolation)
            vtModeOption("VT 超分", interpolation: false, enabled: canUseVTSuperResolution)
            enhancementOption("MetalFX 超分", strategy: .metalFX,
                              enabled: enhancementSettings.metalFXSectionVisible && !enhancementSettings.enhancementCurrentVideoHasDolbyVisionConfig)
            enhancementOption("FSR 超分", strategy: .fsr,
                              enabled: enhancementSettings.spatialSuperResolutionCurrentVideoSupported)
            enhancementOption("ArtCNN 超分", strategy: .artCNN,
                              enabled: enhancementSettings.spatialSuperResolutionCurrentVideoSupported)
            if MetalFXFrameInterpolationAdapter.isSupported() {
                enhancementOption("MetalFX 补帧", strategy: .metalFXInterpolation,
                                  enabled: enhancementSettings.metalFXInterpolationSectionVisible && !enhancementSettings
                                      .enhancementCurrentVideoHasDolbyVisionConfig)
            }
            if enhancementSettings.videoEnhancementStrategy == .anime4k {
                Menu("档位") {
                    Picker("档位", selection: $enhancementSettings.anime4kPreset) {
                        ForEach(Anime4KPreset.availablePresets) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Menu("输出分辨率") {
                    Picker(
                        "输出分辨率",
                        selection: $enhancementSettings.anime4kOutputResolution
                    ) {
                        ForEach(Anime4KOutputResolution.allCases) { resolution in
                            Text(resolution.displayName).tag(resolution)
                        }
                    }
                    .pickerStyle(.inline)
                }
            } else if enhancementSettings.videoEnhancementStrategy == .systemML {
                if enhancementSettings.systemMLFrameInterpolationEnabled {
                    Menu("插入帧数") {
                        Picker(
                            "插入帧数",
                            selection: $enhancementSettings.systemMLInterpolatedFrames
                        ) {
                            ForEach(1 ... enhancementSettings.systemMLMaximumInterpolatedFrames, id: \.self) { count in
                                Text("\(count)帧").tag(count)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                } else {
                    Menu("超分倍率") {
                        Picker(
                            "超分倍率",
                            selection: $enhancementSettings.systemMLSuperResolutionScale
                        ) {
                            ForEach(enhancementSettings.systemMLSupportedScaleFactorsForPicker, id: \.self) { scale in
                                Text("\(scale, specifier: "%.2f")×").tag(scale)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }
            } else if enhancementSettings.videoEnhancementStrategy == .metalFX {
                Menu("输出分辨率") {
                    Picker(
                        "输出分辨率",
                        selection: $enhancementSettings.metalFXOutputResolution
                    ) {
                        ForEach(enhancementSettings.metalFXSupportedOutputResolutionsForCurrentVideo) { resolution in
                            Text(resolution.displayName).tag(resolution)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            if enhancementSettings.videoEnhancementStrategy == .fsr {
                Menu("输出分辨率") {
                    Picker(
                        "输出分辨率",
                        selection: $enhancementSettings.fsrOutputResolution
                    ) {
                        ForEach(enhancementSettings.fsrSupportedOutputResolutions) { resolution in
                            Text(resolution.rawValue).tag(resolution)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            if enhancementSettings.videoEnhancementStrategy == .fsr {
                Picker("锐化", selection: $enhancementSettings.fsrSharpness) {
                    ForEach(FSRSharpness.allCases) { Text($0.displayName).tag($0) }
                }
            }
            // A/B 复用现有左右画面对比，仅提供给支持对比的超分处理器。
            if enhancementSettings.videoEnhancementStrategy == .anime4k {
                Toggle("A/B 对比", isOn: $enhancementSettings.anime4kABCompare)
            } else if enhancementSettings.videoEnhancementStrategy == .systemML,
                      enhancementSettings.systemMLSuperResolutionEnabled
            {
                Toggle("A/B 对比", isOn: $enhancementSettings.systemMLABCompare)
            } else if enhancementSettings.videoEnhancementStrategy == .metalFX {
                Toggle("A/B 对比", isOn: $enhancementSettings.metalFXABCompare)
            } else if enhancementSettings.videoEnhancementStrategy == .fsr {
                Toggle("A/B 对比", isOn: $enhancementSettings.fsrABCompare)
            } else if enhancementSettings.videoEnhancementStrategy == .artCNN {
                Toggle("A/B 对比", isOn: $enhancementSettings.artCNNABCompare)
            }
            if enhancementSettings.enhancementPreparingStrategy != nil {
                Text("正在准备视频增强…")
            } else if enhancementSettings.enhancementStartupFailed {
                Text("视频增强准备失败，请关闭后重试。")
            }
        } label: {
            Image(systemName: "wand.and.stars")
        }
        .menuActionDismissBehavior(.disabled)
        .accessibilityLabel("视频增强")
        .frame(width: 68, height: 68)
        .buttonBorderShape(.circle)
    }

    private var canUseVTSuperResolution: Bool {
        enhancementSettings.systemMLSuperResolutionSupported && enhancementSettings.systemMLCurrentVideoSupportsSuperResolution
    }

    private var canUseVTInterpolation: Bool {
        enhancementSettings.systemMLFrameInterpolationSupported && enhancementSettings.systemMLCurrentVideoSupportsFrameInterpolation
    }

    private func enhancementOption(_ title: LocalizedStringKey, strategy: VideoEnhancementStrategy, enabled: Bool = true) -> some View {
        Button {
            enhancementSettings.videoEnhancementStrategy = strategy
        } label: {
            HStack {
                Text(title)
                if enhancementSettings.videoEnhancementStrategy == strategy {
                    Image(systemName: "checkmark")
                }
            }
        }
        .disabled(!enabled)
    }

    private func vtModeOption(_ title: LocalizedStringKey, interpolation: Bool, enabled: Bool) -> some View {
        Button {
            enhancementSettings.videoEnhancementStrategy = .systemML
            enhancementSettings.systemMLFrameInterpolationEnabled = interpolation
            enhancementSettings.systemMLSuperResolutionEnabled = !interpolation
        } label: {
            HStack {
                Text(title)
                if enhancementSettings.videoEnhancementStrategy == .systemML,
                   enhancementSettings.systemMLFrameInterpolationEnabled == interpolation
                {
                    Image(systemName: "checkmark")
                }
            }
        }
        .disabled(!enabled)
    }

}
#endif
