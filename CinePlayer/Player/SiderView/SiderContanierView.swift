//
//  SiderContanierView.swift
//  Cinemore
//

import SwiftUI

/// 弹出方向枚举
enum ContainerDirection {
    case trailing // 从右侧弹出
    case bottom // 从底部弹出
}

struct SiderContanierView<Content: View>: View {
    /// 是否显示容器
    var show: Bool
    /// 几何信息
    var geometry: GeometryProxy
    /// 弹出方向
    var direction: ContainerDirection
    /// 容器宽度，只在从右侧弹出时使用
    var width: CGFloat?
    /// 背景
    var showBackground = true

    @ViewBuilder
    var content: Content

    private var offset: CGSize {
        switch direction {
        case .trailing:
            CGSize(width: show ? 0 : geometry.size.width, height: 0)
        case .bottom:
            CGSize(width: 0, height: show ? 0 : geometry.size.height)
        }
    }

    private var alignment: Alignment {
        switch direction {
        case .trailing:
            .trailing
        case .bottom:
            .bottom
        }
    }

    private var cornerRadius: CGFloat {
        PlatformServices.displayCornerRadius()
    }

    private var leadingCornerRadius: CGFloat {
        #if canImport(UIKit)
            return 24
        #else
            return 16
        #endif
    }

    var body: some View {
        ZStack {
            content
                .frame(maxWidth: direction == .trailing ? (width ?? 380) : .infinity)
                .if(showBackground) {
                    if direction == .trailing {
                        // 从右边弹出，右边两个角使用屏幕圆角
                        $0.modifier(GlassEffectModifier(
                            topLeading: leadingCornerRadius,
                            topTrailing: cornerRadius,
                            bottomLeading: leadingCornerRadius,
                            bottomTrailing: cornerRadius,
                            material: .regularMaterial,
                            useCapsule: false,
                            clipsContent: true
                        ))
                    } else {
                        // 从底部弹出，下面两个角使用屏幕圆角
                        $0.modifier(GlassEffectModifier(
                            topLeading: leadingCornerRadius,
                            topTrailing: leadingCornerRadius,
                            bottomLeading: cornerRadius,
                            bottomTrailing: cornerRadius,
                            material: .regularMaterial,
                            useCapsule: false,
                            clipsContent: true
                        ))
                    }
                }
                .offset(x: offset.width, y: offset.height)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: show)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: direction == .trailing ? geometry.size.height + geometry.safeAreaInsets.bottom - 16 : .infinity,
            alignment: alignment
        )
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .edgesIgnoringSafeArea(.all)
    }
}
