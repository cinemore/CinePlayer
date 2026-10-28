import CinePlayerSDK
//
//  SiderEnhancementView.swift
//  Cinemore
//
//  视频增强侧边弹出窗口
//

import SwiftUI

#if !os(tvOS)
    import Anime4KMetal
    import Metal

    /// 侧边弹出窗口 - 视频增强
    struct SiderEnhancementView: View {
        @Environment(\.locale) private var locale
        @ObservedObject var playSettingModel = PlayerEnhancementModel.shared
        @State private var category: EnhancementCategory = .interpolation

        private enum EnhancementCategory: Hashable {
            case interpolation, superResolution
        }

        private enum EnhancementSection: CaseIterable {
            case metalFX, fsr, anime4k, artCNN
            case frameInterpolation, rife
            case superResolution
            case metalFXInterpolation
        }

        private func isAvailable(_ section: EnhancementSection) -> Bool {
            guard !playSettingModel.enhancementCurrentVideoHasDolbyVisionConfig else {
                return false
            }
            return switch section {
            case .fsr,
                 .artCNN:
                playSettingModel.spatialSuperResolutionCurrentVideoSupported
            case .anime4k:
                playSettingModel.anime4kSectionVisible
            case .metalFX:
                playSettingModel.metalFXSectionVisible
            case .frameInterpolation:
                playSettingModel.systemMLFrameInterpolationSupported
                    && playSettingModel.systemMLCurrentVideoSupportsFrameInterpolation
            case .rife:
                playSettingModel.rifeSectionVisible
            case .superResolution:
                playSettingModel.systemMLSuperResolutionSupported
                    && playSettingModel.systemMLCurrentVideoSupportsSuperResolution
            case .metalFXInterpolation:
                playSettingModel.metalFXInterpolationSectionVisible
            }
        }

        private func isSystemSupported(_ section: EnhancementSection) -> Bool {
            switch section {
            case .anime4k,
                 .rife,
                 .fsr,
                 .artCNN:
                MTLCreateSystemDefaultDevice() != nil
            case .metalFX:
                playSettingModel.metalFXSuperResolutionSupported
            case .frameInterpolation:
                playSettingModel.systemMLFrameInterpolationSupported
            case .superResolution:
                playSettingModel.systemMLSuperResolutionSupported
            case .metalFXInterpolation:
                MetalFXFrameInterpolationAdapter.isSupported()
            }
        }

        private var orderedSections: [EnhancementSection] {
            let sections = EnhancementSection.allCases
                .filter { categoryForSection($0) == category }
                .filter { isSystemSupported($0) }
                .map { (section: $0, available: isAvailable($0)) }
            // 超分按推荐顺序展示，不随当前视频的可开启状态重排。
            if category == .superResolution {
                return sections.map(\.section)
            }
            // 可开启的功能优先，同组内保持原顺序，身份不随可用状态改变。
            return sections.filter(\.available).map(\.section)
                + sections.filter { !$0.available }.map(\.section)
        }

        private func categoryForSection(_ section: EnhancementSection) -> EnhancementCategory {
            switch section {
            case .anime4k,
                 .metalFX,
                 .fsr,
                 .artCNN:
                .superResolution
            case .frameInterpolation,
                 .rife:
                .interpolation
            case .superResolution:
                .superResolution
            case .metalFXInterpolation:
                .interpolation
            }
        }

        @ViewBuilder
        private func outputFormatFooter(
            for strategy: VideoEnhancementStrategy,
            frameInterpolation: Bool = false
        ) -> some View {
            if let output = playSettingModel.enhancementOutputFormat(
                for: strategy, frameInterpolation: frameInterpolation
            ) {
                let resolution = "\(output.width)×\(output.height)"
                let frameRate = output.frameRate.map {
                    $0.formatted(.number.locale(locale).grouping(.never).precision(.fractionLength(0 ... 3)))
                }
                let description = frameRate.map { "\(resolution) · \($0) fps" } ?? resolution
                Text("预计增强后：\(description)")
            }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text("视频增强")
                    .playerPanelTitleStyle()

                Form {
                    if playSettingModel.enhancementStartupFailed {
                        Text("视频增强准备失败，请关闭后重试。")
                            .foregroundStyle(.secondary)
                    }
                    if playSettingModel.dolbyVisionP7SectionVisible {
                        Section {
                            Toggle(
                                "FEL 增强层解码",
                                isOn: $playSettingModel.dolbyVisionFELDecode
                            )
                            OpenUrlButtonView(
                                url: "https://professionalsupport.dolby.com/s/article/What-is-Dolby-Vision-Profile?language=en_US",
                                title: "了解详情",
                                opensExternally: true
                            )
                        } header: {
                            Text("杜比视界 P7")
                        } footer: {
                            VStack(alignment: .leading) {
                                Text("为 Dolby Vision Profile 7 视频合成 FEL 增强层，提升高光与细节表现。")
                                Text("性能要求高，会增加发热")
                                outputFormatFooter(for: .off)
                            }
                        }
                    }

                    Section {
                        Picker("增强类型", selection: $category) {
                            Text("补帧").tag(EnhancementCategory.interpolation)
                            Text("超分").tag(EnhancementCategory.superResolution)
                        }
                        .pickerStyle(.segmented)
                    } footer: {
                        VStack(alignment: .leading) {
                            Text("会增加发热，不保证都能稳定运行")
                        }
                    }

                    ForEach(orderedSections, id: \.self) { section in
                        let available = isAvailable(section)
                        switch section {
                        case .fsr,
                             .artCNN:
                            let strategy: VideoEnhancementStrategy = section == .fsr ? .fsr : .artCNN
                            Section {
                                if available {
                                    Toggle("开启", isOn: Binding(
                                        get: { playSettingModel.videoEnhancementStrategy == strategy },
                                        set: { enabled in
                                            if enabled {
                                                playSettingModel.videoEnhancementStrategy = strategy
                                            } else if playSettingModel.videoEnhancementStrategy == strategy {
                                                playSettingModel.videoEnhancementStrategy = .off
                                            }
                                        }
                                    ))
                                    .toggleStyle(EnhancementLoadingToggleStyle(isPreparing: playSettingModel.enhancementPreparingStrategy != nil))
                                    if section == .fsr {
                                        PlayerPanelPicker("输出分辨率", selection: $playSettingModel.fsrOutputResolution) {
                                            ForEach(playSettingModel.fsrSupportedOutputResolutions) { resolution in
                                                Text(resolution.rawValue).tag(resolution)
                                            }
                                        }
                                        PlayerPanelPicker("锐化", selection: $playSettingModel.fsrSharpness) {
                                            ForEach(FSRSharpness.allCases) { sharpness in
                                                Text(sharpness.displayName).tag(sharpness)
                                            }
                                        }
                                    }
                                    Toggle("A/B 对比（左原图，右超分）", isOn: section == .fsr
                                        ? $playSettingModel.fsrABCompare : $playSettingModel.artCNNABCompare)
                                } else {
                                    Text("当前视频不支持").foregroundStyle(.secondary)
                                }
                            } header: {
                                Text(strategy.displayName)
                            } footer: {
                                VStack(alignment: .leading) {
                                    Text("仅支持 1080p 30fps 及以下")
                                    if section == .artCNN {
                                        Text("适合动漫视频")
                                        Text("性能要求：超高")
                                    } else {
                                        Text("性能要求：低")
                                    }
                                    if available {
                                        outputFormatFooter(for: strategy)
                                    }
                                }
                            }

                        case .anime4k:
                            // Anime4K 区域
                            Section(
                                header: Text("Anime4K 超分"),
                                footer: VStack(alignment: .leading) {
                                    Text("适合动漫视频")
                                    Text("更高的档位，需要更高的性能")
                                    Text("性能要求：超高")
                                    if available {
                                        outputFormatFooter(for: .anime4k)
                                    }
                                }
                            ) {
                                if available {
                                    Toggle(
                                        "开启",
                                        isOn: Binding(
                                            get: {
                                                playSettingModel.videoEnhancementStrategy == .anime4k
                                                    && playSettingModel.anime4kEnabled
                                            },
                                            set: { newValue in
                                                if newValue {
                                                    // 开启 Anime4K：切换策略并打开 Anime4K
                                                    playSettingModel.videoEnhancementStrategy = .anime4k
                                                    playSettingModel.anime4kEnabled = true
                                                } else {
                                                    // 关闭 Anime4K：仅关闭 Anime4K 开关，策略交给内部互斥逻辑处理
                                                    playSettingModel.anime4kEnabled = false
                                                    if playSettingModel.videoEnhancementStrategy == .anime4k {
                                                        playSettingModel.videoEnhancementStrategy = .off
                                                    }
                                                }
                                            }
                                        )
                                    )
                                    .toggleStyle(EnhancementLoadingToggleStyle(isPreparing: playSettingModel.enhancementPreparingStrategy != nil))
                                    PlayerPanelPicker(
                                        "档位",
                                        selection: Binding(
                                            get: {
                                                let p = playSettingModel.anime4kPreset
                                                return Anime4KPreset.availablePresets.contains(p)
                                                    ? p : .modeAFast
                                            },
                                            set: { playSettingModel.anime4kPreset = $0 }
                                        )
                                    ) {
                                        ForEach(Anime4KPreset.availablePresets) { preset in
                                            Text(preset.displayName).tag(preset)
                                        }
                                    }
                                    .onAppear {
                                        if !Anime4KPreset.availablePresets.contains(
                                            playSettingModel.anime4kPreset
                                        ) {
                                            playSettingModel.anime4kPreset = .modeAFast
                                        }
                                    }

                                    PlayerPanelPicker("输出分辨率", selection: $playSettingModel.anime4kOutputResolution) {
                                        ForEach(Anime4KOutputResolution.allCases) { res in
                                            Text(res.displayName).tag(res)
                                        }
                                    }

                                    Toggle(isOn: $playSettingModel.anime4kABCompare) {
                                        Text("A/B 对比（左原图，右超分）")
                                    }
                                } else {
                                    Text("当前视频不支持")
                                        .playerPanelFormFont(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                OpenUrlButtonView(
                                    url: "https://github.com/bloc97/Anime4K",
                                    title: "了解详情",
                                    opensExternally: true
                                )
                            }

                        case .metalFX:
                            Section(
                                header: HStack(spacing: 4) {
                                    Text("MetalFX 超分")
                                    Text("(推荐)").foregroundStyle(.green)
                                },
                                footer: VStack(alignment: .leading) {
                                    Text("提升有限")
                                    Text("性能要求：高")
                                    if available {
                                        outputFormatFooter(for: .metalFX)
                                    }
                                }
                            ) {
                                if available {
                                    Toggle(
                                        "开启",
                                        isOn: Binding(
                                            get: {
                                                playSettingModel.videoEnhancementStrategy == .metalFX
                                                    && playSettingModel.metalFXSuperResolutionEnabled
                                            },
                                            set: { newValue in
                                                if newValue {
                                                    playSettingModel.videoEnhancementStrategy = .metalFX
                                                    playSettingModel.metalFXSuperResolutionEnabled = true
                                                } else {
                                                    playSettingModel.metalFXSuperResolutionEnabled = false
                                                    if playSettingModel.videoEnhancementStrategy == .metalFX {
                                                        playSettingModel.videoEnhancementStrategy = .off
                                                    }
                                                }
                                            }
                                        )
                                    )
                                    .toggleStyle(EnhancementLoadingToggleStyle(isPreparing: playSettingModel.enhancementPreparingStrategy != nil))
                                    PlayerPanelPicker(
                                        "目标输出",
                                        selection: $playSettingModel.metalFXOutputResolution
                                    ) {
                                        ForEach(
                                            playSettingModel.metalFXSupportedOutputResolutionsForCurrentVideo,
                                            id: \.self
                                        ) { resolution in
                                            Text(resolution.displayName).tag(resolution)
                                        }
                                    }

                                    Toggle(isOn: $playSettingModel.metalFXABCompare) {
                                        Text("A/B 对比（左原图，右超分）")
                                    }
                                } else {
                                    Text("当前视频不支持")
                                        .playerPanelFormFont(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                OpenUrlButtonView(
                                    url: "https://developer.apple.com/documentation/metalfx",
                                    title: "了解详情",
                                    opensExternally: true
                                )
                            }

                        case .frameInterpolation:
                            // VT 插帧区域
                            Section(
                                header: HStack(spacing: 4) {
                                    Text("VT 补帧")
                                    Text("(推荐)").foregroundStyle(.green)
                                },
                                footer:
                                VStack(alignment: .leading) {
                                    Text("在高性能设备上，综合效果最好，最流畅")
                                    Text("更高的补帧数，需要更高的性能")
                                    Text("性能要求：超高")
                                    if available {
                                        outputFormatFooter(for: .systemML, frameInterpolation: true)
                                    }
                                }
                            ) {
                                if available {
                                    Toggle(
                                        "开启",
                                        isOn: Binding(
                                            get: {
                                                playSettingModel.videoEnhancementStrategy == .systemML
                                                    && playSettingModel.systemMLFrameInterpolationEnabled
                                            },
                                            set: { newValue in
                                                if newValue {
                                                    playSettingModel.videoEnhancementStrategy = .systemML
                                                    playSettingModel.systemMLFrameInterpolationEnabled = true
                                                    // 互斥：超分与插帧共用 System VT 管道，同时开启会冲突
                                                    playSettingModel.systemMLSuperResolutionEnabled = false
                                                } else {
                                                    playSettingModel.systemMLFrameInterpolationEnabled = false
                                                    if playSettingModel.videoEnhancementStrategy == .systemML,
                                                       !playSettingModel.systemMLSuperResolutionEnabled
                                                    {
                                                        playSettingModel.videoEnhancementStrategy = .off
                                                    }
                                                }
                                            }
                                        )
                                    )
                                    .toggleStyle(EnhancementLoadingToggleStyle(isPreparing: playSettingModel.enhancementPreparingStrategy != nil))
                                }
                                if available {
                                    Picker("模式", selection: $playSettingModel.systemMLQualityInterpolation) {
                                        Text("速度").tag(false)
                                        if playSettingModel.systemMLQualityAvailable || playSettingModel.systemMLQualityInterpolation {
                                            Text("质量").tag(true)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    if playSettingModel.systemMLFrameInterpolationEnabled {
                                        Picker(
                                            "补帧数",
                                            selection: $playSettingModel.systemMLInterpolatedFrames
                                        ) {
                                            Text("1帧").tag(1)
                                            if playSettingModel.systemMLMaximumInterpolatedFrames > 1 {
                                                Text("2帧").tag(2)
                                                Text("3帧").tag(3)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                    }
                                } else {
                                    Text("当前视频不支持")
                                        .playerPanelFormFont(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                OpenUrlButtonView(
                                    url: "https://developer.apple.com/documentation/videotoolbox",
                                    title: "了解详情",
                                    opensExternally: true
                                )
                            }

                        case .rife:
                            Section(
                                header: Text("RIFE 补帧"),
                                footer: VStack(alignment: .leading) {
                                    Text("自动档根据性能调整")
                                    Text("性能要求：超高")
                                    if available {
                                        outputFormatFooter(for: .rife)
                                    }
                                }
                            ) {
                                if available {
                                    Toggle(
                                        "开启",
                                        isOn: Binding(
                                            get: {
                                                playSettingModel.videoEnhancementStrategy == .rife
                                            },
                                            set: { newValue in
                                                if newValue {
                                                    playSettingModel.videoEnhancementStrategy = .rife
                                                } else if playSettingModel.videoEnhancementStrategy == .rife {
                                                    playSettingModel.videoEnhancementStrategy = .off
                                                }
                                            }
                                        )
                                    )
                                    .toggleStyle(EnhancementLoadingToggleStyle(isPreparing: playSettingModel.enhancementPreparingStrategy != nil))
                                    if playSettingModel.videoEnhancementStrategy == .rife {
                                        PlayerPanelPicker("档位", selection: $playSettingModel.rifeTierPreference) {
                                            ForEach(RifeTierPreference.allCases) { tier in
                                                Text(tier.displayName).tag(tier)
                                            }
                                        }
                                        if playSettingModel.rifeTierPreference == .auto {
                                            Text("当前档位：\(playSettingModel.rifeAutoTierDisplayName)")
                                                .playerPanelFormFont(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                if !available {
                                    Text("当前视频不支持")
                                        .playerPanelFormFont(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                OpenUrlButtonView(
                                    url: "https://github.com/hzwer/Practical-RIFE",
                                    title: "了解详情",
                                    opensExternally: true
                                )
                            }

                            // VT 超分与 MetalFX 补帧均按设备、系统和视频兼容性显示开启入口。

                        case .superResolution:
                            // VT 超分区域
                            Section(
                                header: Text("VT 超分"),
                                footer: VStack(alignment: .leading) {
                                    Text("可能出现画面瑕疵")
                                    Text("性能要求：高")
                                    if available {
                                        outputFormatFooter(for: .systemML)
                                    }
                                }
                            ) {
                                if available {
                                    Toggle(
                                        "开启",
                                        isOn: Binding(
                                            get: {
                                                playSettingModel.videoEnhancementStrategy == .systemML
                                                    && playSettingModel.systemMLSuperResolutionEnabled
                                            },
                                            set: { newValue in
                                                if newValue {
                                                    playSettingModel.videoEnhancementStrategy = .systemML
                                                    playSettingModel.systemMLSuperResolutionEnabled = true
                                                    playSettingModel.systemMLFrameInterpolationEnabled = false
                                                } else {
                                                    playSettingModel.systemMLSuperResolutionEnabled = false
                                                    if playSettingModel.videoEnhancementStrategy == .systemML,
                                                       !playSettingModel.systemMLFrameInterpolationEnabled
                                                    {
                                                        playSettingModel.videoEnhancementStrategy = .off
                                                    }
                                                }
                                            }
                                        )
                                    )
                                    .toggleStyle(EnhancementLoadingToggleStyle(isPreparing: playSettingModel.enhancementPreparingStrategy != nil))
                                    if playSettingModel.systemMLSuperResolutionEnabled {
                                        PlayerPanelPicker(
                                            "超分倍率",
                                            selection: $playSettingModel.systemMLSuperResolutionScale
                                        ) {
                                            ForEach(
                                                playSettingModel.systemMLSupportedScaleFactorsForPicker,
                                                id: \.self
                                            ) { scale in
                                                Text("\(scale, specifier: "%.2f")x").tag(scale)
                                            }
                                        }
                                        Toggle(
                                            "A/B 对比（左原图，右超分）",
                                            isOn: $playSettingModel.systemMLABCompare
                                        )
                                    }
                                } else {
                                    Text("当前视频不支持")
                                        .playerPanelFormFont(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                OpenUrlButtonView(
                                    url: "https://developer.apple.com/documentation/videotoolbox",
                                    title: "了解详情",
                                    opensExternally: true
                                )
                            }

                        case .metalFXInterpolation:
                            // MetalFX 补帧区域
                            Section(
                                header: Text("MetalFX 补帧"),
                                footer: VStack(alignment: .leading) {
                                    Text("快速运动可能出现拖影")
                                    Text("性能要求：高")
                                    if available {
                                        outputFormatFooter(for: .metalFXInterpolation)
                                    }
                                }
                            ) {
                                if available {
                                    Toggle(
                                        "开启",
                                        isOn: Binding(
                                            get: {
                                                playSettingModel.videoEnhancementStrategy == .metalFXInterpolation
                                            },
                                            set: { newValue in
                                                if newValue {
                                                    playSettingModel.videoEnhancementStrategy = .metalFXInterpolation
                                                } else if playSettingModel.videoEnhancementStrategy == .metalFXInterpolation {
                                                    playSettingModel.videoEnhancementStrategy = .off
                                                }
                                            }
                                        )
                                    )
                                    .toggleStyle(EnhancementLoadingToggleStyle(isPreparing: playSettingModel.enhancementPreparingStrategy != nil))
                                } else {
                                    Text("当前视频不支持")
                                        .playerPanelFormFont(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                OpenUrlButtonView(
                                    url: "https://developer.apple.com/documentation/metalfx",
                                    title: "了解详情",
                                    opensExternally: true
                                )
                            }
                        }
                    }
                }
                .modifier(PlayerPanelFormModifier())
                .scrollContentBackground(.hidden)
            }
        }
    }

    private struct EnhancementLoadingToggleStyle: ToggleStyle {
        let isPreparing: Bool
        func makeBody(configuration: Configuration) -> some View {
            HStack {
                configuration.label
                Spacer()
                if isPreparing, configuration.isOn {
                    // 加载器保留取消入口，准备期间也能关闭当前增强。
                    Button { configuration.isOn = false } label: {
                        ProgressView().controlSize(.small)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("取消准备"))
                } else {
                    Toggle(isOn: configuration.$isOn) { EmptyView() }
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
    }
#endif
