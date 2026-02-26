import SwiftUI

#if os(iOS)
import UIKit
#endif

@MainActor
struct SiderView: View {
    var geometry: GeometryProxy

    @EnvironmentObject var playerControlModel: PlayerControlModel
    @EnvironmentObject var playerMaskModel: PlayerMaskModel

    private var panelDirection: ContainerDirection {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            if PlatformServices.isIOSPlayerPortraitLock() {
                .bottom
            } else {
                .trailing
            }
        } else {
            .trailing
        }
        #else
        .trailing
        #endif
    }

    var body: some View {
        ZStack {
            if playerControlModel.isSiderContainerShow {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        playerControlModel.hideContainer()
                        playerMaskModel.showMask()
                    }
            }

            SiderContanierView(
                show: playerControlModel.showSettingContainer,
                geometry: geometry,
                direction: panelDirection,
                showBackground: panelDirection == .trailing
            ) {
                SiderSettingView()
                    .if(panelDirection == .bottom) {
                        $0.frame(height: geometry.size.height * 0.75)
                    }
            }

            SiderContanierView(
                show: playerControlModel.showEnhancementContainer,
                geometry: geometry,
                direction: panelDirection,
                showBackground: panelDirection == .trailing
            ) {
                SiderEnhancementView()
                    .if(panelDirection == .bottom) {
                        $0.frame(height: geometry.size.height * 0.75)
                    }
            }

            SiderContanierView(
                show: playerControlModel.showSubtitleContainer,
                geometry: geometry,
                direction: panelDirection,
                showBackground: panelDirection == .trailing
            ) {
                SiderSubtitleView()
                    .if(panelDirection == .bottom) {
                        $0.frame(height: geometry.size.height * 0.75)
                    }
            }

            SiderContanierView(
                show: playerControlModel.showAudioContainer,
                geometry: geometry,
                direction: panelDirection,
                showBackground: panelDirection == .trailing
            ) {
                SiderAudioSettingView()
                    .if(panelDirection == .bottom) {
                        $0.frame(height: geometry.size.height * 0.75)
                    }
            }

            SiderContanierView(
                show: playerControlModel.showVideoTrackContainer,
                geometry: geometry,
                direction: panelDirection,
                showBackground: panelDirection == .trailing
            ) {
                SiderVideoTrackView()
                    .if(panelDirection == .bottom) {
                        $0.frame(height: geometry.size.height * 0.75)
                    }
            }

            SiderContanierView(
                show: playerControlModel.showPlaybackSpeedContainer,
                geometry: geometry,
                direction: .bottom,
                showBackground: false
            ) {
                SiderPlaybackSpeedView()
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .compatibleOnChange(of: playerControlModel.isSiderContainerShow) { _ in
            if playerControlModel.isSiderContainerShow {
                playerMaskModel.hideMask()
            }
        }
    }
}
