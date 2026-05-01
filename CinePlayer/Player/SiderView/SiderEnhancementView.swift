import SwiftUI

#if !os(tvOS)

/// 侧边弹出窗口 - 视频增强
struct SiderEnhancementView: View {
    @ObservedObject private var enhancementModel = PlayerEnhancementModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("视频增强（实验）")
                .f17s()
                .padding()

            Form {
                Section(
                    header: Text("Anime4K 超分"),
                    footer: Text("仅对低像素的视频开启，为实验功能，会增加耗电与发热。")
                ) {
                    let isAvailable = enhancementModel.anime4kSectionVisible

                    Toggle(
                        "开启",
                        isOn: Binding(
                            get: {
                                enhancementModel.videoEnhancementStrategy == .anime4k
                                    && enhancementModel.anime4kEnabled
                            },
                            set: { newValue in
                                if newValue {
                                    enhancementModel.videoEnhancementStrategy = .anime4k
                                    enhancementModel.anime4kEnabled = true
                                } else {
                                    enhancementModel.anime4kEnabled = false
                                    if enhancementModel.videoEnhancementStrategy == .anime4k {
                                        enhancementModel.videoEnhancementStrategy = .off
                                    }
                                }
                            }
                        )
                    )
                    .disabled(!isAvailable)

                    if isAvailable {
                        Picker(
                            "档位",
                            selection: Binding(
                                get: {
                                    let preset = enhancementModel.anime4kPreset
                                    return Anime4KPreset.availablePresets.contains(preset)
                                        ? preset : .modeAFast
                                },
                                set: { enhancementModel.anime4kPreset = $0 }
                            )
                        ) {
                            ForEach(Anime4KPreset.availablePresets) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .onAppear {
                            if !Anime4KPreset.availablePresets.contains(enhancementModel.anime4kPreset) {
                                enhancementModel.anime4kPreset = .modeAFast
                            }
                        }

                        Picker("输出分辨率", selection: $enhancementModel.anime4kOutputResolution) {
                            ForEach(Anime4KOutputResolution.allCases) { resolution in
                                Text(resolution.displayName).tag(resolution)
                            }
                        }

                        Toggle(isOn: $enhancementModel.anime4kABCompare) {
                            Text("A/B 对比（左原图，右超分）")
                        }

                        if let anime4kURL = URL(string: "https://github.com/bloc97/Anime4K") {
                            Link("了解 Anime4K 详情", destination: anime4kURL)
                        }
                    } else {
                        Text("当前视频像素数不在 Anime4K 适配范围内")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(
                    header: Text("MetalFX 超分"),
                    footer: Text("使用系统 MetalFX Spatial Scaler 做单帧超分。输出将按视频原始比例等比放大到目标 2K 或 4K 边界内。")
                ) {
                    let isAvailable = enhancementModel.metalFXSectionVisible

                    Toggle(
                        "开启",
                        isOn: Binding(
                            get: {
                                enhancementModel.videoEnhancementStrategy == .metalFX
                                    && enhancementModel.metalFXSuperResolutionEnabled
                            },
                            set: { newValue in
                                if newValue {
                                    enhancementModel.videoEnhancementStrategy = .metalFX
                                    enhancementModel.metalFXSuperResolutionEnabled = true
                                } else {
                                    enhancementModel.metalFXSuperResolutionEnabled = false
                                    if enhancementModel.videoEnhancementStrategy == .metalFX {
                                        enhancementModel.videoEnhancementStrategy = .off
                                    }
                                }
                            }
                        )
                    )
                    .disabled(!isAvailable)

                    if isAvailable {
                        Picker(
                            "目标输出",
                            selection: $enhancementModel.metalFXOutputResolution
                        ) {
                            ForEach(
                                enhancementModel.metalFXSupportedOutputResolutionsForCurrentVideo,
                                id: \.self
                            ) { resolution in
                                Text(resolution.displayName).tag(resolution)
                            }
                        }

                        Toggle(isOn: $enhancementModel.metalFXABCompare) {
                            Text("A/B 对比（左原图，右超分）")
                        }

                        if let metalFXURL = URL(string: "https://developer.apple.com/documentation/metalfx") {
                            Link("了解 MetalFX 详情", destination: metalFXURL)
                        }
                    } else if !enhancementModel.metalFXSuperResolutionSupported {
                        Text("当前设备不支持 MetalFX 超分")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("当前视频暂不支持 MetalFX 超分")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(
                    header: Text("VT 超分"),
                    footer: Text("依赖系统 VideoToolbox 低延迟超分能力。与 VT 插帧互斥：开启一项会关闭另一项。")
                ) {
                    let srAvailable =
                        enhancementModel.systemMLEnhancementSupported
                            && enhancementModel.systemMLCurrentVideoSupportsSuperResolution

                    Toggle(
                        "开启 VT 超分",
                        isOn: Binding(
                            get: {
                                enhancementModel.videoEnhancementStrategy == .systemML
                                    && enhancementModel.systemMLSuperResolutionEnabled
                            },
                            set: { newValue in
                                if newValue {
                                    enhancementModel.videoEnhancementStrategy = .systemML
                                    enhancementModel.systemMLSuperResolutionEnabled = true
                                    enhancementModel.systemMLFrameInterpolationEnabled = false
                                } else {
                                    enhancementModel.systemMLSuperResolutionEnabled = false
                                    if enhancementModel.videoEnhancementStrategy == .systemML,
                                       !enhancementModel.systemMLFrameInterpolationEnabled
                                    {
                                        enhancementModel.videoEnhancementStrategy = .off
                                    }
                                }
                            }
                        )
                    )
                    .disabled(!srAvailable)

                    if srAvailable {
                        if enhancementModel.systemMLSuperResolutionEnabled {
                            Picker(
                                "超分倍率",
                                selection: $enhancementModel.systemMLSuperResolutionScale
                            ) {
                                ForEach(
                                    enhancementModel.systemMLSupportedScaleFactorsForPicker,
                                    id: \.self
                                ) { scale in
                                    Text("\(scale, specifier: "%.2f")x").tag(scale)
                                }
                            }
                            Toggle(
                                "A/B 对比（左原图，右超分）",
                                isOn: $enhancementModel.systemMLABCompare
                            )
                        }
                    } else if !enhancementModel.systemMLEnhancementSupported {
                        Text("当前设备不支持 VT 超分")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("当前视频分辨率不支持 VT 超分")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(
                    header: Text("VT 插帧"),
                    footer: Text("依赖系统 VideoToolbox 低延迟插帧能力。")
                ) {
                    let fiAvailable =
                        enhancementModel.systemMLEnhancementSupported
                            && enhancementModel.systemMLCurrentVideoSupportsFrameInterpolation

                    Toggle(
                        "开启 VT 插帧",
                        isOn: Binding(
                            get: {
                                enhancementModel.videoEnhancementStrategy == .systemML
                                    && enhancementModel.systemMLFrameInterpolationEnabled
                            },
                            set: { newValue in
                                if newValue {
                                    enhancementModel.videoEnhancementStrategy = .systemML
                                    enhancementModel.systemMLFrameInterpolationEnabled = true
                                    enhancementModel.systemMLSuperResolutionEnabled = false
                                } else {
                                    enhancementModel.systemMLFrameInterpolationEnabled = false
                                    if enhancementModel.videoEnhancementStrategy == .systemML,
                                       !enhancementModel.systemMLSuperResolutionEnabled
                                    {
                                        enhancementModel.videoEnhancementStrategy = .off
                                    }
                                }
                            }
                        )
                    )
                    .disabled(!fiAvailable)

                    if fiAvailable {
                        if enhancementModel.systemMLFrameInterpolationEnabled {
                            Picker(
                                "Frames added",
                                selection: $enhancementModel.systemMLInterpolatedFrames
                            ) {
                                Text("1").tag(1)
                                Text("2").tag(2)
                                Text("3").tag(3)
                            }
                        }
                    } else if !enhancementModel.systemMLEnhancementSupported {
                        Text("当前设备不支持 VT 插帧")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("当前视频分辨率不支持 VT 插帧")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(
                    header: Text("光流补帧"),
                    footer: Text("仅在 1080p 及以下分辨率开放，适合低帧率内容插帧。")
                ) {
                    let isAvailable = enhancementModel.opticalFlowSectionVisible

                    Toggle(
                        "开启",
                        isOn: Binding(
                            get: {
                                enhancementModel.videoEnhancementStrategy == .opticalFlow
                            },
                            set: { newValue in
                                if newValue {
                                    enhancementModel.videoEnhancementStrategy = .opticalFlow
                                } else if enhancementModel.videoEnhancementStrategy == .opticalFlow {
                                    enhancementModel.videoEnhancementStrategy = .off
                                }
                            }
                        )
                    )
                    .disabled(!isAvailable)

                    if !isAvailable {
                        Text("当前视频分辨率不在光流补帧支持范围内")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                #if os(macOS)
                Section(
                    header: Text("RIFE 补帧"),
                    footer: Text("Apple 原生 ML 补帧，720p–4K 自动选档。与光流补帧互斥，不同场景各有所长。")
                ) {
                    let isAvailable = enhancementModel.rifeSectionVisible

                    Toggle(
                        "开启",
                        isOn: Binding(
                            get: {
                                enhancementModel.videoEnhancementStrategy == .rife
                            },
                            set: { newValue in
                                if newValue {
                                    enhancementModel.videoEnhancementStrategy = .rife
                                } else if enhancementModel.videoEnhancementStrategy == .rife {
                                    enhancementModel.videoEnhancementStrategy = .off
                                }
                            }
                        )
                    )
                    .disabled(!isAvailable)

                    if !isAvailable {
                        Text("当前视频分辨率不在 RIFE 支持范围内（720p–4K）")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if enhancementModel.videoEnhancementStrategy == .rife {
                        Text("自动选档：\(enhancementModel.rifeAutoTierDisplayName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                #endif
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }
}

#else

struct SiderEnhancementView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("视频增强（实验）")
                .f17s()
            Text("tvOS 暂不提供增强策略配置")
                .f12r()
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding()
    }
}

#endif
